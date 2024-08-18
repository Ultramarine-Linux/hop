import std/options
import std/[os, osproc]
import strutils, strformat
import owlkettle, owlkettle/adw


when isMainModule:
  if not os.isAdmin():
    discard findExe("xhost").startProcess(args=["si:localuser:root"], options={poParentStreams}).waitForExit
    let x = findExe("pkexec").startProcess(args="umupgrader"&commandLineParams(), options={poParentStreams}).waitForExit
    discard findExe("xhost").startProcess(args=["-si:localuser:root"], options={poParentStreams}).waitForExit
    quit x
