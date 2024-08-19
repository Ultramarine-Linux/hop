import fungus

adtEnum MsgToMain:
  Test1
adtEnum MsgToThrd:
  Test2

type Hub* = object
  toMain*: Channel[MsgToMain]
  toThrd*: Channel[MsgToThrd]
