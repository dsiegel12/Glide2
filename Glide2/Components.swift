import SwiftUI

// MARK: - Gauge View

struct GaugeView: View {
    let value: Double
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let r = min(cx, cy) * 0.88
            let minV: Double = 40
            let maxV: Double = 110

            func angleFor(_ v: Double) -> Double {
                let pct = max(0, min(1, (v - minV) / (maxV - minV)))
                return -220 + pct * 260
            }

            let bgRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            let bgPath = Path(ellipseIn: bgRect)
            ctx.fill(bgPath, with: .color(Color(white: 0.10)))
            ctx.stroke(bgPath, with: .color(Color.white), lineWidth: 2)

            var trackPath = Path()
            trackPath.addArc(center: CGPoint(x: cx, y: cy), radius: r * 0.78,
                startAngle: .degrees(-220 - 90), endAngle: .degrees(40 - 90), clockwise: false)
            ctx.stroke(trackPath, with: .color(Color.white),
                       style: StrokeStyle(lineWidth: r * 0.13, lineCap: .round))

            var valuePath = Path()
            valuePath.addArc(center: CGPoint(x: cx, y: cy), radius: r * 0.78,
                startAngle: .degrees(-220 - 90), endAngle: .degrees(angleFor(value) - 90), clockwise: false)
            ctx.stroke(valuePath, with: .color(color.opacity(0.9)),
                       style: StrokeStyle(lineWidth: r * 0.13, lineCap: .round))

            for i in 0...20 {
                let v = minV + Double(i) / 20.0 * (maxV - minV)
                let rad = (angleFor(v) - 90) * Double.pi / 180
                let isMajor = i % 4 == 0
                let innerR = isMajor ? r * 0.60 : r * 0.68
                var tick = Path()
                tick.move(to: CGPoint(x: cx + cos(rad) * innerR, y: cy + sin(rad) * innerR))
                tick.addLine(to: CGPoint(x: cx + cos(rad) * r * 0.74, y: cy + sin(rad) * r * 0.74))
                ctx.stroke(tick, with: .color(isMajor ? Color(white: 0.6) : Color.white),
                           lineWidth: isMajor ? 2 : 1)
            }

            let nRad = (angleFor(value) - 90) * Double.pi / 180
            let tipX = cx + cos(nRad) * r * 0.62
            let tipY = cy + sin(nRad) * r * 0.62
            let tailX = cx - cos(nRad) * r * 0.14
            let tailY = cy - sin(nRad) * r * 0.14
            let px = cos(nRad + Double.pi / 2) * 3.5
            let py = sin(nRad + Double.pi / 2) * 3.5
            var needle = Path()
            needle.move(to: CGPoint(x: tipX, y: tipY))
            needle.addLine(to: CGPoint(x: cx + px, y: cy + py))
            needle.addLine(to: CGPoint(x: tailX, y: tailY))
            needle.addLine(to: CGPoint(x: cx - px, y: cy - py))
            needle.closeSubpath()
            ctx.fill(needle, with: .color(color))

            let capR = r * 0.085
            let capPath = Path(ellipseIn: CGRect(x: cx - capR, y: cy - capR, width: capR * 2, height: capR * 2))
            ctx.fill(capPath, with: .color(Color(white: 0.5)))
        }
    }
}

// MARK: - Bank Angle Diagram

struct BankDiagram: View {
    let bankDeg: Double
    let color: Color

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width / 2
            let cy = size.height / 2
            let span = min(size.width, size.height) * 0.38

            var horizon = Path()
            horizon.move(to: CGPoint(x: 0, y: cy))
            horizon.addLine(to: CGPoint(x: size.width, y: cy))
            ctx.stroke(horizon, with: .color(Color.white), lineWidth: 1)

            for deg in [20.0, 40.0, 60.0] {
                for sign in [-1.0, 1.0] {
                    let angle = sign * deg * Double.pi / 180
                    var mark = Path()
                    mark.move(to: CGPoint(x: cx + cos(angle - .pi/2) * span * 0.85,
                                         y: cy + sin(angle - .pi/2) * span * 0.85))
                    mark.addLine(to: CGPoint(x: cx + cos(angle - .pi/2) * span * 0.95,
                                            y: cy + sin(angle - .pi/2) * span * 0.95))
                    ctx.stroke(mark, with: .color(Color.white), lineWidth: 1)
                }
            }

            let bankRad = bankDeg * Double.pi / 180
            let wingLen = span * 0.75
            let fuseLen = span * 0.22

            var leftWing = Path()
            leftWing.move(to: CGPoint(x: cx, y: cy))
            leftWing.addLine(to: CGPoint(
                x: cx - cos(bankRad) * wingLen,
                y: cy - sin(bankRad) * wingLen))
            ctx.stroke(leftWing, with: .color(color), lineWidth: 3)

            var rightWing = Path()
            rightWing.move(to: CGPoint(x: cx, y: cy))
            rightWing.addLine(to: CGPoint(
                x: cx + cos(bankRad) * wingLen,
                y: cy + sin(bankRad) * wingLen))
            ctx.stroke(rightWing, with: .color(color), lineWidth: 3)

            var fuse = Path()
            fuse.move(to: CGPoint(
                x: cx + sin(bankRad) * fuseLen,
                y: cy - cos(bankRad) * fuseLen))
            fuse.addLine(to: CGPoint(
                x: cx - sin(bankRad) * fuseLen * 0.4,
                y: cy + cos(bankRad) * fuseLen * 0.4))
            ctx.stroke(fuse, with: .color(color.opacity(0.7)), lineWidth: 2)

            let dot = Path(ellipseIn: CGRect(x: cx - 4, y: cy - 4, width: 8, height: 8))
            ctx.fill(dot, with: .color(color))

            var arc = Path()
            arc.addArc(center: CGPoint(x: cx, y: cy), radius: span * 0.45,
                startAngle: .degrees(-90), endAngle: .degrees(-90 + bankDeg), clockwise: false)
            ctx.stroke(arc, with: .color(color.opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
    }
}

// MARK: - Reusable Card Background

struct CardBG: View {
    var accent: Color = Color(white: 0.12)
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color(white: 0.07))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(accent, lineWidth: 1))
    }
}

// MARK: - Speed Pair View

struct SpeedPair: View {
    let kts: Double
    let mph: Double
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
                .kerning(1.2)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(Int(kts.rounded()))")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                Text("KTS")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundColor(color.opacity(0.6))
                    .padding(.bottom, 3)
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(Int(mph.rounded()))")
                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                    .foregroundColor(color.opacity(0.75))
                Text("MPH")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(color.opacity(0.45))
                    .padding(.bottom, 2)
            }
        }
    }
}

// MARK: - Distance Tile

struct DistTile: View {
    let value: String
    let unit: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(Color(red: 0.48, green: 0.71, blue: 0.88))
            Text(unit)
                .font(.system(size: 15, design: .monospaced))
                .foregroundColor(Color.white)
            Text(label)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(Color.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color(white: 0.06))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(white: 0.13), lineWidth: 1))
        )
    }
}


// MARK: - Standalone View Structs (prevent Swift type metadata recursion)

struct GlideDistLine: View {
    let label: String
    let value: Double
    let ok: Bool
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.white)
            Text("\(Int((value * 6076.12).rounded())) ft")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(label == "GLIDE AVAIL" ? (ok ? color : .red) : Color.white)
        }
    }
}

struct GoNoGoBox: View {
    let ok: Bool
    var body: some View {
        Text(ok ? "GO" : "NO GO")
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundColor(ok ? .green : .red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(ok ? Color.green.opacity(0.10) : Color.red.opacity(0.10))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(ok ? Color.green.opacity(0.4) : Color.red.opacity(0.4), lineWidth: 1)))
    }
}

struct CompareRow: View {
    let label: String
    let alt180: Double?
    let alt270: Double?
    let ok180: Bool
    let ok270: Bool
    let glideAvail180: Double
    let glideAvail270: Double
    let glideReq180: Double
    let glideReq270: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                turnCol(title: "180° TURN", altOpt: alt180, ok: ok180,
                        avail: glideAvail180, req: glideReq180)
                turnCol(title: "270° TURN", altOpt: alt270, ok: ok270,
                        avail: glideAvail270, req: glideReq270)
            }
        }
    }

    private func turnCol(title: String, altOpt: Double?, ok: Bool,
                         avail: Double, req: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white)
            Text("MIN ALT NEEDED")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Color.white)
            Text(altOpt.map { "\(Int($0)) ft AGL" } ?? "> 6,000 ft")
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(ok ? color : .red)
            Divider().background(Color(white: 0.20))
            GlideDistLine(label: "GLIDE AVAIL", value: avail, ok: ok, color: color)
            GlideDistLine(label: "GLIDE REQD",  value: req,   ok: ok, color: color)
            Text(ok ? "✓ POSSIBLE" : "✗ NOT POSSIBLE")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(ok ? .green : .red)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 6)
            .fill(ok ? Color(white: 0.05) : Color.red.opacity(0.06))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .stroke(ok ? Color(white: 0.10) : Color.red.opacity(0.25), lineWidth: 1)))
    }
}
