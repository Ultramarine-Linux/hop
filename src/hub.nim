import fungus

adtEnum MsgToMain:
  UpdateState: string
  DnfError: string
  Progress: float
  DownloadFinish
adtEnum MsgToThrd:
  DeleteRebootDE: string

type Hub* = object
  toMain*: Channel[MsgToMain]
  toThrd*: Channel[MsgToThrd]
