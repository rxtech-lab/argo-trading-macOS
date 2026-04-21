//
//  SchemaTranslator.swift
//  ArgoTradingSwift
//
//  Translates the `title` and `description` string values inside a JSON Schema
//  document via the system Translation framework, preserving all other JSON
//  content and key ordering by operating on the raw string.
//

import Foundation
import Translation

enum SchemaTranslator {
    static func collectTranslatableStrings(in jsonString: String) -> [String] {
        let ns = jsonString as NSString
        let matches = regex.matches(in: jsonString, range: NSRange(location: 0, length: ns.length))
        var seen = Set<String>()
        var ordered: [String] = []
        for match in matches where match.numberOfRanges >= 2 {
            let literalRange = match.range(at: 1)
            guard literalRange.location != NSNotFound else { continue }
            let literalContent = ns.substring(with: literalRange)
            guard let decoded = decodeJSONStringContent(literalContent), !decoded.isEmpty else { continue }
            if seen.insert(decoded).inserted {
                ordered.append(decoded)
            }
        }
        return ordered
    }

    static func applyTranslations(to jsonString: String, translations: [String: String]) -> String {
        let ns = jsonString as NSString
        let matches = regex.matches(in: jsonString, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return jsonString }
        let result = NSMutableString(string: jsonString)
        for match in matches.reversed() where match.numberOfRanges >= 2 {
            let literalRange = match.range(at: 1)
            guard literalRange.location != NSNotFound else { continue }
            let literalContent = result.substring(with: literalRange)
            guard let decoded = decodeJSONStringContent(literalContent),
                  let translated = translations[decoded],
                  translated != decoded,
                  let reEncoded = encodeJSONStringContent("\(decoded)\n\(translated)")
            else { continue }
            result.replaceCharacters(in: literalRange, with: reEncoded)
        }
        return result as String
    }

    static func translate(jsonString: String, session: TranslationSession) async -> String {
        let strings = collectTranslatableStrings(in: jsonString)
        guard !strings.isEmpty else { return jsonString }
        let requests = strings.enumerated().map { index, text in
            TranslationSession.Request(sourceText: text, clientIdentifier: "\(index)")
        }
        do {
            let responses = try await session.translations(from: requests)
            var map: [String: String] = [:]
            for response in responses {
                guard let id = response.clientIdentifier,
                      let index = Int(id),
                      index < strings.count
                else { continue }
                map[strings[index]] = response.targetText
            }
            return applyTranslations(to: jsonString, translations: map)
        } catch {
            return jsonString
        }
    }

    private static let regex: NSRegularExpression = {
        let pattern = #""(?:title|description)"\s*:\s*"((?:[^"\\]|\\.)*)""#
        return try! NSRegularExpression(pattern: pattern)
    }()

    private static func decodeJSONStringContent(_ literalContent: String) -> String? {
        let wrapped = "\"\(literalContent)\""
        guard let data = wrapped.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(String.self, from: data)
        else { return nil }
        return decoded
    }

    private static func encodeJSONStringContent(_ value: String) -> String? {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8),
              encoded.count >= 2,
              encoded.first == "\"",
              encoded.last == "\""
        else { return nil }
        return String(encoded.dropFirst().dropLast())
    }
}
