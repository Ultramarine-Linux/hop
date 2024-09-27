import std/[tables, strutils, strformat]
import owlkettle
import owlkettle/adw
import ../app
import ../backend/pkgs

const installed_tooltip_msg: string = "This desktop environment is not installed."

viewable DeletePage:
  rootapp: AppState

method view(state: DeletePageState): Widget = gui:
  Box(orient = OrientY, spacing = 16, margin = 16):
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Ultramarine Hop"
      description = "Choose an desktop environment to remove:"
      style = [StyleClass("compact")]
      FlowBox(margin = 12, rowSpacing = 8, columnSpacing = 8):
        columns = 1..2
        for (name, pkg) in pkgs.editions.pairs:
          Button(text = name):
            if not state.rootapp.installed_desktops.contains pkg:
              sensitive = false
              tooltip = installed_tooltip_msg
            proc clicked = state.rootapp.cfgs["rm-de"] = name
            if state.rootapp.cfgs.getOrDefault("rm-de") == name:
              style = [ButtonSuggested]
            else: style = []
    Box() {.expand: true.}
    Box(orient = OrientX) {.expand: false, vAlign: AlignEnd.}:
      Box() {.expand: true.}
      Button(text = "Confirm") {.expand: false, hAlign: AlignEnd.}:
        sensitive = false
        if state.rootapp.cfgs.contains "rm-de":
          style = [ButtonSuggested]
          sensitive = true
          proc clicked =
            let (res, _) = state.rootapp.open: gui:
              MessageDialog:
                # TODO: when adding i18n support, use `%s`.
                message = dedent fmt"""
                  Are you sure you would like to erase {state.rootapp.cfgs["rm-de"]}?

                  Click 'Continue' to reboot your computer now for the removal.
                """
                DialogButton {.addButton.}:
                  text = "Cancel"
                  res = DialogCancel
                DialogButton {.addButton.}:
                  text = "Continue"
                  res = DialogAccept
                  style = [ButtonDestructive]
            if res.kind == DialogAccept:
              state.rootapp.page = "deleteReboot"

export DeletePage, DeletePageState
