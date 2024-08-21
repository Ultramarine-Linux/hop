import fungus

adtEnum MsgToMain:
  UpdateState: string
  DnfError: string
adtEnum MsgToThrd:
  DeleteRebootDE: string


type Hub* = object
  toMain*: Channel[MsgToMain]
  toThrd*: Channel[MsgToThrd]


proc setupThread(hub: ref Hub): Thread[ref Hub] =
  proc th(hub: ref Hub) {.thread, nimcall.} =
    let de = match hub[].toThrd.recv:
    of DeleteRebootDE as inner_de: inner_de
    else:
      echo "BUG: expected DeleteRebootDE!!!"
      return
  createThread(result, th, hub)
