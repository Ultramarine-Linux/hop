import results
import fungus
import owlkettle
import owlkettle/adw
import ../[app, hub]
import ../backend/[pkgs, delete]

viewable DeleteRebootPage:
  rootapp: AppState
  text: string = "Making sure dnf5 exists..."
  hub: ref Hub
  first: bool = true

  hooks:
    afterBuild:
      proc redrawer(): bool =
        if state.hub[].toMain.peek > 0:
          discard redraw state
        
        const KEEP_LISTENER_ACTIVE = true
        return KEEP_LISTENER_ACTIVE
      discard addGlobalTimeout(200, redrawer)

var thread: Thread[DeleteRebootPageState]


generateSetupThread DeleteRebootPageState: remove_de_offline

method view(state: DeleteRebootPageState): Widget =
  if state.first:
    state.first = false
    new state.hub
    open state.hub[].toMain
    open state.hub[].toThrd
    state.hub[].toThrd.send SendDE.init state.rootapp.cfgs["rm-de"]
    setupThread(state)
  while state.hub[].toMain.peek > 0:
    let msg = state.hub[].toMain.recv
    match msg:
    of UpdateState as text:
      state.text = text
    of DnfError as err:
      state.rootapp.cfgs["error"] = err
      state.rootapp.page = "zError"
    else:
      echo "BUG: unexpected message: " & $msg
  gui:
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Erasing " & state.rootapp.cfgs["rm-de"]
      description = "The system reboot will happen shortly..."
      Box(orient = OrientX):
        Box() {.expand: true.}
        Spinner(spinning = true) {.expand: false.}:
          size_request = (25, 25)
        Label(text = state.text, margin = 5) {.expand: false.}
        Box() {.expand: true.}

export DeleteRebootPage
