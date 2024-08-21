import results
import std/[os, osproc, streams, strutils, strformat, times, tables, sugar, options]
import pkgs
import ../hub

const de_to_pkgs_to_add: Table[string, seq[string]] = {
    "Budgie": @["budgie-desktop"],
    "GNOME": @["gnome-shell"],
    "KDE Plasma": @["plasma-desktop"],
    "XFCE": @["xfwm4"],
}.toTable()

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
  track_dnf5_download_progress(process, some(hub))
  ?end_proc(process, time, "Downloading Packages", "arrange offline DE install")
  hub.toMain.send DownloadFinish.init
