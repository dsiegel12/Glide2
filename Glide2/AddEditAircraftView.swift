import SwiftUI

struct AddEditAircraftView: View {
    @EnvironmentObject var store: AircraftStore
    @Environment(\.dismiss) var dismiss

    let existingAircraft: Aircraft?

    @State private var aircraftID   = ""
    @State private var fullName     = ""
    @State private var mtow         = ""
    @State private var minWeight    = ""
    @State private var glideSpeed   = ""
    @State private var glideSpeedUnit = 0   // 0 = kts, 1 = mph
    @State private var glideRatio   = ""
    @State private var stallSpeed   = ""    // always kts
    @State private var colorHex     = presetAircraftColors[0].hex
    @State private var errorMessage = ""

    var isEditing: Bool { existingAircraft != nil }

    // Conversion display for glide speed entry
    private var glideSpeedConverted: String? {
        guard let v = Double(glideSpeed), v > 0 else { return nil }
        if glideSpeedUnit == 0 {
            return String(format: "%.1f mph", v * 1.15078)
        } else {
            return String(format: "%.1f kts", v / 1.15078)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Identity
                Section("AIRCRAFT IDENTITY") {
                    HStack {
                        Text("Short ID")
                        Spacer()
                        TextField("e.g. PA28", text: $aircraftID)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                    HStack {
                        Text("Full Name")
                        Spacer()
                        TextField("e.g. Piper Cherokee 180", text: $fullName)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                    }
                }

                // MARK: Weight
                Section("WEIGHT (LB)") {
                    HStack {
                        Text("Max Takeoff Weight")
                        Spacer()
                        TextField("e.g. 2400", text: $mtow)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Min Weight")
                        Spacer()
                        TextField("e.g. 1200", text: $minWeight)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }

                // MARK: Performance
                Section("PERFORMANCE") {
                    // Best glide speed with kts/mph toggle
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Best Glide Speed")
                            Spacer()
                            Picker("", selection: $glideSpeedUnit) {
                                Text("KTS").tag(0)
                                Text("MPH").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 96)
                        }
                        TextField(
                            glideSpeedUnit == 0 ? "e.g. 76" : "e.g. 87",
                            text: $glideSpeed
                        )
                        .keyboardType(.decimalPad)
                        if let other = glideSpeedConverted {
                            Text("= \(other)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    // Glide ratio
                    HStack {
                        Text("Glide Ratio (L/D)")
                        Spacer()
                        TextField("e.g. 9.0", text: $glideRatio)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }

                    // Stall speed — always kts input, mph shown below
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Stall Speed — level flight, MTOW")
                        HStack {
                            TextField("e.g. 50", text: $stallSpeed)
                                .keyboardType(.decimalPad)
                            Text("KTS")
                                .foregroundColor(.secondary)
                        }
                        if let v = Double(stallSpeed), v > 0 {
                            Text("= \(String(format: "%.1f", v * 1.15078)) mph")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("Bank-angle stall speeds are calculated automatically.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Color
                Section("ACCENT COLOR") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 4),
                        spacing: 14
                    ) {
                        ForEach(presetAircraftColors, id: \.hex) { preset in
                            Button {
                                colorHex = preset.hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: preset.hex))
                                        .frame(width: 46, height: 46)
                                    if colorHex == preset.hex {
                                        Circle()
                                            .strokeBorder(Color.white, lineWidth: 2.5)
                                            .frame(width: 46, height: 46)
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .font(.system(size: 15, weight: .bold))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // MARK: Error
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 13, design: .monospaced))
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Aircraft" : "Add Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear { prefill() }
        }
        .preferredColorScheme(.dark)
    }

    private func prefill() {
        guard let ac = existingAircraft else { return }
        aircraftID     = ac.id
        fullName       = ac.fullName
        mtow           = String(Int(ac.mtow))
        minWeight      = String(Int(ac.minWeight))
        glideSpeed     = String(Int(ac.refGlideSpeed))
        glideSpeedUnit = 0
        glideRatio     = String(format: "%.1f", ac.glideRatio)
        stallSpeed     = String(format: "%.0f", ac.stallSpeeds[0])
        colorHex       = ac.colorHex
    }

    private func save() {
        errorMessage = ""

        let trimID   = aircraftID.trimmingCharacters(in: .whitespaces)
        let trimName = fullName.trimmingCharacters(in: .whitespaces)

        guard !trimID.isEmpty   else { errorMessage = "Short ID is required.";        return }
        guard !trimName.isEmpty  else { errorMessage = "Full name is required.";       return }
        guard let mtowVal = Double(mtow), mtowVal > 0
                                         else { errorMessage = "Enter a valid MTOW.";         return }
        guard let minWtVal = Double(minWeight), minWtVal > 0, minWtVal < mtowVal
                                         else { errorMessage = "Min weight must be less than MTOW."; return }
        guard let gsVal = Double(glideSpeed), gsVal > 0
                                         else { errorMessage = "Enter a valid glide speed.";  return }
        guard let grVal = Double(glideRatio), grVal > 0
                                         else { errorMessage = "Enter a valid glide ratio.";  return }
        guard let ssVal = Double(stallSpeed), ssVal > 0
                                         else { errorMessage = "Enter a valid stall speed.";  return }

        if !store.idIsAvailable(trimID, excluding: existingAircraft?.id) {
            errorMessage = "ID '\(trimID)' is already in use."
            return
        }

        // Convert glide speed to kts if entered in mph
        let glideKts = glideSpeedUnit == 1 ? gsVal / 1.15078 : gsVal

        let ac = Aircraft.makeUserAircraft(
            id:            trimID,
            fullName:      trimName,
            mtow:          mtowVal,
            minWeight:     minWtVal,
            refGlideSpeed: glideKts,
            glideRatio:    grVal,
            stallSpeedKts: ssVal,
            colorHex:      colorHex
        )

        if isEditing {
            store.update(ac)
        } else {
            store.add(ac)
        }
        dismiss()
    }
}
