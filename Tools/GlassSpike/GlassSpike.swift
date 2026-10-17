import AppKit
import SwiftUI

@main
enum GlassSpikeMain {
    static var retainedDelegate: SpikeDelegate?

    static func main() {
        let app = NSApplication.shared
        let delegate = SpikeDelegate()
        retainedDelegate = delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class SpikeDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel!
    private var backdrop: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main!

        // A synthetic full-screen desktop so the glass samples our colors,
        // never the user's actual desktop or documents.
        backdrop = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        backdrop.backgroundColor = .white
        backdrop.isOpaque = true
        backdrop.level = .normal
        backdrop.contentView = NSHostingView(rootView: SpikeBackdrop())
        backdrop.orderFrontRegardless()

        let panelRect = NSRect(
            x: screen.frame.midX - 340,
            y: screen.frame.maxY - 360,
            width: 680,
            height: 230
        )
        panel = NSPanel(
            contentRect: panelRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.contentView = NSHostingView(rootView: SpikeGlassCard())
        panel.orderFrontRegardless()
    }
}

struct SpikeBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.98, blue: 1.0),
                    Color(red: 0.62, green: 0.77, blue: 1.0),
                    Color(red: 1.0, green: 0.76, blue: 0.55),
                    Color(red: 0.10, green: 0.12, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 22) {
                Text("DESKTOP CONTENT BEHIND THE GLASS")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(.black.opacity(0.62))
                HStack(spacing: 28) {
                    Circle().fill(.white.opacity(0.72)).frame(width: 120, height: 120)
                    RoundedRectangle(cornerRadius: 28)
                        .fill(.black.opacity(0.20))
                        .frame(width: 260, height: 120)
                    Circle().fill(Color(red: 0.2, green: 0.9, blue: 0.7).opacity(0.75))
                        .frame(width: 90, height: 90)
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct SpikeGlassCard: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            ZStack {
                Text("THANK YOU FOR TAKING THE TIME")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 640, height: 200)
            .glassEffect(
                .regular.tint(.black.opacity(0.22)),
                in: .rect(cornerRadius: 30)
            )
        } else {
            Text("Official glass requires macOS 26")
                .foregroundStyle(.white)
                .frame(width: 640, height: 200)
                .background(.black.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 30))
        }
    }
}
