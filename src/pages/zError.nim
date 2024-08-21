import owlkettle
import owlkettle/adw
import ../app

viewable ErrorPage:
  rootapp: AppState

method view(state: ErrorPageState): Widget = gui:
  StatusPage:
    iconName = "gtk-quit"
    title = "Sorry! Something went wrong!"
    description = state.rootapp.cfgs["error"]
    style = [StyleClass("compact")]

export ErrorPage
