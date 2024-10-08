import std/[strutils, strformat]
import owlkettle
import owlkettle/adw
import ../app
import ../backend/pkgs

viewable ChangePage:
  rootapp: AppState

method view(state: ChangePageState): Widget = gui:
  Box(orient = OrientY, spacing = 16, margin = 16):
    StatusPage:
      iconName = "fedora-logo-icon"
      title = "Ultramarine Hop"
      description = "Which edition would you like to change to?"
      style = [StyleClass("compact")]
      Box(orient = OrientX, margin = 12, spacing = 8):
        FlowBox(margin = 12, rowSpacing = 8, columnSpacing = 8):
          columns = 1..2
          for (name, pkg) in pkgs.identities.pairs:
            Button(text = name):
              proc clicked = state.rootapp.cfgs["change-edition"] = name
              if state.rootapp.cfgs.getOrDefault("change-edition") == name:
                style = [ButtonSuggested]
              else: style = []
              if state.rootapp.installed_identities.contains pkg:
                sensitive = false
                tooltip = "This is your current edition"
    Box() {.expand: true.}
    Box(orient = OrientX) {.expand: false, vAlign: AlignEnd.}:
      Box() {.expand: true.}
      Button(text = "Confirm") {.expand: false, hAlign: AlignEnd.}:
        sensitive = false
        if state.rootapp.cfgs.contains "change-edition":
          style = [ButtonSuggested]
          sensitive = true
          proc clicked =
            let (res, _) = state.rootapp.open: gui:
              MessageDialog:
                # TODO: when adding i18n support, use `%s`.
                message = dedent fmt"""
                  Are you sure you would like to change to {state.rootapp.cfgs["change-edition"]}? This will not remove your existing environment.
                  You may remove one later by running this app again after reboot.
                  
                  Click 'Continue' to swap.
                """
                DialogButton {.addButton.}:
                  text = "Cancel"
                  res = DialogCancel
                DialogButton {.addButton.}:
                  text = "Continue"
                  res = DialogAccept
                  style = [ButtonDestructive]
            if res.kind == DialogAccept:
              state.rootapp.page = "changeApply"
export ChangePage
