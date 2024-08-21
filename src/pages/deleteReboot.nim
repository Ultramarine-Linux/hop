import results
import fungus
import owlkettle
import owlkettle/adw
import ../[app, hub]
import ../backend/delete

viewable DeleteRebootPage:
  rootapp: AppState
  text: string = "Making sure dnf5 exists..."
  hub: ref Hub
  first: bool = true
  th: ref Thread[ref Hub]


proc setupThread(hub: ref Hub): Thread[ref Hub] =
  proc th(hub: ref Hub) {.thread, nimcall.} =
    let de = match hub[].toThrd.recv:
    of DeleteRebootDE as inner_de: inner_de
    else:
      echo "BUG: expected DeleteRebootDE!!!"
      return
    let res = remove_de_offline(hub, de)
    if res.isErr:
      hub.toMain.send DnfError.init res.error
  createThread(result, th, hub)


method view(state: DeleteRebootPageState): Widget =
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

export DeleteRebootPage
