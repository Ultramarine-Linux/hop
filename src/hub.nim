import fungus

type Hub* = object
  toMain*: Channel[string]
  toThrd*: Channel[string]

adtEnum MsgToMain:
  Test1
adtEnum MsgToThrd:
  Test2
