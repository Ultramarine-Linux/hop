import std/macros
import fungus

adtEnum MsgToMain:
  UpdateState: string
  DnfError: string
  Progress: float
  DownloadFinish
adtEnum MsgToThrd:
  SendDE: string
  Reboot

type Hub* = object
  toMain*: Channel[MsgToMain]
  toThrd*: Channel[MsgToThrd]

template generateSetupThread*(State: untyped, f: untyped) =
  var thread: Thread[State]

  proc setupThread(state: State) =
    assert state.hub[].toThrd.peek > 0
    proc th(state: State) {.thread.} =
      echo "Thread running"
      while true:
        if state.hub[].toThrd.peek == 0:
          continue
        let msg = state.hub.toThrd.recv
        let res = match msg:
        of SendDE as de: f(state.hub, de)
        of Reboot: reboot_apply_offline state.hub
        else:
          echo "BUG: unimplemented reached in setupThread!"
          return
        echo "th: res: " & $res
        if res.isErr: state.hub.toMain.send DnfError.init res.error
    createThread(thread, th, state)
