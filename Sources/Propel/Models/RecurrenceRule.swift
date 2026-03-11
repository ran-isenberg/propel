import Foundation

struct RecurrenceRule: Codable, Equatable, Sendable {
    var interval: Int
    var frequency: Frequency

    /// Calculate the next due date by adding the recurrence interval to the previous due date.
    func nextDueDate(from previousDueDate: Date) -> Date {
        let calendar = Calendar.current
        switch frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: previousDueDate) ?? previousDueDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: previousDueDate) ?? previousDueDate
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: previousDueDate) ?? previousDueDate
        case .custom:
            // Custom uses days as the unit
            return calendar.date(byAdding: .day, value: interval, to: previousDueDate) ?? previousDueDate
        }
    }
}
