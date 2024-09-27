import owlkettle
import std/tables

viewable App:
  page: string = "action"
  cfgs: Table[string, string]
  installed_desktops: seq[string]
  installed_identities: seq[string]

export App, AppState, tables
