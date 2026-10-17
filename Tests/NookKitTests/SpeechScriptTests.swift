import Foundation

func runSpeechScriptTests() {
    let text = "Hi, I'm Alex. Dr. Chen is here.\n\nThis is hard—but it's worth it."
    let script = ScriptTokenizer.tokenize(text)

    checkEqual(
        script.tokens.map(\.text),
        ["Hi,", "I'm", "Alex.", "Dr.", "Chen", "is", "here.", "This", "is", "hard—", "but", "it's", "worth", "it."],
        "Tokenizer produces stable local word tokens"
    )
    checkEqual(script.sentenceCount, 3, "Honorific and sentence boundaries are preserved")
    checkEqual(script.paragraphCount, 2, "Blank lines produce paragraphs")
    checkEqual(
        script.tokens.map(\.sentenceIndex),
        [0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2],
        "Sentence indexes are sequential"
    )
    check(script.tokens[2].isSentenceEnd, "Alex. ends a sentence")
    check(script.tokens[5].isSentenceEnd == false, "Mid-sentence token is not a sentence end")
    check(script.tokens[6].isParagraphEnd, "here. ends the first paragraph")
    check(script.tokens[13].isParagraphEnd, "it. ends the second paragraph")
    checkEqual(script.tokens[9].text, "hard—", "Em dash is attached to the preceding token")
    checkEqual(script.tokenizerVersion, ScriptTokenizer.version, "Tokenizer version is recorded")

    let empty = ScriptTokenizer.tokenize("  \n\n ")
    check(empty.isEmpty, "Whitespace-only input is empty")
    checkEqual(empty.sentenceCount, 0, "Empty input has no sentences")

    let legacy = PromptScriptBuilder.build(from: text)
    checkEqual(
        script.tokens.map(\.text),
        legacy.words.map(\.text),
        "Migrated tokenizer matches the legacy token stream"
    )
}
