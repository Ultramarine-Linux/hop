import results
import fungus
import owlkettle
import owlkettle/adw
import ../[app, hub]
import ../backend/pkgs

viewable ChangeApplyPage:
  rootapp: AppState
  text: string = "Making sure dnf5 exists..."
  hub: ref Hub
  first: bool = true
  th: ref Thread[ref Hub]
  prog: float = 0.0


proc setupThread(hub: ref Hub): Thread[ref Hub] =
  assert hub[].toThrd.peek > 0
  proc th(hub: ref Hub) {.thread, nimcall.} =
    let msg = hub[].toThrd.recv
    let edition = match msg:
    of ChangeEdition as edition: edition
    else:
      echo "BUG: expected ChangeEdition!!!"
      echo "BUG: found " & $msg
      return
    let res = swap(hub, edition)
    if res.isErr:
      hub.toMain.send DnfError.init res.error
  createThread(result, th, hub)


method view(state: ChangeApplyPageState): Widget =
  if state.first:
    open state.hub[].toMain
    open state.hub[].toThrd
    state.hub[].toThrd.send ChangeEdition.init state.rootapp.cfgs["change-edition"]
    state.th[] = setupThread(state.hub)
  while state.hub[].toMain.peek > 0:
    let msg = state.hub[].toMain.recv
    match msg:
    of UpdateState as text:
      state.text = text
    of DnfError as err:
      state.rootapp.cfgs["error"] = err
      state.rootapp.page = "zError"
    of Progress as prog:
      state.progress = prog
    else:
      echo "BUG: unexpected message: " & $msg
  gui:
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Switching to " & state.rootapp.cfgs["change-edition"] & " Edition"
      description = "This will take around 5 minutes."
      Box(orient = OrientY):
        Label(text = state.text)
        ProgressBar(fraction = state.progress)

export ChangeApplyPage
