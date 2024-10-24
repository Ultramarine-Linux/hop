import owlkettle
import owlkettle/adw
import ../app

viewable ActionPage:
  rootapp: AppState

method view(state: ActionPageState): Widget = gui:
  StatusPage:
    iconName = "fedora-logo-icon"
    title = "Ultramarine Hop"
    description = "Choose an action:"
    style = [StyleClass("compact")]
    Box(orient = OrientY, margin = 12, spacing = 8):
      Button:
        # StatusPage:
          # iconName = "gtk-add"
          # title = "Add DE"
          # style = [StyleClass("compact")]
        text = "Add DE"
        proc clicked = state.rootapp.page = "add"
      Button:
        # StatusPage:
        #   iconName = "delete"
        #   title = "Remove DE"
        #   style = [StyleClass("compact")]
        text = "Remove DE"
        if state.rootapp.installed_desktops.len == 1:
          sensitive = false
          tooltip = "You cannot remove any more desktops because you have only 1 installed."
        proc clicked = state.rootapp.page = "delete"
      Button:
        # StatusPage:
        #   iconName = "home"
        #   title = "Change Edition"
        #   style = [StyleClass("compact")]
        text = "Change Edition"
        proc clicked = state.rootapp.page = "change"

export ActionPage, ActionPageState
