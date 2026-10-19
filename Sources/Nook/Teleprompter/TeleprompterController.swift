import AppKit
import Combine
import QuartzCore
import SwiftUI

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class TeleprompterController {
    let engine: PlaybackEngine
    private let model: AppModel
    private let forceVisibleInCapture: Bool

    private var panel: NotchPanel!
    private var hostingView: NSHostingView<TeleprompterView>!
    private var cancellables = Set<AnyCancellable>()
    private var presentationGeneration = 0
    private var hoverTimer: Timer?
    private var hoverActive = false

    private(set) var isPresented = false
    var onHoverChanged: ((Bool) -> Void)?

    init(model: AppModel, engine: PlaybackEngine, forceVisibleInCapture: Bool = false) {
        self.model = model
        self.engine = engine
        self.forceVisibleInCapture = forceVisibleInCapture
        configurePanel()
        bindModel()
        engine.load(model.document, preservePosition: false)
        applyFrame(animated: false)
        updateCaptureVisibility()
    }

    // MARK: Setup

    private func configurePanel() {
        let initialFrame = targetWindowFrame()

        panel = NotchPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.animationBehavior = .none
        panel.title = "Nook"
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.tabbingMode = .disallowed

        let hosting = NSHostingView(rootView: TeleprompterView(engine: engine, model: model))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.isOpaque = false
        hostingView = hosting
        panel.contentView = hosting
        panel.setFrame(initialFrame, display: false)
    }

    private func bindModel() {
        model.$document
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] document in
                guard let self else { return }
                self.engine.load(document, preservePosition: true)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(model.$fontSize, model.$cardWidth)
            .dropFirst()
            .sink { [weak self] _ in
                self?.applyFrame(animated: false)
            }
            .store(in: &cancellables)

        model.$hideFromCapture
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateCaptureVisibility()
            }
            .store(in: &cancellables)
    }

    // MARK: Presentation

    func show(autoplay: Bool) {
        if autoplay {
            engine.load(model.document, preservePosition: false)
            engine.resetPosition()
        }

        presentationGeneration += 1
        let generation = presentationGeneration
        let finalFrame = targetWindowFrame()

        applyFrame(animated: false)

        if !isPresented {
            let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            var startFrame = finalFrame
            if !reduceMotion {
                startFrame.origin.y += 9
                startFrame.size.width = finalFrame.width * 0.985
                startFrame.origin.x = finalFrame.midX - startFrame.width / 2
            }
            panel.alphaValue = 0
            panel.setFrame(startFrame, display: false)
            isPresented = true
            panel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0.12 : 0.32
                context.timingFunction = reduceMotion
                    ? CAMediaTimingFunction(name: .easeOut)
                    : CAMediaTimingFunction(controlPoints: 0.16, 0.84, 0.30, 1.0)
                panel.animator().alphaValue = 1
                panel.animator().setFrame(finalFrame, display: true)
            } completionHandler: { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, self.presentationGeneration == generation else { return }
                    self.panel.alphaValue = 1
                }
            }
        } else {
            panel.orderFrontRegardless()
            panel.alphaValue = 1
            panel.setFrame(finalFrame, display: true)
        }

        if autoplay {
            engine.play()
        } else if engine.isPlaying {
            engine.pause()
        }

        if ProcessInfo.processInfo.environment["NOOK_NO_HOVER"] != "1" {
            startHoverTracking()
        }
        debugLayoutIfNeeded()
    }

    func hide(animated: Bool = true, pause: Bool = true) {
        stopHoverTracking()
        if pause {
            engine.pause()
        }

        guard isPresented else { return }

        presentationGeneration += 1
        let generation = presentationGeneration
        isPresented = false

        if !animated {
            panel.alphaValue = 0
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0.12 : 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.presentationGeneration == generation, !self.isPresented else { return }
                self.panel.orderOut(nil)
                self.panel.alphaValue = 1
            }
        }
    }

    func toggleVisibility() {
        if isPresented {
            hide()
        } else {
            show(autoplay: false)
        }
    }

    func reposition() {
        applyFrame(animated: isPresented)
        updateHoverState()
        debugLayoutIfNeeded()
    }

    // MARK: Hover context

    private func startHoverTracking() {
        guard isPresented else { return }
        if hoverTimer != nil { return }
        let timer = Timer(timeInterval: 0.08, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateHoverState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
        updateHoverState()
    }

    private func stopHoverTracking() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        setHoverActive(false)
    }

    private func updateHoverState() {
        guard isPresented, panel != nil else {
            setHoverActive(false)
            return
        }
        let point = NSEvent.mouseLocation
        setHoverActive(panel.frame.contains(point))
    }

    private func setHoverActive(_ active: Bool) {
        guard active != hoverActive else { return }
        hoverActive = active
        onHoverChanged?(active)
    }

    deinit {
        hoverTimer?.invalidate()
    }

    // MARK: Geometry

    private func screenForPrompter() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: {
            $0.safeAreaInsets.top > 0 && $0.auxiliaryTopLeftArea != nil
        }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private var cardSize: CGSize {
        CGSize(
            width: CGFloat(model.cardWidth),
            height: PromptMetrics.cardHeight(fontSize: CGFloat(model.fontSize))
        )
    }

    private func targetWindowFrame() -> NSRect {
        guard let screen = screenForPrompter() else {
            return NSRect(x: 0, y: 0, width: 760, height: 260)
        }

        let menuBarInset = max(
            screen.safeAreaInsets.top,
            screen.frame.maxY - screen.visibleFrame.maxY
        )
        let cardTop = screen.frame.maxY - menuBarInset - 7
        let card = cardSize
        let margin = PromptMetrics.windowShadowMargin
        let windowSize = CGSize(
            width: card.width + margin * 2,
            height: card.height + margin * 2
        )

        return NSRect(
            x: screen.frame.midX - windowSize.width / 2,
            y: cardTop - card.height - margin,
            width: windowSize.width,
            height: windowSize.height
        )
    }

    private func applyFrame(animated: Bool) {
        guard panel != nil else { return }
        let finalFrame = targetWindowFrame()

        if animated, isPresented {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(finalFrame, display: true)
            }
        } else {
            panel.setFrame(finalFrame, display: true)
        }
    }

    // MARK: Capture privacy

    private func updateCaptureVisibility() {
        guard panel != nil else { return }
        // SharingType.none is a legacy, best-effort hint. Apple documents that
        // it must not be used to guarantee hiding from capture, and meeting
        // apps may ignore it. The UI copy and docs describe that limit.
        let shouldHide = model.hideFromCapture && !forceVisibleInCapture
        panel.sharingType = shouldHide ? .none : .readOnly
    }

    // MARK: Debug

    private func debugLayoutIfNeeded() {
        guard ProcessInfo.processInfo.environment["NOOK_DEBUG_LAYOUT"] == "1",
              let screen = screenForPrompter() else { return }

        let frame = panel.frame
        let cardTop = screen.frame.maxY - max(
            screen.safeAreaInsets.top,
            screen.frame.maxY - screen.visibleFrame.maxY
        ) - 7
        let notchWidth: CGFloat
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notchWidth = screen.frame.width - left.width - right.width
        } else {
            notchWidth = 0
        }

        print(
            "NOOK_LAYOUT screen=\(screen.localizedName) screenFrame=\(screen.frame) " +
            "menuBarInset=\(screen.safeAreaInsets.top) notchWidth=\(notchWidth) " +
            "cardTop=\(cardTop) windowFrame=\(frame) visible=\(isPresented)"
        )
    }
}
