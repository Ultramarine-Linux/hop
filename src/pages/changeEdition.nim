import owlkettle
import owlkettle/adw
import ../app

viewable ChangeEditionPage:
  rootapp: AppState

method view(state: ChangeEditionPageState): Widget = gui:
  StatusPage:
    iconName = "fedora-logo-icon"
    title = "Ultramarine Hop"
    description = "Which edition would you like to change to?"
    style = [StyleClass("compact")]
    Box(orient = OrientX, margin = 12, spacing = 8):
      discard

export ChangeEditionPage, ChangeEditionPageState
