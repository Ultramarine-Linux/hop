import std/[strutils, tables, strformat]
import owlkettle
import owlkettle/adw
import ../app
import ../backend/pkgs

const installed_tooltip_msg: string = "This desktop environment has already been installed."

viewable AddPage:
  rootapp: AppState

method view(state: AddPageState): Widget = gui:
  Box(orient = OrientY, spacing = 16, margin = 16):
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Ultramarine Hop"
      description = "Choose a desktop environment to add:"
      FlowBox(margin = 12, rowSpacing = 8, columnSpacing = 8):
        columns = 1..2
        for (name, pkg) in pkgs.editions.pairs:
          Button(text = name):
            if state.rootapp.installed_desktops.contains pkg:
              sensitive = false
              tooltip = installed_tooltip_msg
            proc clicked = state.rootapp.cfgs["add-de"] = name
            if state.rootapp.cfgs.getOrDefault("add-de") == name:
              style = [ButtonSuggested]
            else: style = []
    Box() {.expand: true.}
    Box(orient = OrientX) {.expand: false, vAlign: AlignEnd.}:
      Box() {.expand: true.}
      Button(text = "Confirm") {.expand: false, hAlign: AlignEnd.}:
        sensitive = false
        if state.rootapp.cfgs.contains "add-de":
          style = [ButtonSuggested]
          sensitive = true
          proc clicked =
            let (res, _) = state.rootapp.open: gui:
              MessageDialog:
                # TODO: when adding i18n support, use `%s`.
                message = dedent fmt"""
                  Are you sure you would like to install {state.rootapp.cfgs["add-de"]}? This will not remove your existing environment.
                  You may remove one later by running this app again after reboot.
                  
                  Click 'Continue' to start the download. After the download finishes, you will be prompted for a reboot.
                """
                DialogButton {.addButton.}:
                  text = "Cancel"
                  res = DialogCancel
                DialogButton {.addButton.}:
                  text = "Continue"
                  res = DialogAccept
                  style = [ButtonDestructive]
            if res.kind == DialogAccept:
              state.rootapp.page = "addDownload"

export AddPage, AddPageState
