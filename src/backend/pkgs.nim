import results
import std/[osproc, strutils, strformat, sugar, tables, sequtils]

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
  result.ok()
