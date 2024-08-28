# Package

version       = "0.1.0"
author        = "madonuko"
description   = "Ultramarine Switcher"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["umswitch"]


import nimsutils/src/nimsutils
import std/[syncio, strutils]

proc get_releasever(): int =
  for l in readFile("/etc/os-release").splitLines:
    if l.starts_with("VERSION_ID="):
      return l[11..12].parseInt
  error("cannot find VERSION_ID in /etc/os-release")
  quit 1

let releasever = get_releasever()
info "Detected releasever to be " & $releasever
#--define:"releasever=" & $releasever
switch("define", "releasever=" & $releasever)

xtask r, "alias for run": setCommand "run"
# Dependencies

requires "nim >= 2.0.0"
requires "https://github.com/can-lehmann/owlkettle#HEAD"
requires "fungus"
requires "results"