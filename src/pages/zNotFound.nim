import std/strformat
import owlkettle
import owlkettle/adw
import ../app

viewable NotFoundPage:
  rootapp: AppState

method view(state: NotFoundPageState): Widget = gui:
  StatusPage:
    iconName = "gtk-close"
    title = "Sorry! Something went wrong!"
    description = fmt"Technical Details: z-not-found: {state.rootapp.page}\n\n{state.rootapp.cfgs=}"
    style = [StyleClass("compact")]

export NotFoundPage, NotFoundPageState
