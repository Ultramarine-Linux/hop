import results
import std/[osproc, strutils, strformat, times, tables, options]
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
  echo "Removing packages..."
  hub.toMain.send UpdateState.init("Running dnf5...")
  echo fmt"┌──── BEGIN: Remove DE Offline ─────"
  let pkgs = de_to_pkgs_to_rm[de]
  echo "├═ Pkgs: "&pkgs.join(" ")
  stdout.write "┊ "
  let time = now()
  var args = @["rm", "-y", "--offline"]
  args &= pkgs
  let process = startProcess("dnf5", args=args, options = {poStdErrToStdOut})
  track_dnf5_download_progress(process, none(ref Hub))
  ?end_proc(process, time, "Remove DE Offline", "arrange offline DE remove")
  ?reboot_apply_offline hub
