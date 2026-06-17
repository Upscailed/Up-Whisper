import Foundation

struct CommandProcessor {
    // Longest patterns first to avoid partial matches (e.g. "nieuwe paragraaf" before "nieuwe regel")
    private static let commands: [(pattern: String, replacement: String)] = [
        ("aanhalingstekens open", "\u{201C}"),
        ("aanhalingstekens sluit", "\u{201D}"),
        ("nieuwe paragraaf", "\n\n"),
        ("nieuwe alinea", "\n\n"),
        ("nieuwe regel", "\n"),
        ("dubbele punt", ":"),
        ("open haakje", "("),
        ("sluit haakje", ")"),
        ("groter dan", ">"),
        ("kleiner dan", "<"),
        ("schuine streep", "/"),
        ("uitroepteken", "!"),
        ("vraagteken", "?"),
        ("puntkomma", ";"),
        ("apenstaartje", "@"),
        ("procentteken", "%"),
        ("euroteken", "€"),
        ("ampersand", "&"),
        ("underscore", "_"),
        ("gelijkteken", "="),
        ("streepje", "-"),
        ("hekje", "#"),
        ("ster", "*"),
        ("komma", ","),
        ("punt", "."),
    ]

    static func apply(to text: String) -> String {
        var result = text
        for (pattern, replacement) in commands {
            let escaped = NSRegularExpression.escapedPattern(for: pattern)
            result = result.replacingOccurrences(
                of: "(?i)\\b\(escaped)\\b",
                with: replacement,
                options: .regularExpression
            )
        }
        return result
    }
}
