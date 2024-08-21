import results
import std/[os, osproc, streams, strutils, strformat, times, tables]
import pkgs
import ../hub

const de_to_pkgs_to_rm: Table[string, seq[string]] = {
    "Budgie": @["budgie-desktop"],
    "GNOME": @["gnome-shell"],
    "KDE Plasma": @["plasma-desktop"],
    "XFCE": @["xfwm4"],
}.toTable()

proc remove_de_offline*(hub: ref Hub, de: string): Result[void, string] {.thread.} =
  ?ensure_dnf5()
  hub.toMain.send UpdateState.init("Running dnf5...")
  echo fmt"┌──── BEGIN: Remove DE Offline ─────"
  let pkgs = de_to_pkgs_to_rm[de]
  echo "├═ Pkgs: "&pkgs.join(" ")
  stdout.write "┊ "
  let time = now()
  var args = @["rm", "-y", "--offline"]
  args &= pkgs
  let process = startProcess("dnf5", args=args, options = {poStdErrToStdOut})
  let outs = process.outputStream
  var line = ""
  
  while process.running:
    if outs.at_end: sleep(20)
    while not outs.at_end:
      let c = $outs.read_char
      if c == "\n":
        stdout.write "\n┊ "
        line = ""
      else:
        stdout.write c
        line = line & c
  block:
    let rc = process.peekExitCode
    echo "\n│"
    echo fmt"├═ Return code: {rc}"
    echo fmt"├═ Time taken: {now() - time}"
    echo fmt"└──── END OF Remove DE Offline ─────"
    if rc != 0:
      echo "Error: cannot arrange offline DE remove"
      return err fmt"Fail to arrange offline DE remove ({rc=})"
  process.close()
  hub.toMain.send UpdateState.init("Rebooting...")
  let rc = execCmd("dnf5 offline reboot -y")
  if rc != 0:
    echo "Fail to run offline reboot, rc: " & $rc
    return err fmt"Fail to run offline reboot ({rc=})"
  hub.toMain.send UpdateState.init("Reboot message sent. If your computer isn't rebooting, this is a bug.")
