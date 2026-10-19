import Foundation

/// Human-readable time formatting shared by the editor and the teleprompter.
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
