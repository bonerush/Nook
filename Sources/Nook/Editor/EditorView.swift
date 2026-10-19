import SwiftUI

struct EditorView: View {
    @ObservedObject var model: AppModel
    let actions: EditorActions

    @ObservedObject private var entrance = EntranceState()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                EditorToolbar(model: model, actions: actions)

                HStack(alignment: .top, spacing: 20) {
                    ScriptPaper(model: model)
                        .frame(maxWidth: NookMetrics.paperMaxWidth)
                        .frame(maxWidth: .infinity, alignment: .center)

                    if model.isInspectorVisible {
                        InspectorPane(model: model)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 10)
                .frame(maxHeight: .infinity)

                if hasPlanningError {
                    PlanningErrorBanner(model: model, actions: actions)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                EditorStatusBar(model: model)
            }
            .opacity(entrance.visible ? 1 : 0)
            .offset(y: entrance.visible || reduceMotion ? 0 : 8)
            .onAppear {
                withAnimation(
                    NookMotion.resolved(NookMotion.entrance, reduceMotion: reduceMotion)
                ) {
                    entrance.visible = true
                }
            }
            .allowsHitTesting(!model.isAISettingsPresented)

            if model.isAISettingsPresented {
                AISettingsOverlay(settings: model.aiSettings) {
                    model.closeAISettings()
                }
                .zIndex(10)
            }
        }
        .frame(minWidth: NookMetrics.windowMin.width, minHeight: NookMetrics.windowMin.height)
        .ignoresSafeArea(.container, edges: .top)
        .preferredColorScheme(.light)
        .animation(
            NookMotion.resolved(NookMotion.inspector, reduceMotion: reduceMotion),
            value: model.isInspectorVisible
        )
        .onExitCommand {
            if model.isAISettingsPresented {
                model.closeAISettings()
            } else if model.planningState == .planning {
                model.cancelPlanning()
            }
        }
    }
}
