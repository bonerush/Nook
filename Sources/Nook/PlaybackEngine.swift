import Foundation

final class PlaybackEngine: NSObject, ObservableObject {
    enum Phase: String {
        case empty = "EMPTY"
        case ready = "READY"
        case playing = "PLAYING"
        case paused = "PAUSED"
        case finished = "DONE"

        var label: String { rawValue }
    }

    @Published private(set) var document: PromptDocument
    @Published private(set) var isPlaying = false
    @Published private(set) var isFinished = false
    @Published private(set) var hasStarted = false
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var currentWordIndex: Int?
    @Published private(set) var currentLineIndex = 0

    private var timer: Timer?
    private var anchorElapsed: TimeInterval = 0
    private var anchorUptime: TimeInterval = 0

    init(document: PromptDocument = .empty) {
        self.document = document
        super.init()
        refreshDerived()
    }

    deinit {
        timer?.invalidate()
    }

    // MARK: Computed state

    var phase: Phase {
        if document.isEmpty { return .empty }
        if isFinished { return .finished }
        if isPlaying {
            // The document includes a short lead-in before the first word.
            // Expose that window as READY rather than making the reader feel
            // they have already fallen behind.
            if currentWordIndex == nil, elapsed < document.leadIn {
                return .ready
            }
            return .playing
        }
        if hasStarted { return .paused }
        return .ready
    }

    var progress: Double {
        document.progress(at: elapsed)
    }

    var remaining: TimeInterval {
        max(0, document.totalDuration - elapsed)
    }

    var elapsedLabel: String {
        NookTime.clock(elapsed)
    }

    var remainingLabel: String {
        NookTime.remaining(remaining)
    }

    var totalLabel: String {
        NookTime.total(document.totalDuration)
    }

    // MARK: Document loading

    /// Replaces the script while keeping the reader in the same word, if the
    /// word sequence has not changed. This lets live WPM and type-size changes
    /// update the prompter without losing the reader's place.
    func load(_ newDocument: PromptDocument, preservePosition: Bool = true) {
        let captured = currentElapsed()
        let oldDocument = document
        let oldIndex = oldDocument.wordIndex(at: captured)
        let oldFraction: Double

        if let oldIndex, oldIndex < oldDocument.words.count,
           oldDocument.words[oldIndex].duration > 0 {
            oldFraction = min(
                1,
                max(0, (captured - oldDocument.words[oldIndex].start)
                    / oldDocument.words[oldIndex].duration)
            )
        } else {
            oldFraction = 0
        }

        let canPreserve = preservePosition
            && oldIndex != nil
            && !newDocument.isEmpty
            && oldDocument.words.map(\.text) == newDocument.words.map(\.text)
            && (oldIndex ?? 0) < newDocument.words.count

        let wasPlaying = isPlaying
        let wasStarted = hasStarted
        let wasFinished = isFinished

        stopTimer()
        isPlaying = false
        document = newDocument

        if canPreserve, let oldIndex {
            if wasFinished {
                elapsed = newDocument.totalDuration
                hasStarted = true
                isFinished = true
            } else {
                let word = newDocument.words[oldIndex]
                elapsed = min(
                    newDocument.totalDuration,
                    word.start + oldFraction * max(0, word.duration)
                )
                hasStarted = wasStarted
                isFinished = false
            }
        } else {
            elapsed = 0
            hasStarted = false
            isFinished = false
        }

        refreshDerived()
        if wasPlaying, canPreserve, !newDocument.isEmpty {
            play()
        }
    }

    func resetPosition() {
        stopTimer()
        isPlaying = false
        elapsed = 0
        hasStarted = false
        isFinished = false
        currentWordIndex = nil
        currentLineIndex = 0
        refreshDerived()
    }

    // MARK: Transport

    func play() {
        guard !document.isEmpty else { return }

        if isFinished || elapsed >= document.totalDuration - 0.001 {
            resetPosition()
        }

        hasStarted = true
        isFinished = false
        isPlaying = true
        anchorElapsed = elapsed
        anchorUptime = ProcessInfo.processInfo.systemUptime
        startTimer()
        refreshDerived()
    }

    func pause() {
        guard isPlaying else { return }
        elapsed = currentElapsed()
        stopTimer()
        isPlaying = false
        hasStarted = true
        refreshDerived()
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func restart(autoPlay: Bool) {
        resetPosition()
        if autoPlay {
            play()
        }
    }

    func nextLine() {
        seek(toLineOffset: 1)
    }

    func previousLine() {
        seek(toLineOffset: -1)
    }

    func seek(toLineOffset offset: Int) {
        guard !document.lines.isEmpty else { return }
        let target = min(document.lines.count - 1, max(0, currentLineIndex + offset))
        let wasPlaying = isPlaying

        stopTimer()
        isPlaying = false
        elapsed = document.lines[target].startTime
        hasStarted = true
        isFinished = false
        refreshDerived()

        if wasPlaying {
            play()
        }
    }

    /// A convenience used when the panel is opened and should immediately
    /// begin at the top, with the built-in one-second lead-in.
    func restartFromBeginning(autoPlay: Bool) {
        restart(autoPlay: autoPlay)
    }

    // MARK: Clock

    private func startTimer() {
        stopTimer()
        let timer = Timer(
            timeInterval: 1.0 / 30.0,
            target: self,
            selector: #selector(handleTimer),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 0.012
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func handleTimer() {
        guard isPlaying, !document.isEmpty else { return }

        let next = currentElapsed()
        if next >= document.totalDuration {
            finish()
            return
        }

        updateDerived(at: next)
        elapsed = next
    }

    private func finish() {
        stopTimer()
        isPlaying = false
        isFinished = true
        hasStarted = true
        elapsed = document.totalDuration
        currentWordIndex = document.words.last?.id
        currentLineIndex = document.lines.last?.id ?? 0
    }

    private func currentElapsed() -> TimeInterval {
        guard isPlaying else { return elapsed }
        let now = ProcessInfo.processInfo.systemUptime
        return min(document.totalDuration, anchorElapsed + (now - anchorUptime))
    }

    private func updateDerived(at time: TimeInterval) {
        let wordIndex = document.wordIndex(at: time)
        let lineIndex = wordIndex.map { document.words[$0].lineIndex } ?? 0
        if wordIndex != currentWordIndex {
            currentWordIndex = wordIndex
        }
        if lineIndex != currentLineIndex {
            currentLineIndex = lineIndex
        }
    }

    private func refreshDerived() {
        currentWordIndex = document.wordIndex(at: elapsed)
        currentLineIndex = currentWordIndex.map { document.words[$0].lineIndex } ?? 0
        if !document.isEmpty, elapsed >= document.totalDuration - 0.001 {
            isFinished = true
            hasStarted = true
        }
    }
}
