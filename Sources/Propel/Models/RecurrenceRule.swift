import Foundation

struct RecurrenceRule: Codable, Equatable, Sendable {
    var interval: Int
    var frequency: Frequency

    /// Clamped interval to prevent overflow in calendar calculations.
    private var safeInterval: Int {
        min(max(interval, 1), 999)
    }

    /// Calculate the next due date by adding the recurrence interval to the previous due date.
    func nextDueDate(from previousDueDate: Date) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: safeInterval, to: previousDueDate) ?? previousDueDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: safeInterval, to: previousDueDate) ?? previousDueDate
        case .monthly:
            return calendar.date(byAdding: .month, value: safeInterval, to: previousDueDate) ?? previousDueDate
        case .custom:
            return calendar.date(byAdding: .day, value: safeInterval, to: previousDueDate) ?? previousDueDate
        }
    }
}
