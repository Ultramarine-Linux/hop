import results
import fungus
import owlkettle
import owlkettle/adw
import ../[app, hub]
import ../backend/[add, pkgs]
import zError
import std/[strutils, strformat]

viewable AddDownloadPage:
  rootapp: AppState
  text: string = "Making sure dnf5 exists..."
  hub: ref Hub
  first: bool = true
  progress: float = 0.0
  
  hooks:
    afterBuild:
      proc redrawer(): bool =
        if state.hub[].toMain.peek > 0:
          discard redraw state
        
        const KEEP_LISTENER_ACTIVE = true
        return KEEP_LISTENER_ACTIVE
      discard addGlobalTimeout(200, redrawer)

var thread: Thread[AddDownloadPageState]


generateSetupThread AddDownloadPageState: add_de_offline

method view(state: AddDownloadPageState): Widget =
  if state.first:
    state.first = false
    new state.hub
    open state.hub[].toMain
    open state.hub[].toThrd
    state.hub[].toThrd.send SendDE.init state.rootapp.cfgs["add-de"]
    setupThread(state)
  while state.hub[].toMain.peek > 0:
    let msg = state.hub[].toMain.recv
    match msg:
    of UpdateState as text:
      state.text = text
    of DnfError as err:
      state.rootapp.cfgs["error"] = err
      state.rootapp.page = "zError"
      return gui: ErrorPage(rootapp = state.rootapp)
    of Progress as prog:
      state.progress = prog
    of DownloadFinish:
      state.progress = 1
      let _ = state.rootapp.open: gui:
        MessageDialog:
          # TODO: when adding i18n support, use `%s`.
          message = dedent fmt"""
            The system is ready to reboot in order to install {state.rootapp.cfgs["add-de"]}. This will not remove your existing environment.
            You may remove one later by running this app again after reboot.

            Click 'Reboot' to reboot instantly.
          """
          DialogButton {.addButton.}:
            text = "Continue"
            res = DialogAccept
            style = [ButtonDestructive]
      state.hub[].toThrd.send MsgToThrd Reboot.init
    else:
      echo "BUG: unexpected message: " & $msg
  gui:
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Downloading " & state.rootapp.cfgs["add-de"]
      description = "This will take a while."
      Box(orient = OrientY):
        Label(text = state.text)
        ProgressBar(fraction = state.progress):
          if state.progress == 1:
            style = [StyleClass("progress-finish")]

export AddDownloadPage
