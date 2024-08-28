import results
import std/[os, osproc, strutils, strformat, sugar, tables, sequtils, streams, options, times]
import ../hub

const editions*: Table[string, string] = {
  "Budgie": "budgie-desktop",
  "GNOME": "gnome-desktop",
  "KDE Plasma": "plasma-desktop",
  "XFCE": "xfwm4",
}.toTable

proc package_installed*(pkgs: openArray[string]): seq[string] =
  let stdout = execProcess("rpm -qa "&pkgs.join(" "))
  collect:
    for line in stdout.splitLines:
      for pkg in pkgs:
        if line.starts_with(pkg): pkg


echo "Checking for installed desktops..."
let installed_desktops* = package_installed(editions.values.toSeq)
echo installed_desktops

proc ensure_dnf5*(): Result[void, string] =
  if package_installed(["dnf5"]).len != 0:
    return
  echo "dnf5 is not installed; installing right now…"
  let rc = execCmd("dnf4 in -y dnf5")
  if rc != 0:
    echo "Failed to install dnf5; process returned exit code " & $rc
    return err fmt"Fail to install dnf5 ({rc=})"
  ok()

proc track_dnf5_download_progress*(process: Process, hub: Option[ref Hub]) {.thread.} =
  let outs = process.outputStream
  var line = ""
  var progress = 0.0

  while process.running:
    if outs.at_end:
      sleep(20)
    while not outs.at_end:
      let c = $outs.read_char
      if c == "\n":
        stdout.write "\n┊ "
        line = ""
      else:
        stdout.write c
        line = line & c
        if hub.is_some:
          if line.endsWith ']':
            try:
              let middle = line.find('/')
              if middle <= 0:
                continue
              let denominator = line[1..middle-1].parseInt
              let divisor = line[middle+1..^2].parseInt
              if denominator > 0 and divisor > 0:
                if denominator/divisor < progress:
                  hub.get.toMain.send UpdateState.init "Applying transaction..."
                progress = denominator/divisor
                hub.get.toMain.send Progress.init progress
            except: discard

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

proc reboot_apply_offline*(hub: ref Hub): Result[void, string] = 
  hub.toMain.send UpdateState.init("Rebooting...")
  let rc = execCmd("dnf5 offline reboot -y")
  if rc != 0:
    echo "Fail to run offline reboot, rc: " & $rc
    return err fmt"Fail to run offline reboot ({rc=})"
  hub.toMain.send UpdateState.init("Reboot command finished. If your computer isn't rebooting, this is a bug.\nApp will force-quit in 10 seconds.")
  sleep 10000
  quit(0)

const releasever* {.intdefine.}: int = 0

when releasever == 0:
  import std/macros
  macro x = error "Compiling this requires --define:releasever=..."
  x()

#proc get_releasever(): int =
#  let f = open("/etc/os-release")
#  defer: f.close()
#  for l in f.lines:
#    if l.starts_with("VERSION_ID="):
#      return l[11..12].parseInt
#  quit("cannot find VERSION_ID in /etc/os-release")