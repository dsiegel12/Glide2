import SwiftUI

// MARK: - ContentView

struct ContentView: View {
    let aircraft: Aircraft
    let onChangeAircraft: () -> Void

    @State private var weight = 2500.0
    @State private var altFt = 3000.0
    @State private var displayed = 76.0
    @State private var bankDeg = 0.0
    @State private var reactionTimeSec = 3.0
    @State private var runwayLengthFt = 3000.0
    @State private var windKts = 0.0          // positive = headwind on departure
    @State private var thresholdCrossingHt = 25.0   // ft AGL at runway threshold
    @State private var engineFailureAlt = 500.0         // ft AGL at engine failure
    @State private var groundRollFt = 800.0              // ft of ground roll before liftoff
    @State private var climbRateFpm = 700.0              // fpm climb rate after liftoff
    @State private var climbSpeedKts = 73.0              // Vy in kts
    @State private var climbSpeedUnit = 0                // 0 = kts, 1 = mph

    var ac: Aircraft { aircraft }
    var glide: Double { ac.bestGlide(weight: weight) }
    var glideMph: Double { ac.bestGlideMph(weight: weight) }
    var distNM: Double { ac.glideDistance(weight: weight, altFt: altFt) }
    var stall: (kts: Double, mph: Double) { ac.stallSpeed(bankDeg: bankDeg, weight: weight) }

    // ── Impossible Turn / Minimum Return Altitude ────────────────────────────

    var altLostReaction: Double {
        return 200.0 * reactionTimeSec / 60.0
    }

    var climbSpeedKtsNorm: Double {
        climbSpeedUnit == 1 ? climbSpeedKts / 1.15078 : climbSpeedKts
    }

    func distFromRunwayAtAlt(altFt: Double, headwindKts: Double) -> Double {
        let climbGroundSpeedKts = max(climbSpeedKtsNorm - headwindKts, 1.0)
        let climbGradientFtPerNM = max(climbRateFpm, 1.0) / climbGroundSpeedKts * 6076.12 / 60.0
        guard climbGradientFtPerNM > 0 else { return 0 }
        return altFt / climbGradientFtPerNM
    }

    func distBackNM(headwindKts: Double, turnDeg: Double) -> Double {
        return glideDistNeededNM(headwindKts: headwindKts, failureAlt: 0, turnDeg: turnDeg)
    }

    func distCoveredReactionNM(headwindKts: Double) -> Double {
        let groundSpeedKts = max(climbSpeedKtsNorm - headwindKts, 1.0)
        return groundSpeedKts * (reactionTimeSec / 3600.0)
    }

    func glideDistNeededNM(headwindKts: Double, failureAlt: Double, turnDeg: Double = 180.0) -> Double {
        guard turnRateDegPerSec > 1.0 else { return 999.0 }
        let distOut    = distFromRunwayAtAlt(altFt: failureAlt, headwindKts: headwindKts)
        let rxnDist    = distCoveredReactionNM(headwindKts: headwindKts)
        let halfRwyNM  = runwayLengthFt / 2.0 / 6076.12
        let vNMperSec  = glide / 3600.0
        let rAero      = vNMperSec / (turnRateDegPerSec * .pi / 180.0)
        let gsTurn     = max(glide - headwindKts, 1.0)
        let rGnd       = rAero * (gsTurn / glide)
        let longit     = distOut + rxnDist + halfRwyNM

        let lateral = 2.0 * rGnd
        return (longit * longit + lateral * lateral).squareRoot()
    }

    func lateralOffsetNM(headwindKts: Double, failureAlt: Double, turnDeg: Double = 180.0) -> Double {
        return glideDistNeededNM(headwindKts: headwindKts, failureAlt: failureAlt, turnDeg: turnDeg)
            - runwayLengthFt / 2.0 / 6076.12
    }

    func glideDistReturnNM(altitudeFt: Double, headwindKts: Double) -> Double {
        let tailwindKts = headwindKts
        let groundSpeedReturn = glide + tailwindKts
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

    var canReturnGeoNoWind: Bool   { canReturn(failureAlt: engineFailureAlt, headwindKts: 0,        threshold: 0,                  turnDeg: 180) }
    var canReturnGeoWithWind: Bool { canReturn(failureAlt: engineFailureAlt, headwindKts: windKts,  threshold: 0,                  turnDeg: 180) }
    var canReturnFullNoWind: Bool  { canReturn(failureAlt: engineFailureAlt, headwindKts: 0,        threshold: thresholdCrossingHt, turnDeg: 180) }
    var canReturnFullWithWind: Bool{ canReturn(failureAlt: engineFailureAlt, headwindKts: windKts,  threshold: thresholdCrossingHt, turnDeg: 180) }


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
        let speedFps = glide * 6076.12 / 3600.0
        return speedFps * 60.0 / ac.glideRatio
    }

    var turnRateDegPerSec: Double {
        guard bankDeg > 5 else { return 0.0 }
        let vFps = glide * 6076.12 / 3600.0
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    gaugeSection
                    weightSection
                    altSection
                    distSection
                    stallSection
                    turnSection
                    returnSection
                    formulaSection
                    Text("FOR SIMULATION & TRAINING ONLY · VERIFY WITH POH")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundColor(Color.white)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
            }
            .background(Color(red: 0.055, green: 0.068, blue: 0.085).ignoresSafeArea())
            .navigationTitle("Best Glide Calculator")
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
            weight = ((ac.minWeight + ac.mtow) / 2 / 50).rounded() * 50
            displayed = glide
        }
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
        VStack(alignment: .leading, spacing: 12) {
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
        .background(CardBG(accent: ac.accentColor.opacity(0.18)))
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
            .font(.system(size: 14, design: .monospaced))
            .foregroundColor(Color.white)
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
        VStack(alignment: .leading, spacing: 12) {
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
        .background(CardBG(accent: ac.accentColor.opacity(0.18)))
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


    // MARK: Minimum Return Altitude

    var returnSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("MINIMUM RETURN ALTITUDE")
                .font(.system(size: 22, weight: .heavy, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.2)
            Text("ENGINE FAILURE ON DEPARTURE — 180° TURN BACK TO AIRPORT")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(ac.accentColor)
                .fixedSize(horizontal: false, vertical: true)
            Text("The minimum height AGL above the airport at which engine failure occurs and a successful return to the runway is still possible.")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color.white)
                .fixedSize(horizontal: false, vertical: true)
            returnInputsCard
            returnFailureAltCard
            returnResultsCard
            returnPhaseBreakdown
            if bankDeg < 5 {
                Text("⚠ SET A BANK ANGLE IN THE STALL SECTION ABOVE TO COMPUTE TURN PERFORMANCE")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(CardBG(accent: ac.accentColor.opacity(0.18)))
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
                        Picker("", selection: $climbSpeedUnit) {
                            Text("KTS").tag(0)
                            Text("MPH").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 90)
                    }
                    HStack {
                        Spacer()
                        Text(climbSpeedUnit == 0
                             ? "\(Int(climbSpeedKts)) kts"
                             : "\(Int(climbSpeedKts)) mph")
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(ac.accentColor)
                    }
                    Slider(value: $climbSpeedKts, in: 50...150, step: 1).tint(ac.accentColor)
                    sliderEndLabels(
                        climbSpeedUnit == 0 ? "50 kts" : "50 mph",
                        climbSpeedUnit == 0 ? "150 kts" : "150 mph"
                    )
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
                sublabel: "Your actual AGL height above the airport when the engine fails",
                value: "\(Int(engineFailureAlt)) ft AGL"
            )
            Slider(value: $engineFailureAlt, in: 100...6000, step: 100).tint(ac.accentColor)
            sliderEndLabels("100 ft AGL", "6,000 ft AGL")
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.05))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.12), lineWidth: 1))
        )
    }

    @ViewBuilder var returnResultsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RESULTS — MINIMUM ENGINE FAILURE ALTITUDE AGL")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.5)
                .fixedSize(horizontal: false, vertical: true)

                turnStrategyBlock(
                    windLabel: "NO WIND",
                    geoAlt: minReturnAltGeoNoWind,
                    fullAlt: minReturnAltNoWind,
                    failureAlt: engineFailureAlt,
                    color: ac.accentColor,
                    isWind: false
                )

                if windKts > 0 {
                    Divider().background(Color.white)
                    turnStrategyBlock(
                        windLabel: "\(Int(windKts)) KTS HEADWIND ON DEPARTURE",
                        geoAlt: minReturnAltGeoWithWind,
                        fullAlt: minReturnAltWithWind,
                        failureAlt: engineFailureAlt,
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
            )
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

        return VStack(alignment: .leading, spacing: 12) {
            Text(windLabel)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .kerning(1.0)

            let hw           = isWind ? windKts : 0.0
            let distFromEnd  = distFromRunwayAtAlt(altFt: failureAlt, headwindKts: hw)
            let distBack     = glideDistNeededNM(headwindKts: hw, failureAlt: failureAlt, turnDeg: 180)
            let altLostRx    = altLostReaction
            let altLost180   = rateOfDescentFpm * (180.0 / max(turnRateDegPerSec, 0.01)) / 60.0
            let gsReturn     = glide + hw
            let effRatio     = ac.glideRatio * (gsReturn / glide)
            let glideAvail   = max(0, failureAlt - altLostRx - altLost180) * effRatio / 6076.12

            // Distances card
            VStack(alignment: .leading, spacing: 8) {
                Text("DISTANCES AT ENGINE FAILURE (\(Int(failureAlt)) FT AGL)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white)
                    .kerning(1.0)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("OUT — PAST DEPARTURE END OF RUNWAY")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white)
                            .kerning(0.8)
                        Text("Climb distance from liftoff to engine failure. Ground roll occurs behind the departure end.")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.white)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.2f NM", distFromEnd))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(ac.accentColor)
                        Text("\(Int((distFromEnd * 6076.12).rounded())) ft")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(Color.white)
                    }
                }

                Divider().background(Color(white: 0.15))

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BACK — GLIDE DISTANCE TO THRESHOLD (180° TURN)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.white)
                            .kerning(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("= √((2r)²+(out+rxn+½rwy)²)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(Color.white)
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
        }
    }

    func glideDistLine(label: String, value: Double, ok: Bool, color: Color) -> some View {
        GlideDistLine(label: label, value: value, ok: ok, color: color)
    }

    func goNoGoBox(ok: Bool) -> some View {
        GoNoGoBox(ok: ok)
    }

    func altRow(rowLabel: String, sublabel: String, altOpt: Double?, failureAlt: Double, canMakeIt: Bool, color: Color) -> some View {
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
                VStack(alignment: .trailing, spacing: 2) {
                    Text("MIN: \(Int(alt.rounded())) ft AGL")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(canMakeIt ? color : .red)
                    Text(canMakeIt ? "✓ POSSIBLE" : "✗ NOT POSSIBLE")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(canMakeIt ? .green : .red)
                }
            } else {
                Text("MIN: >6,000 ft")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.red)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(canMakeIt ? Color(white: 0.04) : Color.red.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 7)
                    .stroke(canMakeIt ? Color(white: 0.10) : Color.red.opacity(0.25), lineWidth: 1))
        )
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

            Text("All altitudes are AGL — height above the airport surface.")
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
        HStack(alignment: .top, spacing: 10) {
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
        .padding(.vertical, 6)
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
