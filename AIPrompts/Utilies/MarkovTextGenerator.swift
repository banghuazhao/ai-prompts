import Foundation

/// A simple Markov chain text generator for offline prompt creation.
class MarkovTextGenerator {
    private var markovChain: [String: [String]] = [:]
    private var startWords: [String] = []
    private let order: Int

    /// Initialize with a corpus of text and the order of the Markov chain (default: 2).
    init(corpus: [String], order: Int = 2) {
        self.order = order
        buildChain(from: corpus)
    }

    private func buildChain(from corpus: [String]) {
        for text in corpus {
            let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            guard words.count > order else { continue }
            for i in 0..<(words.count - order) {
                let key = words[i..<(i+order)].joined(separator: " ")
                let nextWord = words[i+order]
                markovChain[key, default: []].append(nextWord)
                if i == 0 {
                    startWords.append(key)
                }
            }
        }
    }

    /// Generate a prompt with a maximum number of words.
    func generatePrompt(maxWords: Int = 30) -> String {
        guard !startWords.isEmpty else { return "" }
        let current = startWords.randomElement()!
        var result = current.components(separatedBy: " ")
        while result.count < maxWords {
            let key = result.suffix(order).joined(separator: " ")
            guard let nextWords = markovChain[key], !nextWords.isEmpty else { break }
            let next = nextWords.randomElement()!
            result.append(next)
        }
        return result.joined(separator: " ")
    }
} 
