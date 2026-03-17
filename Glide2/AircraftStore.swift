import SwiftUI
import Foundation

class AircraftStore: ObservableObject {
    @Published private(set) var aircraft: [Aircraft] = []

    private let saveURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        saveURL = docs.appendingPathComponent("user_aircraft.json")
        reload()
    }

    private func reload() {
        var userAircraft: [Aircraft] = []
        if let data = try? Data(contentsOf: saveURL),
           let decoded = try? JSONDecoder().decode([Aircraft].self, from: data) {
            userAircraft = decoded
        }
        aircraft = builtInAircraft + userAircraft
    }

    func add(_ ac: Aircraft) {
        aircraft.append(ac)
        persist()
    }

    func update(_ ac: Aircraft) {
        guard let i = aircraft.firstIndex(where: { $0.id == ac.id }) else { return }
        aircraft[i] = ac
        persist()
    }

    func delete(_ ac: Aircraft) {
        aircraft.removeAll { $0.id == ac.id }
        persist()
    }

    // Returns true if the ID is not already in use (optionally excluding one ID for edits)
    func idIsAvailable(_ id: String, excluding: String? = nil) -> Bool {
        aircraft.allSatisfy { $0.id != id || $0.id == excluding }
    }

    private func persist() {
        let userOnly = aircraft.filter { $0.isUserDefined }
        if let data = try? JSONEncoder().encode(userOnly) {
            try? data.write(to: saveURL)
        }
    }
}
