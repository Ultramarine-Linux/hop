import results
import std/[osproc, strutils, strformat, times, tables, options]
import pkgs
import ../hub

const de_to_pkgs_to_add: Table[string, seq[string]] = {
  "Budgie": @["@ultramarine-flagship-product"],
  "GNOME": @["@ultramarine-gnome-product"],
  "KDE Plasma": @[if releasever < 41: "@ultramarine-kde-product" else: "@ultramarine-plasma-product"],
  "XFCE": @["@ultramarine-xfce-product"],
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
  hub.toMain.send MsgToMain DownloadFinish.init
