import std/[os, osproc, sequtils]
import owlkettle, owlkettle/adw
import app
import pages/[action, add, addDownload, delete, deleteReboot, change, changeApply, zNotFound, zError]
import backend/pkgs

const
  # logfilepath: string = "/tmp/umswitch.log"
  usesudo {.intdefine.} = 0

# FIXME: make progressbars green when fraction = 1.0
let
  stylesheets: array[1, StyleSheet] = [newStyleSheet("""
    .progress-finish.progressbar {
      background-color: green;
    }
""")]

method view(app: AppState): Widget =
  result = gui:
    AdwWindow:
      defaultSize = (1000, 800)
      Box(orient = OrientY):
        AdwHeaderBar {.expand: false.}:
          style = HeaderBarFlat

        case app.page
        of "action": ActionPage(rootapp = app)
        of "add": AddPage(rootapp = app)
        of "addDownload": AddDownloadPage(rootapp = app)
        of "change": ChangePage(rootapp = app)
        of "changeApply": ChangeApplyPage(rootapp = app)
        of "delete": DeletePage(rootapp = app)
        of "deleteReboot": DeleteRebootPage(rootapp = app)
        of "zError": ErrorPage(rootapp = app)
        else: NotFoundPage(rootapp = app)

proc main =
  # logfilepath.writeFile "" # creates the logfile
  # let logfile = open(logfilepath, fmWrite)
  # defer: logfile.close()
  adw.brew(gui App(
    installed_desktops=package_installed(editions.values.toSeq),
    installed_identities=package_installed(identities.values.toSeq),
  ), stylesheets=stylesheets)

when isMainModule:
  if os.isAdmin():
    main()
    quit(0)
  when usesudo != 0:
    let x = findExe("sudo").startProcess(args=getAppFilename()&commandLineParams(), options={poParentStreams}).waitForExit
  else:
    # run umswitch as root via pkexec
    discard findExe("xhost").startProcess(args=["si:localuser:root", "+localhost"], options={poParentStreams}).waitForExit
    let x = findExe("pkexec").startProcess(args=getAppFilename()&commandLineParams(), options={poParentStreams}).waitForExit
    discard findExe("xhost").startProcess(args=["-si:localuser:root", "-localhost"], options={poParentStreams}).waitForExit
  quit x
