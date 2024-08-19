import owlkettle
import owlkettle/adw
import ../app

viewable ActionPage:
  rootapp: AppState

method view(state: ActionPageState): Widget = 
  result = gui:
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Ultramarine Hop"
      description = "Choose an action:"
      style = [StyleClass("compact")]
      Box(orient = OrientX, margin = 12, spacing = 8):
        Button:
          StatusPage:
            iconName = "gtk-add"
            title = "Add DE"
            style = [StyleClass("compact")]
          proc clicked = state.rootapp.page = "add"
        Button:
          StatusPage:
            iconName = "delete"
            title = "Remove DE"
            style = [StyleClass("compact")]
          proc clicked = state.rootapp.page = "delete"
        Button:
          StatusPage:
            iconName = "home"
            title = "Change Edition"
            style = [StyleClass("compact")]
          proc clicked = state.rootapp.page = "changeEdition"

export ActionPage
