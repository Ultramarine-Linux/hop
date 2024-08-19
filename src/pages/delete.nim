import owlkettle
import owlkettle/adw
import ../app

viewable DeletePage:
  rootapp: AppState

method view(state: DeletePage): Widget = 
  result = gui:
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Ultramarine Hop"
      description = "Choose an desktop environment to remove:"
      style = [StyleClass("compact")]
      Box(orient = OrientX, margin = 12, spacing = 8):
        discard

export DeletePage
