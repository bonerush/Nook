import SwiftUI

struct EditorView: View {
    @ObservedObject var model: AppModel
    let actions: EditorActions

    private var isPlanning: Bool {
        if case .planning = model.planningState { return true }
        return false
    }

    private var hasPlanningError: Bool {
        if case .failed(_) = model.planningState { return true }
        return false
    }

    var body: some View {
        ZStack {
            NookCanvasBackground()

            VStack(spacing: 0) {
                EditorTopBar(model: model, actions: actions)

                if isPlanning {
                    Rectangle()
                        .fill(NookColor.accent)
                        .frame(height: 1)
                } else {
                    NookHairline()
                }

                HStack(spacing: 0) {
                    ScriptPane(model: model)
                    NookHairline().frame(width: 1)
                    InspectorPane(model: model)
                }
                .frame(maxHeight: .infinity)

                if hasPlanningError {
                    PlanningErrorBanner(model: model, actions: actions)
                }

                NookHairline()
                EditorStatusBar(model: model)
            }
            .allowsHitTesting(!model.isAISettingsPresented)

            if model.isAISettingsPresented {
                AISettingsOverlay(settings: model.aiSettings) {
                    model.closeAISettings()
                }
                .zIndex(10)
            }
        }
        .frame(minWidth: 960, minHeight: 680)
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(.light)
        .onExitCommand {
            if model.isAISettingsPresented {
                model.closeAISettings()
            } else if model.planningState == .planning {
                model.cancelPlanning()
            }
        }
    }
}
