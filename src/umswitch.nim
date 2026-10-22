import std/[os, osproc, sequtils, envvars, strutils]
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

method view(app: AppState): Widget = gui:
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

const
  ## PATH forced on the root process. The backend runs `rpm`, `dnf4`,
  ## `dnf5 offline reboot` via PATH, so the user's PATH (linuxbrew, nix, ~/bin
  ## ...) must never be inherited by root.
  rootPath* = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
  ## Only these variables are forwarded to the root process. Everything else
  ## (tokens, secrets, LD_*, GTK_MODULES, GIO_*, HOME, ...) is dropped: the
  ## command line is logged by pkexec/sudo and the values are trusted by root.
  forwardedEnv* = [
    "DISPLAY", "XAUTHORITY", "WAYLAND_DISPLAY", "XDG_SESSION_TYPE",
    "XDG_CURRENT_DESKTOP", "GDK_BACKEND", "GDK_SCALE", "GDK_DPI_SCALE",
    "LANG", "LANGUAGE",
  ]

proc isForwarded(key: string): bool =
  if key in forwardedEnv: return true
  # locale categories: LC_ALL, LC_CTYPE, LC_MESSAGES, ...
  key.len > 3 and key.startsWith("LC_") and key[3..^1].allIt(it in {'A'..'Z', '_'})

proc buildRootEnv*(env: openArray[(string, string)]): seq[string] =
  ## Builds the `K=V` assignments passed to `/usr/bin/env` when re-executing
  ## as root.
  ##
  ## Notes:
  ## * XDG_RUNTIME_DIR is deliberately NOT forwarded: root-run GTK/GLib/dconf
  ##   would otherwise create root-owned files in the user's /run/user/<uid>
  ##   and GLib would auto-discover the user's session bus at
  ##   $XDG_RUNTIME_DIR/bus. Instead a relative WAYLAND_DISPLAY is resolved to
  ##   an absolute socket path, which libwayland supports.
  ## * DBUS_SESSION_BUS_ADDRESS is forced to empty: the app does not need the
  ##   session bus (owlkettle's `brew(widget)` does not register a
  ##   GApplication), and a root process should not talk to services owned by
  ##   the unprivileged user. Leaving it unset is not enough: GLib would then
  ##   spawn `dbus-launch --autolaunch` from PATH; an empty address makes GLib
  ##   fail fast instead.
  var runtimeDir = ""
  for (k, v) in env:
    if k == "XDG_RUNTIME_DIR": runtimeDir = v
  for (k, v) in env:
    if k == "PATH" or not k.isForwarded: continue
    var v = v
    if k == "WAYLAND_DISPLAY" and not v.isAbsolute:
      if runtimeDir.len == 0 or not runtimeDir.isAbsolute: continue
      v = runtimeDir / v
    result.add k & "=" & v
  result.add "DBUS_SESSION_BUS_ADDRESS="
  result.add "PATH=" & rootPath

proc rootArgs*(env: openArray[(string, string)], app: string, params: openArray[string]): seq[string] =
  ## argv (after pkexec/sudo) used to re-run `app` as root.
  @["/usr/bin/env"] & buildRootEnv(env) & @[app] & @params

when isMainModule:
  if os.isAdmin():
    main()
    quit(0)
  let args = rootArgs(envPairs().toSeq, getAppFilename(), commandLineParams())
  when usesudo != 0:
    quit startProcess("/usr/bin/sudo", args=args, options={poParentStreams}).waitForExit
  else:
    # run umswitch as root via pkexec
    let xhost = findExe("xhost")
    if xhost.len > 0:
      discard xhost.startProcess(args=["si:localuser:root", "+localhost"], options={poParentStreams}).waitForExit
    let rc = startProcess("/usr/bin/pkexec", args=args, options={poParentStreams}).waitForExit
    if xhost.len > 0:
      discard xhost.startProcess(args=["-si:localuser:root", "-localhost"], options={poParentStreams}).waitForExit
    quit rc
