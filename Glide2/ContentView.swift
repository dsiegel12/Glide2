import SwiftUI

// MARK: - ContentView

private extension Double {
    func rounded(to places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

struct ContentView: View {
    let aircraft: Aircraft
    let onChangeAircraft: () -> Void

    @State private var weight            = 2500.0
    @State private var altFt             = 3000.0
    @State private var bankDeg           = 0.0
    @State private var reactionTimeSec   = 3.0
    @State private var runwayLengthFt    = 3000.0
    @State private var windKts           = 0.0
    @State private var thresholdCrossingHt = 25.0
    @State private var engineFailureAlt  = 1500.0
    @State private var airportElevFt     = 0.0
    @State private var pilotCorrectionPct = 0.0
    @State private var groundRollFt      = 800.0
    @State private var climbRateFpm      = 700.0
    @State private var climbSpeedKts     = 73.0
    @State private var climbSpeedUnit    = 0
    @State private var displayed         = 76.0
    @State private var oatC              = 15.0   // Outside air temp in °C
    @State private var tempUnit          = 0       // 0 = °C, 1 = °F
    @State private var pressureAltSource = 0       // 0=field elev, 1=manual PA, 2=elev+baro
    @State private var altimeterSetting  = 29.92   // inHg
    @State private var manualPressureAlt = 0.0     // ft, used when source=1
    @State private var selectedTab       = 0       // active tab index

    @Environment(\.horizontalSizeClass) private var sizeClass

    // MARK: - Persistence
    private struct SavedSettings: Codable {
        var weight = 2500.0; var altFt = 3000.0; var bankDeg = 0.0
        var reactionTimeSec = 3.0; var runwayLengthFt = 3000.0; var windKts = 0.0
        var thresholdCrossingHt = 25.0; var engineFailureAlt = 1500.0
        var airportElevFt = 0.0; var pilotCorrectionPct = 0.0
        var groundRollFt = 800.0; var climbRateFpm = 700.0
        var climbSpeedKts = 73.0; var climbSpeedUnit = 0
        var oatC: Double? = nil; var tempUnit: Int? = nil
        var pressureAltSource: Int? = nil
        var altimeterSetting: Double? = nil
        var manualPressureAlt: Double? = nil
    }
    func loadSettings() {
        guard let data = UserDefaults.standard.data(forKey: "flightSettings_\(ac.id)"),
              let s = try? JSONDecoder().decode(SavedSettings.self, from: data) else { return }
        weight = s.weight; altFt = s.altFt; bankDeg = s.bankDeg
        reactionTimeSec = s.reactionTimeSec; runwayLengthFt = s.runwayLengthFt
        windKts = s.windKts; thresholdCrossingHt = s.thresholdCrossingHt
        engineFailureAlt = s.engineFailureAlt; airportElevFt = s.airportElevFt
        pilotCorrectionPct = s.pilotCorrectionPct; groundRollFt = s.groundRollFt
        climbRateFpm = s.climbRateFpm; climbSpeedKts = s.climbSpeedKts
        climbSpeedUnit = s.climbSpeedUnit
        oatC = s.oatC ?? 15.0; tempUnit = s.tempUnit ?? 0
        pressureAltSource = s.pressureAltSource ?? 0
        altimeterSetting  = s.altimeterSetting  ?? 29.92
        manualPressureAlt = s.manualPressureAlt ?? 0.0
    }
    func saveSettings() {
        let s = SavedSettings(weight: weight, altFt: altFt, bankDeg: bankDeg,
            reactionTimeSec: reactionTimeSec, runwayLengthFt: runwayLengthFt,
            windKts: windKts, thresholdCrossingHt: thresholdCrossingHt,
            engineFailureAlt: engineFailureAlt, airportElevFt: airportElevFt,
            pilotCorrectionPct: pilotCorrectionPct, groundRollFt: groundRollFt,
            climbRateFpm: climbRateFpm, climbSpeedKts: climbSpeedKts,
            climbSpeedUnit: climbSpeedUnit, oatC: oatC, tempUnit: tempUnit,
            pressureAltSource: pressureAltSource, altimeterSetting: altimeterSetting,
            manualPressureAlt: manualPressureAlt)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: "flightSettings_\(ac.id)")
        }
    }

    var ac: Aircraft { aircraft }
    var glide: Double { ac.bestGlide(weight: weight) }
    var glideMph: Double { ac.bestGlideMph(weight: weight) }
    var distNM: Double { ac.glideDistance(weight: weight, altFt: altFt) }
    var stall: (kts: Double, mph: Double) { ac.stallSpeed(bankDeg: bankDeg, weight: weight) }

    // ── Impossible Turn / Minimum Return Altitude ────────────────────────────

    var altLostReaction: Double {
        return 200.0 * reactionTimeSec / 60.0
    }

    var climbSpeedKtsNorm: Double { climbSpeedKts }

    // ── Density Altitude ─────────────────────────────────────────────────────
    var oatF: Double { oatC * 9.0 / 5.0 + 32.0 }
    var pressureAltFt: Double {
        switch pressureAltSource {
        case 1:  return manualPressureAlt
        case 2:  return airportElevFt + (29.92 - altimeterSetting) * 1000.0
        default: return airportElevFt
        }
    }
    var densityAltFt: Double {
        let isaTempC = 15.0 - 1.98 * (pressureAltFt / 1000.0)
        return pressureAltFt + 120.0 * (oatC - isaTempC)
    }
    /// TAS = IAS × tasIasRatio (≈2% per 1,000 ft density altitude; <1.0 on cold days)
    var tasIasRatio: Double { max(0.5, 1.0 + 0.02 * densityAltFt / 1000.0) }
    /// Climb rate corrected for density altitude (~3%/1,000 ft; improves on cold days)
    var correctedClimbRateFpm: Double { max(50.0, climbRateFpm * (1.0 - 0.03 * densityAltFt / 1000.0)) }

    func distFromRunwayAtAlt(altFt: Double, headwindKts: Double) -> Double {
        let tasClimb = climbSpeedKtsNorm * tasIasRatio
        let climbGroundSpeedKts = max(tasClimb - headwindKts, 1.0)
        let climbGradientFtPerNM = max(correctedClimbRateFpm, 1.0) / climbGroundSpeedKts * 6076.12 / 60.0
        guard climbGradientFtPerNM > 0 else { return 0 }
        return altFt / climbGradientFtPerNM
    }

    func distBackNM(headwindKts: Double, turnDeg: Double) -> Double {
        return glideDistNeededNM(headwindKts: headwindKts, failureAlt: 0, turnDeg: turnDeg)
    }

    func distCoveredReactionNM(headwindKts: Double) -> Double {
        let tasClimb = climbSpeedKtsNorm * tasIasRatio
        let groundSpeedKts = max(tasClimb - headwindKts, 1.0)
        return groundSpeedKts * (reactionTimeSec / 3600.0)
    }

    func glideDistNeededNM(headwindKts: Double, failureAlt: Double, turnDeg: Double = 180.0) -> Double {
        guard turnRateDegPerSec > 1.0 else { return 999.0 }
        let distOut    = distFromRunwayAtAlt(altFt: failureAlt, headwindKts: headwindKts)
        let rxnDist    = distCoveredReactionNM(headwindKts: headwindKts)
        let runwayLengthNM = runwayLengthFt / 6076.12
        let groundRollNM   = groundRollFt / 6076.12
        let vNMperSec  = glide / 3600.0
        let rAero      = vNMperSec / (turnRateDegPerSec * .pi / 180.0)
        let gsTurn     = max(glide - headwindKts, 1.0)
        let rGnd       = rAero * (gsTurn / glide)
        // Only the distance past the departure end matters longitudinally;
        // if still over the runway, lateral offset (turn radius) is the sole constraint.
        let longit     = max(0, groundRollNM + distOut + rxnDist - runwayLengthNM)

        let lateral = 2.0 * rGnd
        return (longit * longit + lateral * lateral).squareRoot()
    }

    func lateralOffsetNM(headwindKts: Double, failureAlt: Double, turnDeg: Double = 180.0) -> Double {
        return glideDistNeededNM(headwindKts: headwindKts, failureAlt: failureAlt, turnDeg: turnDeg)
            - runwayLengthFt / 2.0 / 6076.12
    }

    func glideDistReturnNM(altitudeFt: Double, headwindKts: Double) -> Double {
        let tailwindKts = headwindKts
        let tasAtGlide = glide * tasIasRatio
        let groundSpeedReturn = tasAtGlide + tailwindKts
        let effectiveRatio = ac.glideRatio * (groundSpeedReturn / glide)
        return altitudeFt * effectiveRatio / 6076.12
    }

    func minimumReturnAltitude(headwindKts: Double, turnDeg: Double = 180.0) -> Double? {
        guard turnRateDegPerSec > 1.0 else { return nil }
        let turnTimeSec = turnDeg / turnRateDegPerSec
        let altLostTurn = rateOfDescentFpm * turnTimeSec / 60.0
        let runwayNM = (runwayLengthFt / 2.0) / 6076.12

        for altStep in stride(from: 100.0, through: 5000.0, by: 20.0) {
            let offsetNM = lateralOffsetNM(headwindKts: headwindKts, failureAlt: altStep, turnDeg: turnDeg)
            let distNeededNM = offsetNM + runwayNM
            let altAfterReaction = altStep - altLostReaction
            guard altAfterReaction > 0 else { continue }
            let altAfterTurn = altAfterReaction - altLostTurn
            guard altAfterTurn > 0 else { continue }
            let altForGlide = altAfterTurn - thresholdCrossingHt
            guard altForGlide > 0 else { continue }
            let distAvailableNM = glideDistReturnNM(altitudeFt: altForGlide, headwindKts: headwindKts)
            if distAvailableNM >= distNeededNM { return altStep }
        }
        return nil
    }

    // ── 180° turn ──────────────────────────────────────────────────────────────
    var minReturnAltNoWind: Double?    { minimumReturnAltitude(headwindKts: 0,       turnDeg: 180) }
    var minReturnAltWithWind: Double?  { minimumReturnAltitude(headwindKts: windKts, turnDeg: 180) }
    var minReturnAltGeoNoWind: Double? { minimumReturnAltitudeCustomThreshold(headwindKts: 0,       threshold: 0, turnDeg: 180) }
    var minReturnAltGeoWithWind: Double?{ minimumReturnAltitudeCustomThreshold(headwindKts: windKts, threshold: 0, turnDeg: 180) }


    func canReturn(failureAlt: Double, headwindKts: Double, threshold: Double, turnDeg: Double = 180.0) -> Bool {
        guard turnRateDegPerSec > 1.0 else { return false }
        let turnTimeSec = turnDeg / turnRateDegPerSec
        let altLostTurn = rateOfDescentFpm * turnTimeSec / 60.0
        let offsetNM = lateralOffsetNM(headwindKts: headwindKts, failureAlt: failureAlt, turnDeg: turnDeg)
        let runwayNM = (runwayLengthFt / 2.0) / 6076.12
        let distNeededNM = offsetNM + runwayNM
        let altAfterReaction = failureAlt - altLostReaction
        guard altAfterReaction > 0 else { return false }
        let altAfterTurn = altAfterReaction - altLostTurn
        guard altAfterTurn > 0 else { return false }
        let altForGlide = altAfterTurn - threshold
        guard altForGlide > 0 else { return false }
        let distAvailableNM = glideDistReturnNM(altitudeFt: altForGlide, headwindKts: headwindKts)
        return distAvailableNM >= distNeededNM
    }

    var engineFailureAltAGL: Double { max(0, engineFailureAlt - airportElevFt) }
    var engineFailureAltMSL: Double { engineFailureAlt }

    var canReturnGeoNoWind: Bool   { canReturn(failureAlt: engineFailureAltAGL, headwindKts: 0,        threshold: 0,                  turnDeg: 180) }
    var canReturnGeoWithWind: Bool { canReturn(failureAlt: engineFailureAltAGL, headwindKts: windKts,  threshold: 0,                  turnDeg: 180) }
    var canReturnFullNoWind: Bool  { canReturn(failureAlt: engineFailureAltAGL, headwindKts: 0,        threshold: thresholdCrossingHt, turnDeg: 180) }
    var canReturnFullWithWind: Bool{ canReturn(failureAlt: engineFailureAltAGL, headwindKts: windKts,  threshold: thresholdCrossingHt, turnDeg: 180) }


    func minimumReturnAltitudeCustomThreshold(headwindKts: Double, threshold: Double, turnDeg: Double = 180.0) -> Double? {
        guard turnRateDegPerSec > 1.0 else { return nil }
        let turnTimeSec = turnDeg / turnRateDegPerSec
        let altLostTurn = rateOfDescentFpm * turnTimeSec / 60.0
        let runwayNM = (runwayLengthFt / 2.0) / 6076.12
        for altStep in stride(from: 100.0, through: 5000.0, by: 20.0) {
            let offsetNM = lateralOffsetNM(headwindKts: headwindKts, failureAlt: altStep, turnDeg: turnDeg)
            let distNeededNM = offsetNM + runwayNM
            let altAfterReaction = altStep - altLostReaction
            guard altAfterReaction > 0 else { continue }
            let altAfterTurn = altAfterReaction - altLostTurn
            guard altAfterTurn > 0 else { continue }
            let altForGlide = altAfterTurn - threshold
            guard altForGlide > 0 else { continue }
            let distAvailableNM = glideDistReturnNM(altitudeFt: altForGlide, headwindKts: headwindKts)
            if distAvailableNM >= distNeededNM { return altStep }
        }
        return nil
    }

    // ── Rate of Descent ───────────────────────────────────────────────────────
    var rateOfDescentFpm: Double {
        let speedFps = glide * tasIasRatio * 6076.12 / 3600.0
        return speedFps * 60.0 / ac.glideRatio
    }

    var turnRateDegPerSec: Double {
        guard bankDeg > 5 else { return 0.0 }
        let vFps = glide * tasIasRatio * 6076.12 / 3600.0
        let rate = (32.174 * tan(bankDeg * .pi / 180)) / vFps
        return rate * 180.0 / .pi
    }

    func altitudeLost(degrees: Double) -> Double {
        guard turnRateDegPerSec > 0 else { return 0 }
        let timeSec = degrees / turnRateDegPerSec
        return rateOfDescentFpm * timeSec / 60.0
    }

    func remainingAlt(degrees: Double) -> Double {
        return max(0, altFt - altitudeLost(degrees: degrees))
    }

    let appBG = Color(red: 0.055, green: 0.068, blue: 0.085)

    private struct TabDef {
        let index: Int; let label: String; let icon: String
    }
    private let tabs = [
        TabDef(index: 0, label: "Aircraft Glide",  icon: "airplane"),
        TabDef(index: 1, label: "Conditions",       icon: "cloud.sun.fill"),
        TabDef(index: 2, label: "Full Briefing",    icon: "list.bullet.rectangle.portrait"),
        TabDef(index: 3, label: "Brief",            icon: "doc.text.fill")
    ]

    @ViewBuilder private var tabContent: some View {
        switch selectedTab {
        case 0: aircraftTab
        case 1: conditionsTab
        case 2: fullBriefingTab
        default: briefTab
        }
    }

    private var iPadTopTabBar: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.index) { tab in
                Button(action: { selectedTab = tab.index }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16, weight: selectedTab == tab.index ? .bold : .regular))
                        Text(tab.label)
                            .font(.system(size: 12, weight: selectedTab == tab.index ? .bold : .regular,
                                          design: .monospaced))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundColor(selectedTab == tab.index ? ac.accentColor : Color(white: 0.45))
                    .background(
                        selectedTab == tab.index
                            ? ac.accentColor.opacity(0.12)
                            : Color.clear
                    )
                    .overlay(alignment: .bottom) {
                        if selectedTab == tab.index {
                            Rectangle()
                                .fill(ac.accentColor)
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(white: 0.06))
        .overlay(alignment: .bottom) {
            Divider().background(Color(white: 0.15))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sizeClass == .regular {
                    // iPad: custom top tab bar
                    VStack(spacing: 0) {
                        iPadTopTabBar
                        tabContent
                    }
                } else {
                    // iPhone: standard bottom tab bar
                    TabView(selection: $selectedTab) {
                        aircraftTab.tag(0)
                            .tabItem { Label("Aircraft Glide", systemImage: "airplane") }
                        conditionsTab.tag(1)
                            .tabItem { Label("Conditions", systemImage: "cloud.sun.fill") }
                        fullBriefingTab.tag(2)
                            .tabItem { Label("Full Briefing", systemImage: "list.bullet.rectangle.portrait") }
                        briefTab.tag(3)
                            .tabItem { Label("Brief", systemImage: "doc.text.fill") }
                    }
                }
            }
            .background(appBG.ignoresSafeArea())
            .navigationTitle(ac.fullName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.06), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onChangeAircraft) {
                        HStack(spacing: 5) {
                            Image(systemName: "airplane")
                                .font(.system(size: 12))
                            Text(ac.id)
                                .font(.system(.subheadline, design: .monospaced).bold())
                        }
                        .foregroundColor(ac.accentColor)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.async {
                loadSettings()
                weight = max(ac.minWeight, min(ac.mtow, weight))
                displayed = glide
            }
        }
        .onDisappear { saveSettings() }
    }

    var aircraftTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                gaugeSection
                weightSection
                altSection
                distSection
                stallSection
                turnSection
            }
            .padding(16)
        }
        .background(appBG.ignoresSafeArea())
    }

    var conditionsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S CONDITIONS")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Set airport, weather, and runway details for this departure")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                returnInputsCard
                    .padding(16)
                    .background(CardBG(accent: ac.accentColor.opacity(0.18)))
                    .padding(.horizontal, 16)

                returnFailureAltCard
                    .padding(.horizontal, 16)

                formulaSection
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .background(appBG.ignoresSafeArea())
    }

    var fullBriefingTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FULL BRIEFING")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Detailed calculations and phase breakdown")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                returnResultsCard
                returnPhaseBreakdown

                Text("FOR SIMULATION & TRAINING ONLY · VERIFY WITH POH")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .background(appBG.ignoresSafeArea())
    }

    var briefTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRE-FLIGHT BRIEF")
                        .font(.system(size: 20, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("Key numbers to write down before takeoff")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)

                if bankDeg < 5 {
                    Text("⚠ SET BANK ANGLE IN THE AIRCRAFT TAB TO COMPUTE TURN PERFORMANCE")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                }

                summaryCard

                // Last-minute pilot correction slider
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("PILOT CORRECTION FACTOR")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(white: 0.7))
                            Text("Adds a safety buffer to the minimum return altitudes above")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(white: 0.45))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Text(pilotCorrectionPct == 0 ? "None" : "+\(Int(pilotCorrectionPct))%")
                            .font(.system(size: 18, weight: .heavy, design: .monospaced))
                            .foregroundColor(pilotCorrectionPct == 0 ? Color(white: 0.4) : ac.accentColor)
                    }
                    Slider(value: $pilotCorrectionPct, in: 0...100, step: 5)
                        .tint(ac.accentColor)
                    HStack {
                        Text("No correction")
                        Spacer()
                        Text("+100%")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(white: 0.35))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(white: 0.05))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ac.accentColor.opacity(0.25), lineWidth: 1))
                )
                .padding(.horizontal, 16)

                Text("FOR SIMULATION & TRAINING ONLY · VERIFY WITH POH")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Color(white: 0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .background(appBG.ignoresSafeArea())
    }

    // MARK: Gauge

    var gaugeSection: some View {
        VStack(spacing: 14) {
            Text("BEST GLIDE SPEED")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.5)

            GaugeView(value: displayed, color: ac.accentColor)
                .frame(width: 200, height: 200)
                .onChange(of: glide) { animateNeedle() }

            HStack(spacing: 0) {
                SpeedPair(kts: glide, mph: glideMph, color: ac.accentColor, label: "BEST GLIDE")
                    .frame(maxWidth: .infinity)
                Divider()
                    .background(Color(white: 0.15))
                    .frame(height: 60)
                VStack(spacing: 4) {
                    Text("L/D RATIO")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(Color.white)
                        .kerning(1.2)
                    Text(String(format: "%.1f : 1", ac.glideRatio))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(ac.accentColor.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ac.accentColor.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ac.accentColor.opacity(0.2), lineWidth: 1))
            )
        }
        .padding(20)
        .background(CardBG(accent: ac.accentColor.opacity(0.22)))
    }

    // MARK: Weight

    var weightSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("GROSS WEIGHT")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.5)
            weightRow
            Slider(value: $weight, in: ac.minWeight...ac.mtow, step: 10)
                .tint(ac.accentColor)
                .onChange(of: weight) { animateNeedle() }
            HStack {
                Text("\(Int(ac.minWeight)) lb")
                Spacer()
                Text("MTOW \(Int(ac.mtow)) lb")
            }
            .font(.system(size: 15, design: .monospaced))
            .foregroundColor(Color.white)
        }
        .padding(16)
        .background(CardBG())
    }

    var weightRow: some View {
        HStack {
            Text("\(Int(weight)) lb")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(weight > ac.mtow ? Color.red : ac.accentColor)
            Spacer()
            if weight > ac.mtow {
                Text("OVER MTOW")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(Color.red)
            }
        }
    }

    // MARK: Altitude

    var altSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ALTITUDE AGL")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.5)
            Text("\(Int(altFt)) ft")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.48, green: 0.71, blue: 0.88))
            Slider(value: $altFt, in: 500...18000, step: 500)
                .tint(Color(red: 0.48, green: 0.71, blue: 0.88))
            HStack {
                Text("500 ft")
                Spacer()
                Text("18,000 ft")
            }
            .font(.system(size: 15, design: .monospaced))
            .foregroundColor(Color.white)
        }
        .padding(16)
        .background(CardBG())
    }

    // MARK: Distance

    var distSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GLIDE DISTANCE FROM \(Int(altFt)) FT AGL")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.5)
            HStack(spacing: 10) {
                DistTile(value: String(format: "%.1f", distNM),           unit: "NM", label: "NAUTICAL MI")
                DistTile(value: String(format: "%.1f", distNM * 1.15078), unit: "SM", label: "STATUTE MI")
                DistTile(value: String(format: "%.1f", distNM * 1.852),   unit: "KM", label: "KILOMETERS")
            }
        }
        .padding(16)
        .background(CardBG())
    }

    // MARK: Stall Speed vs Bank Angle

    var stallSection: some View {
        return AnyView(VStack(alignment: .leading, spacing: 12) {
            Text("STALL SPEED VS BANK ANGLE")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.5)

            BankDiagram(bankDeg: bankDeg, color: ac.accentColor)
                .frame(height: 130)
                .frame(maxWidth: .infinity)

            HStack {
                Text("BANK")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(Color.white)
                Spacer()
                Text("\(Int(bankDeg.rounded()))°")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(ac.accentColor)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.1), value: Int(bankDeg))
            }

            Slider(value: $bankDeg, in: 0...80, step: 1)
                .tint(ac.accentColor)

            HStack {
                Text("0°")
                Spacer()
                Text("20°")
                Spacer()
                Text("40°")
                Spacer()
                Text("60°")
                Spacer()
                Text("80°")
            }
            .font(.system(size: 15, design: .monospaced))
            .foregroundColor(Color.white)

            HStack(spacing: 0) {
                SpeedPair(kts: stall.kts, mph: stall.mph, color: ac.accentColor, label: "STALL SPEED")
                    .frame(maxWidth: .infinity)

                Divider()
                    .background(Color(white: 0.15))
                    .frame(height: 60)

                VStack(spacing: 4) {
                    Text("LOAD FACTOR")
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(Color.white)
                        .kerning(1.0)
                    let lf = bankDeg < 90 ? 1.0 / cos(bankDeg * .pi / 180) : 99.0
                    Text(String(format: "%.2f G", lf))
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(lf > 3.5 ? Color.red : ac.accentColor.opacity(0.8))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ac.accentColor.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ac.accentColor.opacity(0.2), lineWidth: 1))
            )

            pohTable
        }
        .padding(16)
        .background(CardBG(accent: ac.accentColor.opacity(0.18))))
    }

    var pohTable: some View {
        VStack(spacing: 0) {
            Text(ac.isUserDefined ? "CALCULATED REFERENCE  (FLAPS UP)" : "POH REFERENCE  (FLAPS UP)")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 6)

            HStack(spacing: 0) {
                Text("BANK")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("STALL KTS")
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("STALL MPH")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(ac.accentColor)
            .padding(.bottom, 4)

            ForEach([0.0, 20.0, 40.0, 60.0], id: \.self) { deg in
                let s = ac.stallSpeed(bankDeg: deg, weight: weight)
                let isActive = abs(bankDeg - deg) < 10
                HStack(spacing: 0) {
                    Text("\(Int(deg))°")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(format: "%.0f", s.kts))
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text(String(format: "%.0f", s.mph))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(isActive ? ac.accentColor : Color.white)
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(isActive ? ac.accentColor.opacity(0.08) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.10), lineWidth: 1))
        )
    }


    // MARK: Turn Altitude Loss

    var turnSection: some View {
        return AnyView(VStack(alignment: .leading, spacing: 12) {
            Text("ALTITUDE LOST IN GLIDE TURN")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.5)

            HStack(spacing: 0) {
                turnParam(label: "BANK", value: String(format: "%d°", Int(bankDeg.rounded())), color: ac.accentColor)
                Divider().background(Color(white: 0.15)).frame(height: 44)
                turnParam(label: "GLIDE SPEED", value: String(format: "%d KTS", Int(glide.rounded())), color: ac.accentColor)
                Divider().background(Color(white: 0.15)).frame(height: 44)
                turnParam(label: "TURN RATE", value: String(format: "%.1f°/s", turnRateDegPerSec), color: ac.accentColor)
                Divider().background(Color(white: 0.15)).frame(height: 44)
                turnParam(label: "ROD", value: String(format: "%d FPM", Int(rateOfDescentFpm.rounded())), color: ac.accentColor)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(ac.accentColor.opacity(0.06))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ac.accentColor.opacity(0.2), lineWidth: 1))
            )

            HStack {
                Text("STARTING ALTITUDE")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(Color.white)
                    .kerning(1.2)
                Spacer()
                Text("\(Int(altFt)) FT AGL")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.48, green: 0.71, blue: 0.88))
            }

            turnRow(degrees: 180)
            turnRow(degrees: 360)

            if bankDeg < 5 {
                Text("⚠ SET A BANK ANGLE IN THE STALL SECTION ABOVE")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .background(CardBG(accent: ac.accentColor.opacity(0.18))))
    }

    func turnParam(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.0)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    func turnRow(degrees: Double) -> some View {
        let lost = altitudeLost(degrees: degrees)
        let remaining = remainingAlt(degrees: degrees)
        let isGroundContact = remaining <= 0
        let pct = min(1.0, lost / altFt)
        let timeSec = turnRateDegPerSec > 0 ? degrees / turnRateDegPerSec : 0
        let timeMin = Int(timeSec / 60)
        let timeSec2 = Int(timeSec) % 60
        let timeStr = timeMin > 0 ? "\(timeMin)m \(timeSec2)s" : "\(timeSec2)s"

        return VStack(spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(Int(degrees))° TURN")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(isGroundContact ? .red : Color.white)
                    Text("TIME: \(timeStr)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(isGroundContact ? .red.opacity(0.8) : Color.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("-\(Int(lost.rounded())) FT")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(isGroundContact ? .red : ac.accentColor)
                    Text("REMAINING: \(Int(remaining.rounded())) FT AGL")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(isGroundContact ? .red : Color.white)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(white: 0.10))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isGroundContact ? Color.red : ac.accentColor.opacity(0.8))
                        .frame(width: geo.size.width * pct, height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isGroundContact ? Color.red.opacity(0.08) : Color(white: 0.05))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(isGroundContact ? Color.red.opacity(0.4) : Color(white: 0.10), lineWidth: 1))
        )
    }



    var summaryCard: some View {
        let corrFactor  = 1.0 + pilotCorrectionPct / 100.0
        let noWindAGL   = (minReturnAltNoWind   ?? 0) * corrFactor
        let withWindAGL = (minReturnAltWithWind ?? 0) * corrFactor
        let noWindMSL   = noWindAGL + airportElevFt
        let withWindMSL = withWindAGL + airportElevFt

        return VStack(alignment: .leading, spacing: 10) {
            Text("PILOT SUMMARY — \(ac.fullName.uppercased())")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(ac.accentColor)
                .kerning(1.2)

            Divider().background(Color(white: 0.2))

            HStack {
                Text("PARAMETER").frame(maxWidth: .infinity, alignment: .leading)
                Text("VALUE").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundColor(Color(white: 0.5))

            Divider().background(Color(white: 0.12))

            Group {
                sumRow("BEST GLIDE SPEED",
                       "\(Int(glide.rounded())) kts  /  \(Int(glideMph.rounded())) mph")
                sumRow("STALL SPEED (\(Int(bankDeg.rounded()))° BANK)",
                       "\(Int(stall.kts.rounded())) kts  /  \(Int(stall.mph.rounded())) mph")
                sumRow("BANK ANGLE", "\(Int(bankDeg.rounded()))°")
                sumRow("CLIMB SPEED (Vy)",
                       "\(Int(climbSpeedKts.rounded())) kts  /  \(Int((climbSpeedKts * 1.15078).rounded())) mph")
                sumRow("CLIMB RATE (POH)", "\(Int(climbRateFpm.rounded())) fpm")
                sumRow("DENSITY ALTITUDE", String(format: "%d ft", Int(densityAltFt.rounded())))
                sumRow("CORRECTED CLIMB RATE", String(format: "%d fpm", Int(correctedClimbRateFpm.rounded())))
            }

            Divider().background(Color(white: 0.12))

            Group {
                let corrLabel = pilotCorrectionPct > 0 ? " +\(Int(pilotCorrectionPct))% CORRECTION" : ""
                if let _ = minReturnAltNoWind {
                    sumRowAlt("NO WIND\(corrLabel)",
                              msl: noWindMSL, agl: noWindAGL, color: ac.accentColor)
                } else {
                    sumRow("NO WIND\(corrLabel)", "> 6,000 ft AGL")
                }
                if windKts > 0 {
                    if let _ = minReturnAltWithWind {
                        sumRowAlt("\(Int(windKts)) KTS HEADWIND\(corrLabel)",
                                  msl: withWindMSL, agl: withWindAGL, color: ac.accentColor)
                    } else {
                        sumRow("\(Int(windKts)) KTS HEADWIND\(corrLabel)", "> 6,000 ft AGL")
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.05))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ac.accentColor.opacity(0.25), lineWidth: 1))
        )
    }

    func sumRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white: 0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    func sumRowAlt(_ label: String, msl: Double, agl: Double, color: Color) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(Color(white: 0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(msl.rounded())) ft MSL")
                    .font(.system(size: 16, weight: .heavy, design: .monospaced))
                    .foregroundColor(color)
                Text("\(Int(agl.rounded())) ft AGL")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color(white: 0.6))
            }
        }
    }

    var atmosphericRow: some View {
        AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OUTSIDE AIR TEMPERATURE")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color.white)
                            .kerning(1.0)
                        Text("Used to calculate density altitude and performance corrections")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Picker("", selection: $tempUnit) {
                        Text("°C").tag(0)
                        Text("°F").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }

                let tempBinding = Binding<Double>(
                    get: { tempUnit == 0 ? oatC : oatF },
                    set: { val in
                        if tempUnit == 0 { oatC = val }
                        else { oatC = (val - 32.0) * 5.0 / 9.0 }
                    }
                )
                let lo: Double = tempUnit == 0 ? -40 : -40
                let hi: Double = tempUnit == 0 ?  50 : 122
                let displayVal = tempUnit == 0
                    ? String(format: "%.0f°C  (%.0f°F)", oatC, oatF)
                    : String(format: "%.0f°F  (%.0f°C)", oatF, oatC)

                Text(displayVal)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(ac.accentColor)

                Slider(value: tempBinding, in: lo...hi, step: 1).tint(ac.accentColor)
                sliderEndLabels(
                    tempUnit == 0 ? "-40°C" : "-40°F",
                    tempUnit == 0 ?  "50°C" : "122°F"
                )

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DENSITY ALTITUDE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                        let daColor: Color = densityAltFt > airportElevFt + 2000 ? .orange :
                                             densityAltFt > airportElevFt + 500  ? .yellow : .green
                        Text(String(format: "%d ft", Int(densityAltFt.rounded())))
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(daColor)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("CORRECTED CLIMB RATE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                        Text(String(format: "%d fpm", Int(correctedClimbRateFpm.rounded())))
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(ac.accentColor)
                    }
                }
                .padding(.top, 4)
            }
        )
    }

    var airportElevationRow: some View {
        AnyView(
            VStack(alignment: .leading, spacing: 10) {

                // ── Source picker ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRESSURE ALTITUDE SOURCE")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color.white)
                        .kerning(1.0)
                    Picker("", selection: $pressureAltSource) {
                        Text("Field Elev").tag(0)
                        Text("Manual PA").tag(1)
                        Text("Elev + Baro").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                // ── Field elevation (source 0 or 2) ───────────────────────
                if pressureAltSource == 0 || pressureAltSource == 2 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("AIRPORT ELEVATION")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(Color.white)
                                    .kerning(1.0)
                                Text("Field elevation MSL")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                            Spacer()
                            HStack(spacing: 0) {
                                Button { airportElevFt = max(0, airportElevFt - 10) } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ac.accentColor)
                                        .frame(width: 36, height: 36)
                                        .background(ac.accentColor.opacity(0.15))
                                }
                                Text("\(Int(airportElevFt))")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(ac.accentColor)
                                    .frame(minWidth: 52)
                                    .multilineTextAlignment(.center)
                                Button { airportElevFt = min(14000, airportElevFt + 10) } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ac.accentColor)
                                        .frame(width: 36, height: 36)
                                        .background(ac.accentColor.opacity(0.15))
                                }
                            }
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ac.accentColor.opacity(0.3), lineWidth: 1))
                        }
                        Slider(value: $airportElevFt, in: 0...14000, step: 10).tint(ac.accentColor)
                        sliderEndLabels("Sea level", "14,000 ft")
                    }
                }

                // ── Altimeter setting (source 2) ───────────────────────────
                if pressureAltSource == 2 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("ALTIMETER SETTING")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(Color.white)
                                    .kerning(1.0)
                                Text("From ATIS or ATC")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                            Spacer()
                            HStack(spacing: 0) {
                                Button { altimeterSetting = max(27.50, (altimeterSetting - 0.01).rounded(to: 2)) } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ac.accentColor)
                                        .frame(width: 36, height: 36)
                                        .background(ac.accentColor.opacity(0.15))
                                }
                                Text(String(format: "%.2f", altimeterSetting))
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(ac.accentColor)
                                    .frame(minWidth: 60)
                                    .multilineTextAlignment(.center)
                                Button { altimeterSetting = min(31.50, (altimeterSetting + 0.01).rounded(to: 2)) } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ac.accentColor)
                                        .frame(width: 36, height: 36)
                                        .background(ac.accentColor.opacity(0.15))
                                }
                            }
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ac.accentColor.opacity(0.3), lineWidth: 1))
                        }
                        Slider(value: $altimeterSetting, in: 27.50...31.50, step: 0.01).tint(ac.accentColor)
                        sliderEndLabels("27.50 inHg", "31.50 inHg")
                        Text(String(format: "Pressure Alt: %d ft", Int(pressureAltFt.rounded())))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(ac.accentColor)
                    }
                }

                // ── Manual pressure altitude (source 1) ───────────────────
                if pressureAltSource == 1 {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("PRESSURE ALTITUDE")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(Color.white)
                                    .kerning(1.0)
                                Text("Read directly from altimeter set to 29.92")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(Color.white.opacity(0.6))
                            }
                            Spacer()
                            HStack(spacing: 0) {
                                Button { manualPressureAlt = max(0, manualPressureAlt - 10) } label: {
                                    Image(systemName: "minus")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ac.accentColor)
                                        .frame(width: 36, height: 36)
                                        .background(ac.accentColor.opacity(0.15))
                                }
                                Text("\(Int(manualPressureAlt))")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(ac.accentColor)
                                    .frame(minWidth: 52)
                                    .multilineTextAlignment(.center)
                                Button { manualPressureAlt = min(16000, manualPressureAlt + 10) } label: {
                                    Image(systemName: "plus")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(ac.accentColor)
                                        .frame(width: 36, height: 36)
                                        .background(ac.accentColor.opacity(0.15))
                                }
                            }
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ac.accentColor.opacity(0.3), lineWidth: 1))
                        }
                        Slider(value: $manualPressureAlt, in: 0...16000, step: 10).tint(ac.accentColor)
                        sliderEndLabels("Sea level", "16,000 ft")
                    }
                }
            }
        )
    }

    @ViewBuilder var returnInputsCard: some View {
        VStack(spacing: 12) {
            Text("INPUTS")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.white)
                    .kerning(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)

                inputRow(
                    label: "REACTION TIME",
                    sublabel: "Seconds from engine failure to establishing glide attitude",
                    value: String(format: "%.1f sec", reactionTimeSec)
                )
                Slider(value: $reactionTimeSec, in: 1...10, step: 0.5).tint(ac.accentColor)
                sliderEndLabels("1 sec", "10 sec")

                Divider().background(Color(white: 0.15))

                inputRow(
                    label: "RUNWAY LENGTH",
                    sublabel: "Full length of departure runway",
                    value: "\(Int(runwayLengthFt)) ft"
                )
                Slider(value: $runwayLengthFt, in: 1000...10000, step: 100).tint(ac.accentColor)
                sliderEndLabels("1,000 ft", "10,000 ft")

                Divider().background(Color(white: 0.15))

                airportElevationRow

                Divider().background(Color(white: 0.15))

                atmosphericRow

                Divider().background(Color(white: 0.15))

                inputRow(
                    label: "GROUND ROLL",
                    sublabel: "Runway distance used before liftoff",
                    value: "\(Int(groundRollFt)) ft"
                )
                Slider(value: $groundRollFt, in: 200...3000, step: 50).tint(ac.accentColor)
                sliderEndLabels("200 ft", "3,000 ft")

                Divider().background(Color(white: 0.15))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CLIMB SPEED (Vy)")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Color.white)
                                .kerning(1.0)
                            Text("Best rate of climb airspeed")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(Color.white)
                        }
                        Spacer()
                    }
                    HStack {
                        Spacer()
                        Text("\(Int(climbSpeedKts)) kts / \(Int((climbSpeedKts * 1.15078).rounded())) mph")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(ac.accentColor)
                    }
                    Slider(value: $climbSpeedKts, in: 50...150, step: 1).tint(ac.accentColor)
                    sliderEndLabels("50 kts", "150 kts")
                }

                Divider().background(Color(white: 0.15))

                VStack(alignment: .leading, spacing: 6) {
                    inputRow(
                        label: "CLIMB RATE",
                        sublabel: "Rate of climb after liftoff",
                        value: "\(Int(climbRateFpm)) fpm"
                    )
                    Slider(value: $climbRateFpm, in: 100...2000, step: 50).tint(ac.accentColor)
                    sliderEndLabels("100 fpm", "2,000 fpm")
                    let gsKts = max(climbSpeedKtsNorm - windKts, 1.0)
                    let gradFtPerNM = climbRateFpm / gsKts * 6076.12 / 60.0
                    Text("Climb gradient: \(Int(gradFtPerNM)) ft/NM · \(String(format: "%.1f", gradFtPerNM / 6076.12 * 100))% slope")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color.white)
                }

                Divider().background(Color(white: 0.15))

                inputRow(
                    label: "THRESHOLD CROSSING HEIGHT",
                    sublabel: "Minimum height AGL needed over the runway threshold to complete a safe landing flare",
                    value: "\(Int(thresholdCrossingHt)) ft AGL"
                )
                Slider(value: $thresholdCrossingHt, in: 0...500, step: 25).tint(ac.accentColor)
                sliderEndLabels("0 ft (geometric only)", "500 ft")

                Divider().background(Color(white: 0.15))

                inputRow(
                    label: "DEPARTURE HEADWIND",
                    sublabel: "Headwind on takeoff becomes a tailwind on return, reducing glide range",
                    value: windKts == 0 ? "Calm" : "\(Int(windKts)) kts"
                )
                Slider(value: $windKts, in: 0...30, step: 1).tint(ac.accentColor)
                sliderEndLabels("Calm", "30 kts headwind")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.05))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.12), lineWidth: 1))
            )
    }

    @ViewBuilder var returnFailureAltCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            inputRow(
                label: "ENGINE FAILURE ALTITUDE",
                sublabel: "Enter as MSL — AGL is calculated from airport elevation above",
                value: engineFailureAltAGL > 0
                    ? "\(Int(engineFailureAltMSL)) ft MSL  (\(Int(engineFailureAltAGL)) ft AGL)"
                    : "\(Int(engineFailureAltMSL)) ft MSL  (below airport elevation)"
            )
            if engineFailureAltAGL <= 0 {
                Text("⚠ MSL altitude is at or below airport elevation — increase the slider")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Slider(value: $engineFailureAlt,
                   in: 0...15000,
                   step: 50).tint(engineFailureAltAGL > 0 ? ac.accentColor : .red)
            sliderEndLabels("0 ft MSL", "15,000 ft MSL")
            HStack(spacing: 6) {
                ForEach([-50, -5], id: \.self) { step in
                    Button {
                        engineFailureAlt = max(0, min(15000, engineFailureAlt + Double(step)))
                    } label: {
                        Text("\(step) ft")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(ac.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(ac.accentColor.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
                Spacer()
                ForEach([5, 50], id: \.self) { step in
                    Button {
                        engineFailureAlt = max(0, min(15000, engineFailureAlt + Double(step)))
                    } label: {
                        Text("+\(step) ft")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(ac.accentColor)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(ac.accentColor.opacity(0.12))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.05))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.12), lineWidth: 1))
        )
    }

    var returnResultsCard: some View {
        return AnyView(VStack(alignment: .leading, spacing: 14) {
            Text("RESULTS — MINIMUM ENGINE FAILURE ALTITUDE AGL")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.5)
                .fixedSize(horizontal: false, vertical: true)

                turnStrategyBlock(
                    windLabel: "NO WIND",
                    geoAlt: minReturnAltGeoNoWind,
                    fullAlt: minReturnAltNoWind,
                    failureAlt: engineFailureAltAGL,
                    color: ac.accentColor,
                    isWind: false
                )

                if windKts > 0 {
                    Divider().background(Color.white)
                    turnStrategyBlock(
                        windLabel: "\(Int(windKts)) KTS HEADWIND ON DEPARTURE",
                        geoAlt: minReturnAltGeoWithWind,
                        fullAlt: minReturnAltWithWind,
                        failureAlt: engineFailureAltAGL,
                        color: Color(red: 0.48, green: 0.71, blue: 0.88),
                        isWind: true
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.05))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ac.accentColor.opacity(0.25), lineWidth: 1))
            ))
    }

    func inputRow(label: String, sublabel: String, value: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.white)
                    .kerning(1.0)
                Text(sublabel)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(ac.accentColor)
                .multilineTextAlignment(.trailing)
        }
    }

    func sliderEndLabels(_ left: String, _ right: String) -> some View {
        HStack {
            Text(left)
            Spacer()
            Text(right)
        }
        .font(.system(size: 13, design: .monospaced))
        .foregroundColor(Color.white)
    }

    func turnStrategyBlock(windLabel: String,
                           geoAlt: Double?, fullAlt: Double?,
                           failureAlt: Double, color: Color, isWind: Bool) -> some View {
        let fullOk = isWind ? canReturnFullWithWind : canReturnFullNoWind
        let geoOk  = isWind ? canReturnGeoWithWind  : canReturnGeoNoWind

        return AnyView(VStack(alignment: .leading, spacing: 12) {
            Text(windLabel)
                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
                .kerning(1.2)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(color.opacity(0.12))
                .cornerRadius(7)

            let hw           = isWind ? windKts : 0.0
            let climbDistNM  = distFromRunwayAtAlt(altFt: failureAlt, headwindKts: hw)
            let distFromEnd  = max(0.0, groundRollFt / 6076.12 + climbDistNM - runwayLengthFt / 6076.12)
            let distBack     = glideDistNeededNM(headwindKts: hw, failureAlt: failureAlt, turnDeg: 180)
            let altLostRx    = altLostReaction
            let altLost180   = rateOfDescentFpm * (180.0 / max(turnRateDegPerSec, 0.01)) / 60.0
            let gsReturn     = glide + hw
            let effRatio     = ac.glideRatio * (gsReturn / glide)
            let altForGlide  = max(0, failureAlt - altLostRx - altLost180 - thresholdCrossingHt)
            let glideAvail   = altForGlide * effRatio / 6076.12
            let glideMargin  = glideAvail - distBack

            // Distances card
            VStack(alignment: .leading, spacing: 8) {
                Text("DISTANCES AT ENGINE FAILURE (\(Int(failureAlt + airportElevFt)) FT MSL / \(Int(failureAlt)) FT AGL)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white)
                    .kerning(1.0)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(distFromEnd > 0
                             ? "OUT — DISTANCE PAST DEPARTURE END AT ENGINE FAILURE"
                             : "AIRCRAFT STILL OVER RUNWAY AT ENGINE FAILURE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(distFromEnd > 0 ? Color.white : ac.accentColor)
                            .kerning(0.8)
                        Text(distFromEnd > 0
                             ? "How far the aircraft has travelled beyond the departure end of the runway when the engine fails."
                             : "Engine failure occurs before reaching the departure end. Aircraft can turn back and land within the remaining runway.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        if distFromEnd > 0 {
                            Text(String(format: "%.2f NM", distFromEnd))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(ac.accentColor)
                            Text("\(Int((distFromEnd * 6076.12).rounded())) ft")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(Color.white)
                        } else {
                            Text("—")
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(white: 0.5))
                        }
                    }
                }

                Divider().background(Color(white: 0.15))

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(distFromEnd > 0
                             ? "BACK — GLIDE DISTANCE TO DEPARTURE END (180° TURN)"
                             : "LATERAL ALIGNMENT — DISTANCE TO RE-ALIGN WITH RUNWAY CENTERLINE")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white)
                            .kerning(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(distFromEnd > 0
                             ? "Diagonal glide distance needed to reach the departure end after completing the 180° turn. = √((2r)²+(out+rxn)²)"
                             : "Aircraft is over the runway — only needs to cover the lateral turn offset (2 × turn radius) to re-align with the centerline.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.2f NM", distBack))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(ac.accentColor)
                        Text("\(Int((distBack * 6076.12).rounded())) ft")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color.white)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(Color(white: 0.05))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(white: 0.10), lineWidth: 1)))

            // Glide available vs needed
            VStack(alignment: .leading, spacing: 8) {
                Text("GLIDE RANGE AT ENGINE FAILURE (\(Int(failureAlt + airportElevFt)) FT MSL / \(Int(failureAlt)) FT AGL)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white)
                    .kerning(1.0)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEEDED")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.white)
                        Text(String(format: "%.2f NM", distBack))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.red.opacity(0.9))
                        Text("\(Int((distBack * 6076.12).rounded())) ft")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .center, spacing: 2) {
                        Text("AVAILABLE")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.white)
                        Text(String(format: "%.2f NM", glideAvail))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.9))
                        Text("\(Int((glideAvail * 6076.12).rounded())) ft")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(Color.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("MARGIN")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.white)
                        Text(String(format: "%+.2f NM", glideMargin))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(glideMargin >= 0 ? .green : .red)
                        Text("\(glideMargin >= 0 ? "+" : "")\(Int((glideMargin * 6076.12).rounded())) ft")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(glideMargin >= 0 ? .green.opacity(0.8) : .red.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(glideMargin >= 0 ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 6)
                    .stroke(glideMargin >= 0 ? Color.green.opacity(0.25) : Color.red.opacity(0.25), lineWidth: 1)))

            // Geometric minimum (0 ft threshold)
            altRow(
                rowLabel: "REACH RUNWAY (0 ft at threshold)",
                sublabel: "Geometrically possible to reach runway. No flare margin.",
                altOpt: geoAlt,
                failureAlt: failureAlt,
                canMakeIt: geoOk,
                color: color
            )

            // With threshold crossing height
            altRow(
                rowLabel: "REACH THRESHOLD AT \(Int(thresholdCrossingHt)) FT AGL",
                sublabel: "Arrives at threshold with margin to flare and land.",
                altOpt: fullAlt,
                failureAlt: failureAlt,
                canMakeIt: fullOk,
                color: color
            )

            // GO / NO GO
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ENGINE FAILURE AT \(Int(failureAlt)) FT AGL")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color.white)
                    if let minAlt = fullAlt {
                        let delta = failureAlt - minAlt
                        Text(fullOk
                             ? "+\(Int(delta)) ft above minimum"
                             : "\(Int(abs(delta))) ft below minimum")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(fullOk ? .green : .red)
                    }
                }
                Spacer()
                goNoGoBox(ok: fullOk)
                    .frame(width: 100)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(fullOk ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(fullOk ? Color.green.opacity(0.35) : Color.red.opacity(0.35), lineWidth: 1))
            )
        })
    }

    func glideDistLine(label: String, value: Double, ok: Bool, color: Color) -> some View {
        GlideDistLine(label: label, value: value, ok: ok, color: color)
    }

    func goNoGoBox(ok: Bool) -> some View {
        GoNoGoBox(ok: ok)
    }

    func altRow(rowLabel: String, sublabel: String, altOpt: Double?, failureAlt: Double, canMakeIt: Bool, color: Color) -> some View {
        return AnyView(VStack(alignment: .leading, spacing: 8) {
            // Labels + minimum altitude
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(rowLabel)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(sublabel)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Color.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if let alt = altOpt {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int((alt + airportElevFt).rounded())) ft MSL")
                            .font(.system(size: 30, weight: .heavy, design: .monospaced))
                            .foregroundColor(canMakeIt ? color : .red)
                        Text("\(Int(alt.rounded())) ft AGL")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(canMakeIt ? color.opacity(0.75) : .red.opacity(0.75))
                        Text(canMakeIt ? "✓ POSSIBLE" : "✗ NOT POSSIBLE")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(canMakeIt ? .green : .red)
                    }
                } else {
                    Text(">6,000 ft AGL")
                        .font(.system(size: 30, weight: .heavy, design: .monospaced))
                        .foregroundColor(.red)
                }
            }

            // Pilot performance correction
            if let alt = altOpt {
                let corrAGL = alt * (1 + pilotCorrectionPct / 100)
                let corrMSL = corrAGL + airportElevFt
                Divider().background(Color(white: 0.18))
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PILOT CORRECTION: \(Int(pilotCorrectionPct))%")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.orange)
                        Text("Adds margin for imperfect execution")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.6))
                        Slider(value: $pilotCorrectionPct, in: 0...100, step: 5)
                            .tint(.orange)
                            .frame(maxWidth: 200)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(corrMSL.rounded())) ft MSL")
                            .font(.system(size: 30, weight: .heavy, design: .monospaced))
                            .foregroundColor(.orange)
                        Text("\(Int(corrAGL.rounded())) ft AGL")
                            .font(.system(size: 18, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.orange.opacity(0.75))
                        Text("WITH CORRECTION")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(canMakeIt ? Color(white: 0.04) : Color.red.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(canMakeIt ? Color(white: 0.10) : Color.red.opacity(0.25), lineWidth: 1))
        ))
    }

    var returnPhaseBreakdown: some View {
        let turnTimeSec = turnRateDegPerSec > 0 ? 180.0 / turnRateDegPerSec : 0
        let altLostTurn = rateOfDescentFpm * turnTimeSec / 60.0
        let vNMperSec = glide / 3600.0
        let turnRadiusNM = turnRateDegPerSec > 0 ? vNMperSec / (turnRateDegPerSec * .pi / 180.0) : 0
        let turnRadiusFt = turnRadiusNM * 6076.12
        let refAlt = minReturnAltNoWind ?? 0
        let altAfterRx = refAlt - altLostReaction
        let altAfterTurn = max(0, altAfterRx - altLostTurn)

        return VStack(alignment: .leading, spacing: 8) {
            Text("HOW THE ALTITUDE IS CONSUMED")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.2)

            Text("Altitudes shown as MSL / AGL (height above airport at \(Int(airportElevFt)) ft MSL).")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color.white)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                phaseRow(
                    number: "1",
                    title: "Engine failure",
                    detail: "Aircraft is at minimum return altitude AGL",
                    altLabel: "\(Int(refAlt)) ft AGL",
                    lostLabel: "",
                    color: ac.accentColor
                )
                phaseDivider()
                phaseRow(
                    number: "2",
                    title: "Reaction phase (\(String(format: "%.1f", reactionTimeSec))s)",
                    detail: "Flying at Vy (\(Int(climbSpeedKtsNorm)) kts). Covers \(String(format: "%.2f", distCoveredReactionNM(headwindKts: windKts))) NM during reaction. Was \(String(format: "%.2f", distFromRunwayAtAlt(altFt: minReturnAltNoWind ?? engineFailureAlt, headwindKts: windKts))) NM past departure end of runway at failure.",
                    altLabel: "\(Int(altAfterRx)) ft AGL after",
                    lostLabel: "-\(Int(altLostReaction.rounded())) ft",
                    color: .orange
                )
                phaseDivider()
                phaseRow(
                    number: "3",
                    title: "180° glide turn (\(String(format: "%.0f", turnTimeSec))s)",
                    detail: "Turning back at \(Int(bankDeg))° bank. Turn radius \(Int(turnRadiusFt.rounded())) ft. Aircraft is now offset from runway.",
                    altLabel: "\(Int(altAfterTurn)) ft AGL after",
                    lostLabel: "-\(Int(altLostTurn.rounded())) ft",
                    color: .orange
                )
                phaseDivider()
                phaseRow(
                    number: "4",
                    title: "Glide back to threshold",
                    detail: "Must cover lateral offset + runway distance while descending from \(Int(altAfterTurn)) ft to \(Int(thresholdCrossingHt)) ft AGL.",
                    altLabel: "\(Int(thresholdCrossingHt)) ft AGL at threshold",
                    lostLabel: "",
                    color: .green
                )
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.04))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.10), lineWidth: 1))
            )
        }
    }

    func phaseDivider() -> some View {
        HStack {
            Text("↓")
                .font(.system(size: 16, design: .monospaced))
                .foregroundColor(Color.white)
                .padding(.leading, 6)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    func phaseRow(number: String, title: String, detail: String, altLabel: String, lostLabel: String, color: Color) -> some View {
        return AnyView(HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white)
                Text(detail)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Color.white)
                    .fixedSize(horizontal: false, vertical: true)
                if !altLabel.isEmpty {
                    Text(altLabel)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(color)
                }
            }
            Spacer()
            if !lostLabel.isEmpty {
                Text(lostLabel)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.red.opacity(0.85))
            }
        }
        .padding(.vertical, 6))
    }


    // MARK: Formula

    var formulaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("METHOD")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.5)
            Text("GLIDE:  Vg = Vref × √(W / Wref)")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
            Text("= \(Int(ac.refGlideSpeed)) kts × √(\(Int(weight)) / \(Int(ac.refWeight))) = \(Int(glide.rounded())) kts / \(Int(glideMph.rounded())) mph")
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(ac.accentColor)
            Text(ac.isUserDefined
                 ? "STALL:  Vs₀ × √(1/cos(bank)) · load factor formula"
                 : "STALL:  Interpolated from POH · load factor = 1/cos(bank)")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color.white)
                .padding(.top, 2)
        }
        .padding(14)
        .background(CardBG())
    }

    // MARK: Needle Animation

    func animateNeedle() {
        let target = glide
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let diff = target - self.displayed
            if abs(diff) < 0.1 {
                self.displayed = target
                timer.invalidate()
            } else {
                self.displayed += diff * 0.12
            }
        }
    }
}

#Preview {
    ContentView(aircraft: builtInAircraft[0], onChangeAircraft: {})
}
