import std/[osproc, strutils, sugar, tables, sequtils]

const editions*: Table[string, string] = {
  "Budgie": "budgie-desktop",
  "GNOME": "gnome-desktop",
  "KDE Plasma": "plasma-desktop",
  "XFCE": "xfwm4",
}.toTable

proc package_installed*(pkg: string): bool =
  let stdout = execProcess("rpm -qa "&pkg)
  stdout.len != 0

proc package_installed*(pkgs: openArray[string]): seq[string] =
  let stdout = execProcess("rpm -qa "&pkgs.join(" "))
  collect:
    for line in stdout.splitLines:
      for pkg in pkgs:
        if line.starts_with(pkg): pkg


echo "Checking for installed desktops..."
let installed_desktops* = package_installed(editions.values.toSeq)
echo installed_desktops
