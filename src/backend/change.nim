import results
import std/[osproc, tables, strutils, options]
import pkgs
import ../hub

let de_to_pkgs_to_change*: Table[string, string] = {
  "Budgie": "ultramarine-release-identity-flagship",
  "GNOME": "ultramarine-release-identity-gnome",
  "KDE Plasma": if releasever < 41: "ultramarine-release-identity-kde" else: "ultramarine-release-identity-plasma",
  "XFCE": "ultramarine-release-identity-xfce",
}.toTable

proc detect_swap_from*(): Result[string, string] =
  result = strip execProcess("rpm -qa 'ultramarine-release-identity-*'")
  if result.len == 0:
    return err "Cannot detect current release edition"

proc swap*(hub: ref Hub, to: string): Result[void, string] =
  ?ensure_dnf5()
  hub.toMain.send UpdateState.init "Swapping packages using dnf5..."
  echo fmt"┌──── BEGIN: Swap Editions ─────"
  let old = ?detect_swap_from()
  echo "├═ Old: "&old
  echo "├═ New: "&to
  stdout.write "┊ "
  let time = now()
  let process = startProcess("dnf5", args=["swap", "-y", old, to], options = {poStdErrToStdOut})
  track_dnf5_download_progress(process, some(hub))
  ?end_proc(process, time, "Swap Editions", "swap editions")
