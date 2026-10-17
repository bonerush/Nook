import SwiftUI

struct EditorView: View {
    @ObservedObject var model: AppModel
    let actions: EditorActions

    var body: some View {
        ZStack {
            LinearCanvasBackground()

            VStack(spacing: 0) {
                EditorTopBar(model: model, onStart: actions.start)
                LinearHairline()

                HStack(spacing: 0) {
                    ScriptPane(model: model)
                    LinearHairline().frame(width: 1)
                    InspectorPane(model: model)
                }
                .frame(maxHeight: .infinity)

                LinearHairline()
                EditorStatusBar(model: model)
            }
        }
        .frame(minWidth: 960, minHeight: 680)
        .preferredColorScheme(.dark)
    }
}
