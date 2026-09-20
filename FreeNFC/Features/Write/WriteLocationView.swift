import CoreNFC
import SwiftUI

struct WriteLocationView: View {
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var label = ""

    var body: some View {
        Form {
            Section {
                TextField("Latitude (e.g. 37.3349)", text: $latitude)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Longitude (e.g. -122.0090)", text: $longitude)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Label (optional)", text: $label)
            } footer: {
                Text("Writes a Maps link that opens directly to this location.")
            }

            Section {
                AddRecordButton(
                    title: "Location",
                    icon: "mappin.circle.fill",
                    color: .red,
                    subtitle: label.isEmpty ? (latitude.isEmpty ? "Empty" : "\(latitude), \(longitude)") : label,
                    buildPayload: buildPayload
                )
            }
        }
        .navigationTitle("Write Location")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func buildPayload() throws -> NFCNDEFPayload {
        guard let lat = Double(latitude), (-90...90).contains(lat) else {
            throw NFCError.custom("Enter a valid latitude between -90 and 90.")
        }
        guard let lon = Double(longitude), (-180...180).contains(lon) else {
            throw NFCError.custom("Enter a valid longitude between -180 and 180.")
        }

        var urlString = "https://maps.apple.com/?ll=\(lat),\(lon)"
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedLabel.isEmpty {
            let encoded = trimmedLabel.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmedLabel
            urlString += "&q=\(encoded)"
        }

        guard let payload = NDEFWriter.uri(urlString) else {
            throw NFCError.custom("Couldn't build that location record.")
        }
        return payload
    }
}
