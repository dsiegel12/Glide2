import SwiftUI

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            red:   Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8)  & 0xFF) / 255,
            blue:  Double(int         & 0xFF) / 255
        )
    }
}

// MARK: - Aircraft Data

struct Aircraft: Identifiable, Hashable, Codable {
    let id: String
    let fullName: String
    let mtow: Double
    let minWeight: Double
    let refWeight: Double
    let refGlideSpeed: Double   // KIAS
    let glideRatio: Double
    let colorHex: String
    var isUserDefined: Bool

    // Stall speeds at [0°, 20°, 40°, 60°] bank, in kts, at refWeight (MTOW)
    let stallSpeeds: [Double]

    var accentColor: Color { Color(hex: colorHex) }

    func bestGlide(weight: Double) -> Double {
        refGlideSpeed * sqrt(weight / refWeight)
    }

    func bestGlideMph(weight: Double) -> Double {
        bestGlide(weight: weight) * 1.15078
    }

    func glideDistance(weight: Double, altFt: Double) -> Double {
        altFt * glideRatio / 6076.12
    }

    // Stall speed at arbitrary bank angle, scaled for weight.
    // stallSpeeds are at MTOW (refWeight); weight scaling adjusts for actual gross weight.
    func stallSpeed(bankDeg: Double, weight: Double) -> (kts: Double, mph: Double) {
        let knownBanks: [Double] = [0, 20, 40, 60]
        let bank = max(0, min(80, bankDeg))

        let speedKts: Double
        if bank <= 60 {
            if let upper = knownBanks.firstIndex(where: { $0 >= bank }) {
                if upper == 0 {
                    speedKts = stallSpeeds[0]
                } else {
                    let lower = upper - 1
                    let frac = (bank - knownBanks[lower]) / (knownBanks[upper] - knownBanks[lower])
                    speedKts = stallSpeeds[lower] + frac * (stallSpeeds[upper] - stallSpeeds[lower])
                }
            } else {
                speedKts = stallSpeeds.last ?? 0
            }
        } else {
            // Beyond 60°: scale from 60° using load factor
            let vs60  = stallSpeeds.last ?? 0
            let lf    = 1.0 / cos(bank  * .pi / 180)
            let lf60  = 1.0 / cos(60.0  * .pi / 180)
            speedKts = vs60 * sqrt(lf / lf60)
        }

        let weightScale = sqrt(weight / mtow)
        let scaledKts   = speedKts * weightScale
        return (kts: scaledKts, mph: scaledKts * 1.15078)
    }

    // Factory for user-defined aircraft.
    // stallSpeedKts: level-flight stall speed at MTOW in kts.
    // The app computes bank-angle variations using the load factor formula.
    static func makeUserAircraft(
        id: String,
        fullName: String,
        mtow: Double,
        minWeight: Double,
        refGlideSpeed: Double,
        glideRatio: Double,
        stallSpeedKts: Double,
        colorHex: String
    ) -> Aircraft {
        let banks: [Double] = [0, 20, 40, 60]
        let speeds = banks.map { bank in
            stallSpeedKts * sqrt(1.0 / cos(bank * .pi / 180))
        }
        return Aircraft(
            id: id,
            fullName: fullName,
            mtow: mtow,
            minWeight: minWeight,
            refWeight: mtow,
            refGlideSpeed: refGlideSpeed,
            glideRatio: glideRatio,
            colorHex: colorHex,
            isUserDefined: true,
            stallSpeeds: speeds
        )
    }
}

// MARK: - Built-in Aircraft
// Stall speeds converted to kts where originals were in mph.

let builtInAircraft: [Aircraft] = [
    Aircraft(
        id: "C182T",
        fullName: "Cessna 182T Skylane",
        mtow: 3100, minWeight: 1500,
        refWeight: 3100, refGlideSpeed: 76, glideRatio: 9.0,
        colorHex: "#E8B84A",
        isUserDefined: false,
        stallSpeeds: [50, 53, 59, 76]      // kts, from POH
    ),
    Aircraft(
        id: "C175A",
        fullName: "Cessna 175A Skylark",
        mtow: 2350, minWeight: 1000,
        refWeight: 2350, refGlideSpeed: 73, glideRatio: 8.5,
        colorHex: "#5C9CD6",
        isUserDefined: false,
        stallSpeeds: [52.1, 53.9, 60.0, 73.9]  // converted from POH mph values
    ),
]

// MARK: - Preset Colors for User Aircraft

let presetAircraftColors: [(name: String, hex: String)] = [
    ("Gold",   "#E8B84A"),
    ("Blue",   "#5C9CD6"),
    ("Green",  "#6BBF7A"),
    ("Red",    "#E06B6B"),
    ("Purple", "#A87DC8"),
    ("Orange", "#E8914A"),
    ("Cyan",   "#4ABFE8"),
    ("Pink",   "#E84A9C"),
]
