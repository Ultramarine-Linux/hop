import std/tables
import owlkettle
import owlkettle/adw
import ../app
import ../backend/pkgs

const installed_tooltip_msg: string = "This desktop environment has already been installed."

viewable AddPage:
  rootapp: AppState

method view(state: AddPageState): Widget = gui:
  StatusPage:
    iconName = "fedora-logo-icon"
    title = "Ultramarine Hop"
    description = "Choose a desktop environment to add:"
    style = [StyleClass("compact")]
    Box(orient = OrientX, margin = 12, spacing = 8):
      for (name, pkg) in pkgs.editions.pairs:
        Button(text = name):
          if installed_desktops.contains pkg:
            sensitive = false
            tooltip = installed_tooltip_msg

export AddPage, AddPageState
