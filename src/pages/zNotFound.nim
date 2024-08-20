import owlkettle
import owlkettle/adw
import ../app

viewable NotFoundPage:
  rootapp: AppState

method view(state: NotFoundPageState): Widget = gui:
  StatusPage:
    iconName = "gtk-close"
    title = "Sorry! Something went wrong!"
    description = "Technical Details: z-not-found: " & state.rootapp.page
    style = [StyleClass("compact")]

export NotFoundPage, NotFoundPageState
