import owlkettle
import owlkettle/adw
import ../app

viewable AddPage:
  rootapp: AppState

method view(state: AddPage): Widget = 
  result = gui:
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Ultramarine Hop"
      description = "Choose an desktop environment to add:"
      style = [StyleClass("compact")]
      Box(orient = OrientX, margin = 12, spacing = 8):
        discard

export AddPage
