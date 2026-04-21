//
//  LocaleHelper.swift
//  LightweightChart
//
//  Shared helper for resolving the user's preferred language. Used by the
//  main app and the chart tooltip so that both feed the same target language
//  into the system Translation framework.
//

import Foundation

public enum LocaleHelper {
    /// The user's preferred language, resolved in the same order the system
    /// resolves UI strings: current app localization → user preferred list →
    /// current locale identifier.
    public static func preferredTargetLanguage() -> Locale.Language {
        let identifier = Bundle.main.preferredLocalizations.first
            ?? Locale.preferredLanguages.first
            ?? Locale.current.identifier
        return Locale.Language(identifier: identifier)
    }
}
