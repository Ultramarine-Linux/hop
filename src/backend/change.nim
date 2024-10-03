import results
import std/[times, osproc, tables, strformat, options]
import pkgs
import ../hub

let de_to_pkgs_to_change*: Table[string, string] = {
  "Budgie": "ultramarine-release-identity-flagship",
  "GNOME": "ultramarine-release-identity-gnome",
  "KDE Plasma": if releasever < 41: "ultramarine-release-identity-kde" else: "ultramarine-release-identity-plasma",
  "XFCE": "ultramarine-release-identity-xfce",
}.toTable

proc swap*(hub: ref Hub, to: string): Result[void, string] {.thread.} =
  ?ensure_dnf5()
  echo "Swapping packages..."
  hub.toMain.send UpdateState.init "Swapping packages using dnf5..."
  echo fmt"┌──── BEGIN: Swap Editions ─────"
  echo "├═ New: "&to
  stdout.write "┊ "
  let time = now()
  let process = startProcess("/usr/bin/dnf5", args=["swap", "-y", "ultramarine-release-identity", to], options = {poStdErrToStdOut})
  track_dnf5_download_progress(process, some(hub))
  ?end_proc(process, time, "Swap Editions", "swap editions")
  hub.toMain.send MsgToMain DownloadFinish.init
  ok[void]()
