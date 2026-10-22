import results
import std/[times, osproc, tables, strformat, options]
import pkgs
import ../hub

let de_to_pkgs_to_change*: Table[string, string] = {
  "Budgie": if releasever < 43: "ultramarine-release-identity-flagship" else: "ultramarine-release-identity-budgie",
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
  let process = start_dnf5(["swap", "-y", "ultramarine-release-identity", to])
  let output = track_dnf5_download_progress(process, some(hub))
  ?end_proc(process, time, "Swap Editions", "swap editions")
  ?ensure_dnf5_did_something(output, "switch to " & to)
  if package_installed([to]).len == 0:
    return err fmt"dnf5 finished, but {to} is not installed."
  hub.toMain.send MsgToMain DownloadFinish.init
  ok()
