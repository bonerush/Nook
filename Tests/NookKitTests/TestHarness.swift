import AppKit
import Foundation

var testCount = 0
var failures: [String] = []

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    testCount += 1
    if !condition() {
        failures.append(message)
        print("  FAIL  \(message)")
    }
}

func checkEqual<T: Equatable>(_ lhs: T, _ rhs: T, _ message: String) {
    testCount += 1
    if lhs != rhs {
        failures.append("\(message) (got \(lhs), expected \(rhs))")
        print("  FAIL  \(message) (got \(lhs), expected \(rhs))")
    }
}

func sentences(in document: PromptDocument) -> [String] {
    Dictionary(grouping: document.words, by: \.sentenceIndex)
        .keys
        .sorted()
        .map { key in
            document.words
                .filter { $0.sentenceIndex == key }
                .map(\.text)
                .joined(separator: " ")
        }
}

func measuredLineWidth(_ line: PromptLine, document: PromptDocument, fontSize: CGFloat) -> CGFloat {
    let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)
    let words = line.wordRange.map { document.words[$0].text }
    let spacing = PromptMetrics.wordSpacing(fontSize: fontSize)
    let textWidth = words.reduce(CGFloat.zero) { partial, word in
        partial + ceil((word as NSString).size(withAttributes: [.font: font]).width)
    }
    return textWidth + spacing * CGFloat(max(0, words.count - 1))
}
