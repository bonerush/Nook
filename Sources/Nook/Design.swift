import AppKit
import SwiftUI

// MARK: - Time formatting

enum NookTime {
    static func clock(_ seconds: TimeInterval, rounding: FloatingPointRoundingRule = .down) -> String {
        let value = max(0, seconds.rounded(rounding))
        let total = Int(value)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func remaining(_ seconds: TimeInterval) -> String {
        "−" + clock(seconds, rounding: .up)
    }

    static func total(_ seconds: TimeInterval) -> String {
        clock(seconds, rounding: .up)
    }
}

// MARK: - Official fallback material

/// Used only when the system Liquid Glass API is unavailable (macOS < 26).
/// The production glass path is SwiftUI's glassEffect.
struct NookVisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        view.appearance = NSAppearance(named: .darkAqua)
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = cornerRadius > 0
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.wantsLayer = true
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.masksToBounds = cornerRadius > 0
    }
}
