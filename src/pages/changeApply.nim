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


proc setupThread(hub: ref Hub): Thread[ref Hub] =
  assert hub[].toThrd.peek > 0
  proc th(hub: ref Hub) {.thread, nimcall.} =
    let msg = hub[].toThrd.recv
    let de = match msg:
    of DeleteRebootDE as inner_de: inner_de
    else:
      echo "BUG: expected DeleteRebootDE!!!"
      echo "BUG: found " & $msg
      return
    let res = remove_de_offline(hub, de)
    if res.isErr:
      hub.toMain.send DnfError.init res.error
  createThread(result, th, hub)


method view(state: ChangeApplyPageState): Widget =
  if state.first:
    open state.hub[].toMain
    open state.hub[].toThrd
    state.hub[].toThrd.send DeleteRebootDE.init state.rootapp.cfgs["rm-de"]
    state.th[] = setupThread(state.hub)
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
        Spinner(spinning = true)
        Label(text = state.text)

export ChangeApplyPage
