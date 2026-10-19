import SwiftUI

struct PlanningErrorBanner: View {
    @ObservedObject var model: AppModel
    let actions: EditorActions

    private var message: String {
        guard case .failed(let failure) = model.planningState else { return "" }
        switch failure {
        case .disabled:
            return "AI is not configured. Local phrasing is ready."
        case .unauthorized:
            return "API key rejected. Check AI settings."
        case .rateLimited:
            return "Rate limited. Try again shortly."
        case .timeout:
            return "AI request timed out. Try again."
        case .network:
            return "AI unavailable. Check your connection."
        case .truncated:
            return "AI response was truncated. Try a shorter script."
        case .server(let code) where code == 400 || code == 404:
            return "Endpoint or model rejected (HTTP \(code))."
        case .server(let code):
            return "Provider error (HTTP \(code))."
        case .invalidResponse, .invalidPlan:
            return "AI returned an unusable plan."
        case .emptyScript:
            return "Add a script first."
        case .tooLong:
            return "Script is too long for AI phrasing."
        case .cancelled:
            return "AI planning was cancelled."
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(NookColor.danger)

            Text(message)
                .font(NookType.micro)
                .foregroundStyle(NookColor.textPrimary.opacity(0.84))
                .lineLimit(1)

            Spacer(minLength: 12)

            Button("Retry AI", action: actions.retryAI)
                .buttonStyle(NookSecondaryButtonStyle())
            Button("Start locally", action: actions.startLocal)
                .buttonStyle(NookSecondaryButtonStyle())
            Button("Settings", action: actions.openAISettings)
                .buttonStyle(NookSecondaryButtonStyle())
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
        .background(NookColor.danger.opacity(0.05))
        .overlay(alignment: .top) { NookHairline(color: NookColor.danger.opacity(0.18)) }
        .overlay(alignment: .bottom) { NookHairline(color: NookColor.danger.opacity(0.18)) }
    }
}
