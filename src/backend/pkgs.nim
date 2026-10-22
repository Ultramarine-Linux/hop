import results
import std/[os, osproc, strutils, strformat, sugar, tables, streams, options, times]
import ../hub

const releasever* {.intdefine.}: int = 0

when releasever == 0:
  import std/macros
  macro x = error "Compiling this requires --define:releasever=..."
  x()


const editions*: Table[string, string] = {
  "Budgie": if releasever < 43: "ultramarine-release-flagship" else: "ultramarine-release-budgie",
  "GNOME": "ultramarine-release-gnome",
  "KDE Plasma": if releasever < 41: "ultramarine-release-kde" else: "ultramarine-release-plasma",
  "XFCE": "ultramarine-release-xfce",
}.toTable

const identities*: Table[string, string] = {
  "Budgie": if releasever < 43: "ultramarine-release-identity-flagship" else: "ultramarine-release-identity-budgie",
  "GNOME": "ultramarine-release-identity-gnome",
  "KDE Plasma": if releasever < 41: "ultramarine-release-identity-kde" else: "ultramarine-release-identity-plasma",
  "XFCE": "ultramarine-release-identity-xfce",
}.toTable

proc package_installed*(pkgs: openArray[string]): seq[string] =
  echo "package_installed(): " & $pkgs
  let stdout = execProcess("rpm -qa "&pkgs.join(" "))
  collect:
    for line in stdout.splitLines:
      echo "> " & line
      for pkg in pkgs:
        if line.starts_with(pkg): pkg

proc ensure_dnf5*(): Result[void, string] =
  if package_installed(["dnf5"]).len != 0:
    echo "dnf5 is installed"
    return ok()
  echo "Ensuring dnf5"
  echo "dnf5 is not installed; installing right now…"
  let rc = execCmd("dnf4 in -y dnf5")
  if rc != 0:
    echo "Failed to install dnf5; process returned exit code " & $rc
    return err fmt"Fail to install dnf5 ({rc=})"
  ok()

type Dnf5Phase = enum
  dpPreparing    ## resolving / printing the transaction table
  dpDownloading  ## after "Transaction Summary:" / "Downloading Packages:"
  dpTransaction  ## after "Running transaction" / "Testing offline transaction"

proc parse_dnf5_counter(line: string): Option[(int, int)] =
  ## Parses a leading dnf5 counter like "[1/7]", "[ 1/217]" or "[ 12/217]".
  if line.len < 5 or line[0] != '[': return
  let close = line.find(']')
  if close < 0: return
  let parts = line[1 ..< close].split('/')
  if parts.len != 2: return
  try:
    let (n, m) = (parts[0].strip.parseInt, parts[1].strip.parseInt)
    if n >= 0 and m > 0: return some((n, m))
  except ValueError: discard

proc is_dnf5_finished_bar(line: string): bool =
  ## A finished (non-TTY) dnf5 progress bar, e.g.
  ## " wmctrl-0:1.07-41.fc44.x86_64   100% |  76.8 KiB/s |  34.8 KiB |  00m00s"
  let s = line.strip
  let cols = s.split('|')
  if cols.len != 4 or not cols[0].strip.endsWith("100%"): return false
  let t = cols[3].strip  # e.g. "00m00s"
  t.len >= 4 and t.endsWith('s') and 'm' in t and t[0].isDigit

proc parse_dnf5_summary_count(line: string): int =
  ## Number of packages to be downloaded announced by a "Transaction Summary:"
  ## line, e.g. " Installing:       217 packages". 0 for anything else.
  let kv = line.strip.split(':', maxsplit = 1)
  if kv.len != 2 or kv[0] notin ["Installing", "Upgrading", "Reinstalling", "Downgrading"]:
    return 0
  let words = kv[1].strip.splitWhitespace
  if words.len == 2 and words[1].startsWith("package"):
    try: return words[0].parseInt
    except ValueError: discard

proc track_dnf5_download_progress*(process: Process, hub: Option[ref Hub]): string {.thread.} =
  ## Echoes dnf5's output, reports progress to `hub`, and returns the full output.
  ##
  ## Progress comes from (in order of preference) dnf5's "[N/M]" counters
  ## (possibly padded, e.g. "[ 1/217]"), or, when dnf5 prints no counters,
  ## the number of finished "100% | ... | 00m00s" download lines compared to
  ## the package count from the "Transaction Summary:".
  let outs = process.outputStream
  var line = ""
  var progress = 0.0
  var phase = dpPreparing
  var in_summary = false
  var expected = 0   # packages to download, from the transaction summary
  var finished = 0   # finished download lines without a counter

  proc report(p: float) =
    let p = clamp(p, 0.0, 1.0)
    if p != progress:
      progress = p
      if hub.is_some: hub.get.toMain.send Progress.init progress

  proc enter(newPhase: Dnf5Phase, text: string) =
    if phase == newPhase: return
    phase = newPhase
    if text != "" and hub.is_some: hub.get.toMain.send UpdateState.init text
    report 0.0

  proc handle(raw: string) =
    let l = raw.strip(leading = false)
    let s = l.strip
    if s == "Transaction Summary:":
      in_summary = true
      return
    if in_summary:
      if s == "":
        in_summary = false
        phase = dpDownloading
      else:
        expected += parse_dnf5_summary_count(s)
      return
    if s == "Downloading Packages:":
      phase = dpDownloading
      return
    if s == "Running transaction":
      enter dpTransaction, "Applying transaction..."
      return
    if s == "Testing offline transaction":
      enter dpTransaction, "Verifying transaction..."
      return
    if l.startsWith(">>>"): return  # scriptlet / rpm messages
    let counter = parse_dnf5_counter(l)
    if counter.is_some:
      let (n, m) = counter.get
      if phase == dpPreparing: phase = dpDownloading
      # The counter restarted: dnf5 moved from downloading to the transaction.
      if phase == dpDownloading and n/m < progress and not l.contains("Total"):
        enter dpTransaction, "Applying transaction..."
      report n/m
    elif phase == dpDownloading and is_dnf5_finished_bar(l):
      inc finished
      if expected > 0: report finished/expected

  # `at_end` blocks until data or EOF is available, so this drains the pipe
  # completely, even if the process already exited before we started reading.
  while true:
    if outs.at_end:
      if not process.running: break
      sleep(20)
      continue
    while not outs.at_end:
      let c = outs.read_char
      result.add c
      if c == '\n':
        stdout.write "\n┊ "
        handle line
        line = ""
      else:
        stdout.write c
        if c == '\r': line = ""  # keep only the last redraw of a line
        else: line.add c
  if line != "": handle line

proc end_proc*(process: Process, startTime: DateTime, action: string, errAction: string = ""): Result[void, string] {.thread.} =
  defer: process.close()
  let errAction = if errAction == "": action else: errAction
  let rc = process.peekExitCode
  echo "\n│"
  echo fmt"├═ Return code: {rc}"
  echo fmt"├═ Time taken: {now() - startTime}"
  echo fmt"└──── END OF {action} ─────"
  if rc != 0:
    echo "Error: cannot " & errAction
    return err fmt"Fail to {errAction} ({rc=})"
  echo "end_proc finished!"
  ok()

proc ensure_dnf5_did_something*(output: string, action: string): Result[void, string] =
  ## dnf5 exits with 0 when there is "Nothing to do", which would otherwise be
  ## mistaken for success (e.g. removing an environment dnf5 doesn't track).
  for l in output.splitLines:
    if l.strip == "Nothing to do.":
      echo "Error: dnf5 had nothing to do for: " & action
      var details: seq[string]
      for l2 in output.splitLines:
        let s = l2.strip
        if s.startsWith("No groups to") or s.startsWith("No packages to") or
            s.startsWith("No match for argument") or s.contains("already installed") or
            s.contains("not installed"):
          details.add s
      return err fmt"Cannot {action}: dnf5 reported nothing to do." &
        (if details.len > 0: "\n" & details.join("\n") else: "")
  ok()

const offline_state_file = "/usr/lib/sysimage/libdnf5/offline/offline-transaction-state.toml"

proc start_dnf5*(args: openArray[string]): Process =
  ## Runs /usr/bin/dnf5 with a C locale: we parse its (English) output.
  ## `env` execs dnf5 directly, so the stored offline cmd_line still starts with /usr/bin/dnf5.
  startProcess("/usr/bin/env", args = @["LC_ALL=C.UTF-8", "/usr/bin/dnf5"] & @args,
    options = {poStdErrToStdOut})

proc ensure_offline_transaction*(expect: openArray[string] = [], since: Time = Time()): Result[void, string] =
  ## Makes sure the offline transaction dnf5 will apply on reboot is the one
  ## we just prepared, and not missing or left over from another tool
  ## (e.g. Discover / dnf5daemon-server) or from an earlier run of this app.
  ## If `since` is given, the state file must have been written after it.
  if not fileExists(offline_state_file):
    return err "No offline transaction was stored by dnf5; nothing would happen on reboot."
  if since != Time() and getLastModificationTime(offline_state_file) < since:
    return err "dnf5 did not store a new offline transaction for this change; nothing would happen on reboot."
  var status, cmdline = ""
  for l in readFile(offline_state_file).splitLines:
    let kv = l.split('=', maxsplit = 1)
    if kv.len != 2: continue
    let (k, v) = (kv[0].strip, kv[1].strip.strip(chars = {'"'}))
    if k == "status": status = v
    elif k == "cmd_line": cmdline = v
  echo fmt"Offline transaction: {status=} {cmdline=}"
  if status != "download-complete":
    return err fmt"The stored offline transaction is not ready (status: {status})."
  if "--offline" notin cmdline or not cmdline.contains("dnf5"):
    return err fmt"The stored offline transaction was not created by this app (it was created by: {cmdline}). Nothing from this app would be applied on reboot."
  for e in expect:
    if e notin cmdline:
      return err fmt"The stored offline transaction does not match the requested change (it was created by: {cmdline})."
  ok()

proc reboot_apply_offline*(hub: ref Hub): Result[void, string] = 
  echo "reboot_apply_offline()"
  ?ensure_offline_transaction()
  hub.toMain.send UpdateState.init("Rebooting...")
  let rc = execCmd("/usr/bin/env LC_ALL=C.UTF-8 /usr/bin/dnf5 offline reboot -y")
  if rc != 0:
    echo "Fail to run offline reboot, rc: " & $rc
    return err fmt"Fail to run offline reboot ({rc=})"
  hub.toMain.send UpdateState.init("Reboot command finished. If your computer isn't rebooting, this is a bug.\nApp will force-quit in 10 seconds.")
  sleep 10000
  quit(0)
