import owlkettle
import owlkettle/adw
import ../app

viewable ActionPage:
  rootapp: AppState

method view(state: ActionPageState): Widget = 
  result = gui:
    StatusPage:
      title = "Ultramarine Hop"
      description = "Choose an action:"
      Box(orient = OrientY):
        Box(orient = OrientX):
          discard

export ActionPage
