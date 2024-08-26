# Package

version       = "0.1.0"
author        = "madonuko"
description   = "Ultramarine Switcher"
license       = "GPL-3.0-or-later"
srcDir        = "src"
bin           = @["umswitch"]


# Dependencies

requires "nim >= 2.0.0"
requires "https://github.com/can-lehmann/owlkettle#HEAD"
requires "fungus"
requires "results"
