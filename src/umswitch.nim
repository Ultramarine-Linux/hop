import owlkettle, owlkettle/adw
import app
import pages/[action, add, delete, deleteReboot, changeEdition, zNotFound, zError]

const
  logfilepath: string = "/tmp/umswitch.log"
  debug = 1
let
  stylesheets: array[1, StyleSheet] = [loadStylesheet("src/style.css")]

method view(app: AppState): Widget =
  result = gui:
    AdwWindow:
      defaultSize = (800, 600)
      Box(orient = OrientY):
        AdwHeaderBar {.expand: false.}:
          style = HeaderBarFlat

        case app.page
        of "action": ActionPage(rootapp = app)
        of "add": AddPage(rootapp = app) 
        of "changeEdition": ChangeEditionPage(rootapp = app)
        of "delete": DeletePage(rootapp = app)
        of "deleteReboot": DeleteRebootPage(rootapp = app)
        of "zError": ErrorPage(rootapp = app)
        else: NotFoundPage(rootapp = app)

proc main =
  logfilepath.writeFile "" # creates the logfile
  let logfile = open(logfilepath, fmWrite)
  defer: logfile.close()
  adw.brew(gui App(), stylesheets=stylesheets)

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
