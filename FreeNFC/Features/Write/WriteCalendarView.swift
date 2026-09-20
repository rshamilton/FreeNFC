import CoreNFC
import SwiftUI

struct WriteCalendarView: View {
    @State private var title = ""
    @State private var location = ""
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(3600)

    var body: some View {
        Form {
            Section {
                TextField("Event Title", text: $title)
                TextField("Location (optional)", text: $location)
                DatePicker("Starts", selection: $start)
                DatePicker("Ends", selection: $end)
            } footer: {
                Text("Writes a calendar event. Most phones offer to add it when the tag is scanned.")
            }

            Section {
                AddRecordButton(
                    title: "Calendar Event",
                    icon: "calendar.badge.plus",
                    color: .pink,
                    subtitle: title.isEmpty ? "Empty" : title,
                    buildPayload: buildPayload
                )
            }
        }
        .navigationTitle("Write Calendar Event")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { throw ValidationError.empty("Event Title") }
        guard end > start else { throw NFCError.custom("End time must be after the start time.") }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        formatter.timeZone = .current

        var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "BEGIN:VEVENT"]
        lines.append("SUMMARY:\(icalEscape(trimmedTitle))")
        lines.append("DTSTART:\(formatter.string(from: start))")
        lines.append("DTEND:\(formatter.string(from: end))")
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLocation.isEmpty {
            lines.append("LOCATION:\(icalEscape(trimmedLocation))")
        }
        lines.append("END:VEVENT")
        lines.append("END:VCALENDAR")

        let ics = lines.joined(separator: "\r\n")
        return NDEFWriter.mime(type: "text/calendar", data: Data(ics.utf8))
    }

    private func icalEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
    }
}
