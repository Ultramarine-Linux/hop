import results
import fungus
import owlkettle
import owlkettle/adw
import ../[app, hub]
import ../backend/[add, pkgs]
import std/[strutils, strformat]

viewable AddDownloadPage:
  rootapp: AppState
  text: string = "Making sure dnf5 exists..."
  hub: ref Hub
  first: bool = true
  progress: float = 0.0

var thread: Thread[AddDownloadPageState]

proc setupThread(state: AddDownloadPageState) =
  assert state.hub[].toThrd.peek > 0
  proc th(state: AddDownloadPageState) {.thread.} =
    echo "Thread running"
    while true:
      if state.hub[].toThrd.peek == 0:
        continue
      let msg = state.hub[].toThrd.recv
      let edition = match msg:
      of AddDE as de: de
      of Reboot:
        let res = reboot_apply_offline state.hub
        if res.isErr:
          state.hub.toMain.send DnfError.init res.error
        continue
      else:
        echo "BUG: expected AddDE!!!"
        echo "BUG: found " & $msg
        return
      let res = add_de_offline(state.hub, edition)
      if res.isErr:
        state.hub.toMain.send DnfError.init res.error
  createThread(thread, th, state)


method view(state: AddDownloadPageState): Widget =
  if state.first:
    new state.hub
    open state.hub[].toMain
    open state.hub[].toThrd
    state.hub[].toThrd.send AddDE.init state.rootapp.cfgs["add-de"]
    setupThread(state)
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
        ProgressBar(fraction = state.progress)

export AddDownloadPage
