import results
import std/[os, osproc, streams, strutils, strformat, times, tables, sugar]
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
  track_dnf5_download_progress(process, x => discard x)
  end_proc(process, "Remove DE Offline", "arrange offline DE remove")
  reboot_apply_offline hub
