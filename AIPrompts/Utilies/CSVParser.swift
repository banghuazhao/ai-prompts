import Foundation

/// A small RFC 4180 CSV parser.
///
/// Handles quoted fields, escaped quotes (`""` inside a quoted field becomes `"`),
/// and newlines inside quoted fields.
enum CSVParser {
    static func parse(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var insideQuotes = false

        var iterator = content.makeIterator()
        var pending: Character? = nil

        func next() -> Character? {
            if let char = pending {
                pending = nil
                return char
            }
            return iterator.next()
        }

        func endRow() {
            row.append(field)
            field = ""
            // Skip completely empty lines
            if !(row.count == 1 && row[0].isEmpty) {
                rows.append(row)
            }
            row = []
        }

        while let char = next() {
            if insideQuotes {
                if char == "\"" {
                    if let following = next() {
                        if following == "\"" {
                            field.append("\"")
                        } else {
                            insideQuotes = false
                            pending = following
                        }
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(char)
                }
            } else {
                switch char {
                case "\"":
                    insideQuotes = true
                case ",":
                    row.append(field)
                    field = ""
                case "\n", "\r", "\r\n":
                    endRow()
                default:
                    field.append(char)
                }
            }
        }

        if !field.isEmpty || !row.isEmpty {
            endRow()
        }

        return rows
    }

    /// Parses a bundled CSV resource, dropping the header row.
    static func parseResource(named name: String, bundle: Bundle = .main) -> [[String]] {
        guard let url = bundle.url(forResource: name, withExtension: "csv") else {
            print("Could not find \(name).csv")
            return []
        }
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            return Array(parse(content).dropFirst())
        } catch {
            print("Error loading \(name).csv: \(error)")
            return []
        }
    }
}
