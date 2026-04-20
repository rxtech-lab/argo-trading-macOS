import Foundation

extension FormatStyle where Self == Date.FormatStyle {
    /// Format style that preserves the source wall clock (no timezone conversion).
    /// DuckDB parses timestamps as UTC strings, so formatting in UTC echoes the source.
    static var fullDateTimeSource: Date.FormatStyle {
        Date.FormatStyle(
            date: .abbreviated,
            time: .standard,
            timeZone: TimeZone(identifier: "UTC")!
        )
    }

    static var abbreviatedStandardSource: Date.FormatStyle {
        Date.FormatStyle(
            date: .abbreviated,
            time: .standard,
            timeZone: TimeZone(identifier: "UTC")!
        )
    }
}

extension Date {
    /// Format date in UTC timezone for display in tables.
    /// Uses DateFormatter which reliably respects timezone setting.
    func formattedUTC() -> String {
        Self.utcDisplayFormatter.string(from: self)
    }

    private static let utcDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
