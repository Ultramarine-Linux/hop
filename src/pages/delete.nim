import std/tables
import owlkettle
import owlkettle/adw
import ../app
import ../backend/pkgs

const installed_tooltip_msg: string = "This desktop environment is not installed."

viewable DeletePage:
  rootapp: AppState

method view(state: DeletePageState): Widget = gui:
  StatusPage:
    iconName = "fedora-logo-icon"
    title = "Ultramarine Hop"
    description = "Choose an desktop environment to remove:"
    style = [StyleClass("compact")]
    Box(orient = OrientX, margin = 12, spacing = 8):
      for (name, pkg) in pkgs.editions.pairs:
        Button(text = name):
          if not installed_desktops.contains pkg:
            sensitive = false
            tooltip = installed_tooltip_msg

export DeletePage, DeletePageState
