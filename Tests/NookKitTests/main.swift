import AppKit
import Foundation

// A lightweight, dependency-free test runner so this project can be verified
// with only the macOS Command Line Tools installed.

print("Nook prompt-engine tests")
print("-----------------------")

// Empty input.
do {
    let doc = PromptScriptBuilder.build(from: "   \n\n  ")
    check(doc.isEmpty, "Whitespace-only input produces an empty document")
    checkEqual(doc.totalDuration, 0, "Empty document has zero duration")
}

// Sentence splitting + honorifics.
do {
    let text = "Dr. Chen is my mentor. I worked at Acme Inc. for two years. I moved to the U.S. in 2022."
    let doc = PromptScriptBuilder.build(from: text)
    checkEqual(doc.sentenceCount, 3, "Honorific does not create a false sentence")
    checkEqual(sentences(in: doc).first, "Dr. Chen is my mentor.", "Merged honorific sentence is complete")
}

// Initial sequences.
do {
    let doc = PromptScriptBuilder.build(from: "J. K. Rowling is my favorite author. I've read every book.")
    checkEqual(doc.sentenceCount, 2, "Initial sequence stays with the name")
}

// A company suffix at a real sentence boundary should not over-merge.
do {
    let doc = PromptScriptBuilder.build(from: "I worked at Acme Inc. I loved it.")
    checkEqual(doc.sentenceCount, 2, "Company suffix at a sentence boundary does not merge")
}

// Em dashes become natural spoken beats.
do {
    let doc = PromptScriptBuilder.build(from: "This is hard—but it's worth it.")
    let words = doc.words.map(\.text)
    check(words.contains("hard—"), "Unspaced em dash is attached to the preceding word")
    check(words.contains("but"), "Word after an em dash stays intact")
    if let hardIndex = doc.words.firstIndex(where: { $0.text == "hard—" }),
       hardIndex + 1 < doc.words.count {
        let gap = doc.words[hardIndex + 1].start - doc.words[hardIndex].end
        check(gap >= 0.24, "Em dash creates a pause (gap: \(String(format: "%.2f", gap))s)")
    } else {
        check(false, "Em dash word exists")
    }
}

// Comma rhythm.
do {
    let comma = PromptScriptBuilder.build(from: "We build tools, and we ship them.")
    let flat = PromptScriptBuilder.build(from: "We build tools and we ship them.")
    check(comma.totalDuration > flat.totalDuration + 0.1, "Comma adds breathing room")
}

// Sentence pause is longer than a comma pause.
do {
    let comma = PromptScriptBuilder.build(from: "Wait, now.")
    let stop = PromptScriptBuilder.build(from: "Wait. Now.")
    checkEqual(stop.sentenceCount, 2, "Period produces two sentences")
    check(stop.totalDuration > comma.totalDuration + 0.15, "Sentence pause is longer than comma pause")
}

// Pacing scales as expected.
do {
    let slow = PromptScriptBuilder.build(from: SampleScript.interviewIntro, options: PromptBuildOptions(wordsPerMinute: 110))
    let fast = PromptScriptBuilder.build(from: SampleScript.interviewIntro, options: PromptBuildOptions(wordsPerMinute: 170))
    check(slow.totalDuration > fast.totalDuration * 1.3, "Lower WPM meaningfully lengthens the read")
    check(fast.wordsPerMinute == 170, "WPM is recorded on the document")
}

// Line layout, width, indices, and continuity.
do {
    let options = PromptBuildOptions(wordsPerMinute: 138, fontSize: 30, cardWidth: 680)
    let doc = PromptScriptBuilder.build(from: SampleScript.interviewIntro, options: options)
    let maxWidth = PromptMetrics.availableTextWidth(cardWidth: 680)

    check(doc.totalWords > 100, "Sample script contains a useful number of words")
    checkEqual(doc.paragraphCount, 4, "Sample script has four paragraphs")
    check(doc.lines.count > doc.sentenceCount, "Long sentences are broken into multiple lines")
    check(doc.lines.allSatisfy { !$0.wordRange.isEmpty }, "No empty line ranges")

    for line in doc.lines {
        let width = measuredLineWidth(line, document: doc, fontSize: options.fontSize)
        if line.wordCount > 1 {
            check(width <= maxWidth + 2.0, "Line \(line.id) fits the reading column (width \(Int(width)) / \(Int(maxWidth)))")
        }
        let first = line.firstWordIndex
        let last = line.lastWordIndex
        check(first >= 0 && last < doc.words.count, "Line \(line.id) points at valid words")
        check(doc.words[first].lineIndex == line.id, "First word knows its line")
        check(doc.words[last].lineIndex == line.id, "Last word knows its line")
        checkEqual(doc.lines[line.id].sentenceIndex, doc.words[first].sentenceIndex, "Line \(line.id) belongs to one sentence")
        if line.startsSentence {
            check(first == 0 || doc.words[first - 1].sentenceIndex != line.sentenceIndex, "startsSentence only at a sentence boundary")
        }
    }

    for index in 1..<doc.words.count {
        check(doc.words[index].start >= doc.words[index - 1].end, "Word \(index) starts after the previous word")
        check(doc.words[index].start.isFinite, "Word \(index) start is finite")
    }

    check(doc.words.first!.start >= 0.99, "First word respects the lead-in")
    check(doc.totalDuration > doc.words.last!.end, "There is a small hold after the final word")
    check(doc.wordIndex(at: 0) == nil, "No word is active before the lead-in")
    checkEqual(doc.wordIndex(at: doc.words.first!.start + 0.01), 0, "First word activates at its start")

    // During a punctuation pause the previous word stays highlighted.
    if let commaWord = doc.words.first(where: { $0.text.hasSuffix(",") }),
       commaWord.id + 1 < doc.words.count {
        let probe = commaWord.end + 0.05
        check(doc.words[commaWord.id + 1].start > probe, "Comma pause shifts the next word")
        checkEqual(doc.wordIndex(at: probe), commaWord.id, "Comma pause keeps the eye anchored")
    }
    checkEqual(doc.progress(at: doc.totalDuration), 1.0, "Progress reaches one")
    checkEqual(doc.progress(at: -5), 0.0, "Progress never goes negative")
}

// Narrow card forces shorter phrases without crossing a sentence boundary.
do {
    let options = PromptBuildOptions(wordsPerMinute: 138, fontSize: 34, cardWidth: 600)
    let doc = PromptScriptBuilder.build(from: SampleScript.interviewIntro, options: options)
    let maxWidth = PromptMetrics.availableTextWidth(cardWidth: 600)
    check(doc.lines.count > 8, "Narrow/fat type produces more phrase lines")
    for line in doc.lines where line.wordCount > 1 {
        let width = measuredLineWidth(line, document: doc, fontSize: options.fontSize)
        check(width <= maxWidth + 2.0, "Narrow line \(line.id) still fits (\(Int(width)) / \(Int(maxWidth)))")
    }
}

// Round-trip of simple plain text.
do {
    let text = "Today is a good day to begin. I am ready."
    let doc = PromptScriptBuilder.build(from: text)
    checkEqual(doc.words.map(\.text).joined(separator: " "), text, "Simple text round-trips through the tokenizer")
}

// Debug printout for human inspection.
do {
    let options = PromptBuildOptions(wordsPerMinute: 138, fontSize: 30, cardWidth: 680)
    let doc = PromptScriptBuilder.build(from: SampleScript.interviewIntro, options: options)
    print("")
    print("Sample analysis")
    print("  words:      \(doc.totalWords)")
    print("  sentences:  \(doc.sentenceCount)")
    print("  paragraphs: \(doc.paragraphCount)")
    print("  lines:      \(doc.lineCount)")
    print("  duration:   \(String(format: "%.1f", doc.totalDuration))s at \(Int(doc.wordsPerMinute)) WPM")
    for line in doc.lines.prefix(5) {
        print("  · \(line.text)")
    }
}

print("")
runSpeechScriptTests()
runPhrasePlanTests()
runPromptComposerTests()
runPromptPipelineSmokeTest()
runPausePolicyTests()
runLLMConfigurationTests()
runPhrasePlanningPromptTests()
runOpenAICompatibleClientTests()
runPhrasePlanCacheTests()
runAIPlanningCoordinatorTests()
runPreferencesStoreTests()
runScriptDocumentBuilderTests()

if failures.isEmpty {
    print("PASS — \(testCount) checks")
    exit(0)
} else {
    print("FAIL — \(failures.count) of \(testCount) checks failed")
    exit(1)
}
