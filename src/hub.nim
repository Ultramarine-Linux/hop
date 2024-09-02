import fungus

adtEnum MsgToMain:
  UpdateState: string
  DnfError: string
  Progress: float
  DownloadFinish
adtEnum MsgToThrd:
  DeleteRebootDE: string
  ChangeEdition: string
  AddDE: string
  Reboot

type Hub* = object
  toMain*: Channel[MsgToMain]
  toThrd*: Channel[MsgToThrd]
