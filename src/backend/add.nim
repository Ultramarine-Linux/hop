import results
import std/[os, osproc, streams, strutils, strformat, times, tables, sugar]
import pkgs
import ../hub

const de_to_pkgs_to_add: Table[string, seq[string]] = {
    "Budgie": @["budgie-desktop"],
    "GNOME": @["gnome-shell"],
    "KDE Plasma": @["plasma-desktop"],
    "XFCE": @["xfwm4"],
}.toTable()


proc track_dnf5_download_progress*(process: Process, callback: proc(float)) {.thread.} =
  let outs = process.outputStream
  var line = ""

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
        if line.endsWith ']':
          try:
            let middle = line.find('/')
            if middle <= 0:
              continue
            let denominator = line[1..middle-1].parseInt
            let divisor = line[middle+1..^2].parseInt
            if denominator > 0 and divisor > 0:
              callback denominator/divisor
          except: discard

proc end_proc*(process: Process, action: string, errAction: string = ""): Result[void, string] {.thread.} =
  defer: process.close()
  if errAction == "": errAction = action
  let rc = process.peekExitCode
  echo "\n│"
  echo fmt"├═ Return code: {rc}"
  echo fmt"├═ Time taken: {now() - time}"
  echo fmt"└──── END OF {action} ─────"
  if rc != 0:
    echo "Error: cannot " & errAction
    return err fmt"Fail to {errAction} ({rc=})"

proc add_de_offline*(hub: ref Hub, de: string): Result[void, string] {.thread.} =
  ?ensure_dnf5()
  hub.toMain.send UpdateState.init "Downloading packages..."
  echo fmt"┌──── BEGIN: Downloading packages ─────"
  let pkgs = de_to_pkgs_to_add[de]
  echo "├═ Pkgs: "&pkgs.join(" ")
  stdout.write "┊ "
  let time = now()
  var args = @["in", "-y", "--offline"]
  args &= pkgs
  let process = startProcess("dnf5", args=args, options = {poStdErrToStdOut})

  track_dnf5_download_progress(process, progress => hub.toMain.send Progress.init progress)
  ?end_proc(process, "Downloading Packages", "arrange offline DE install")
  hub.toMain.send DownloadFinish.init
