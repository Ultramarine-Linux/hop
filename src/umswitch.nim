import std/options
import std/[os, osproc, sugar]
import strutils, strformat
import owlkettle, owlkettle/adw
import app
import pages/[action]

const
  logfilepath: string = "/tmp/umswitch.log"
  debug = 1

method view(app: AppState): Widget =
  result = gui:
    AdwWindow:
      defaultSize = (800, 600)
      Box(orient = OrientY):
        AdwHeaderBar {.expand: false.}:
          style = HeaderBarFlat

        case app.page_index
        of 0: ActionPage()
        else: discard

proc main =
  logfilepath.writeFile "" # creates the logfile
  let logfile = open(logfilepath, fmWrite)
  defer: logfile.close()
  adw.brew gui App()

when isMainModule and debug == 0:
  if os.isAdmin():
    main()
    quit(0)
  # run umswitch as root via pkexec
  discard findExe("xhost").startProcess(args=["si:localuser:root"], options={poParentStreams}).waitForExit
  let x = findExe("pkexec").startProcess(args="umswitch"&commandLineParams(), options={poParentStreams}).waitForExit
  discard findExe("xhost").startProcess(args=["-si:localuser:root"], options={poParentStreams}).waitForExit
  quit x
when isMainModule and debug == 1:
  main()
  quit(0)
