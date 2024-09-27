import results
import fungus
import owlkettle
import owlkettle/adw
import ../[app, hub]
import ../backend/[pkgs, change]
import zError

viewable ChangeApplyPage:
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

var thread: Thread[ChangeApplyPageState]


generateSetupThread ChangeApplyPageState: swap

method view(state: ChangeApplyPageState): Widget =
  if state.first:
    state.first = false
    new state.hub
    open state.hub[].toMain
    open state.hub[].toThrd
    state.hub[].toThrd.send SendDE.init identities[state.rootapp.cfgs["change-edition"]]
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
      state.text = "The operation was successful. You may now close the app."
    else:
      echo "BUG: unexpected message: " & $msg
  gui:
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Switching to " & state.rootapp.cfgs["change-edition"] & " Edition"
      description = "This will take around 5 minutes."
      Box(orient = OrientY):
        Label(text = state.text)
        ProgressBar(fraction = state.progress):
          if state.progress == 1:
            style = [StyleClass("progress-finish")]

export ChangeApplyPage
