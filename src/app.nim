import owlkettle
import std/tables

viewable App:
  page: string = "action"
  cfgs: Table[string, string]

export App, AppState, tables
