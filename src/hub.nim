import fungus

adtEnum MsgToMain:
  UpdateState: string
  DnfError: string
adtEnum MsgToThrd:
  DeleteRebootDE: string

type Hub* = object
  toMain*: Channel[MsgToMain]
  toThrd*: Channel[MsgToThrd]
