import SwiftUI

enum PlanMode { case top, front, side }

/// Převod mezi souřadnicemi plánu a obrazovkou pro 2D pohledy (shora / zepředu / z boku).
struct Projector {
    let mode: PlanMode
    let scale: CGFloat
    let ox: CGFloat
    let oy: CGFloat   // top: y pro y=0; elevace: y pro z=0

    init(mode: PlanMode, room: Room, size: CGSize, zoom: CGFloat = 1, pan: CGSize = .zero) {
        self.mode = mode
        let w = CGFloat(room.w), d = CGFloat(room.d), h = CGFloat(room.h)
        let base: CGFloat, bx: CGFloat, by: CGFloat
        if mode == .top {
            let m: CGFloat = 1.3
            base = min((size.width - 24) / (w + 2 * m), (size.height - 30) / (d + 2 * m))
            bx = (size.width - w * base) / 2
            by = (size.height - d * base) / 2
        } else {
            let ext = mode == .front ? w : d
            let l: CGFloat = 36, r: CGFloat = 14, t: CGFloat = 14, b: CGFloat = 30
            base = min((size.width - l - r) / ext, (size.height - t - b) / h)
            bx = l + ((size.width - l - r) - ext * base) / 2
            by = t + ((size.height - t - b) - h * base) / 2 + h * base
        }
        // přiblížení kolem středu plátna + posun (pinch / tažení prázdné plochy)
        let cx = size.width / 2, cy = size.height / 2
        scale = base * zoom
        ox = cx + (bx - cx) * zoom + pan.width
        oy = cy + (by - cy) * zoom + pan.height
    }

    func point(_ p: V3) -> CGPoint {
        switch mode {
        case .top: return CGPoint(x: ox + CGFloat(p.x) * scale, y: oy + CGFloat(p.y) * scale)
        case .front: return CGPoint(x: ox + CGFloat(p.x) * scale, y: oy - CGFloat(p.z) * scale)
        case .side: return CGPoint(x: ox + CGFloat(p.y) * scale, y: oy - CGFloat(p.z) * scale)
        }
    }
    /// Vodorovná souřadnice (elevace) / x,y (shora).
    func horizontal(_ p: V3) -> Double { mode == .front ? p.x : p.y }
    func elev(_ h: Double, _ z: Double) -> CGPoint {
        CGPoint(x: ox + CGFloat(h) * scale, y: oy - CGFloat(z) * scale)
    }
    /// Zpět na plán: top → (x, y), elevace → (h, z).
    func unproject(_ p: CGPoint) -> (Double, Double) {
        if mode == .top { return (Double((p.x - ox) / scale), Double((p.y - oy) / scale)) }
        return (Double((p.x - ox) / scale), Double((oy - p.y) / scale))
    }
}

func convexHull(_ pts: [CGPoint]) -> [CGPoint] {
    let p = pts.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
    if p.count < 3 { return p }
    func cr(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
    var lo: [CGPoint] = [], up: [CGPoint] = []
    for q in p {
        while lo.count >= 2 && cr(lo[lo.count - 2], lo[lo.count - 1], q) <= 0 { lo.removeLast() }
        lo.append(q)
    }
    for q in p.reversed() {
        while up.count >= 2 && cr(up[up.count - 2], up[up.count - 1], q) <= 0 { up.removeLast() }
        up.append(q)
    }
    up.removeLast(); lo.removeLast()
    return lo + up
}

// MARK: - Vykreslení

struct PlanRenderer {
    let plan: Plan
    let geo: [LightGeometry]
    let analysis: AnalysisResult
    let selection: Selection?
    let showCones: Bool
    let showHeat: Bool
    let pr: Projector

    private var hazeK: Double { plan.hazeOn ? 1 + 1.1 * plan.hazeDensity : 1 }

    func draw(_ c: inout GraphicsContext) {
        c.fill(Path(CGRect(x: -10, y: -10, width: 5000, height: 5000)), with: .color(Color(white: 0.04)))
        if pr.mode == .top { drawTop(&c) } else { drawElevation(&c) }
    }

    // MARK: Společné

    private func label(_ c: inout GraphicsContext, _ s: String, _ p: CGPoint, color: Color = .gray, size: CGFloat = 10, anchor: UnitPoint = .leading) {
        c.draw(Text(s).font(.system(size: size)).foregroundColor(color), at: p, anchor: anchor)
    }

    private func path(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.addLines(pts)
        p.closeSubpath()
        return p
    }

    private func coneFill(_ c: inout GraphicsContext, _ pts: [CGPoint], apex: CGPoint, end: CGPoint, _ g: LightGeometry) {
        guard pts.count >= 3 else { return }
        let base = 0.035 + 0.09 * g.light.intensity / 100
        let col = g.color.color
        let a0 = min(0.3, base * hazeK * 1.3), a1 = min(0.2, base * hazeK * 0.45)
        let p = path(pts)
        let shading: GraphicsContext.Shading = hypot(end.x - apex.x, end.y - apex.y) > 2
            ? .linearGradient(Gradient(colors: [col.opacity(a0), col.opacity(a1)]), startPoint: apex, endPoint: end)
            : .color(col.opacity(base * hazeK))
        c.fill(p, with: shading)
        c.stroke(p, with: .color(col.opacity(0.35)), lineWidth: 1)
    }

    private func fixtureIcon(_ c: inout GraphicsContext, _ at: CGPoint, _ g: LightGeometry) {
        let selected = selection == .light(g.light.id)
        let circle = Path(ellipseIn: CGRect(x: at.x - 8, y: at.y - 8, width: 16, height: 16))
        c.fill(circle, with: .color(g.color.color))
        c.stroke(circle, with: .color(selected ? .white : .black.opacity(0.6)), lineWidth: selected ? 3 : 1.5)
        if let fl = analysis.flags[g.light.id], !fl.isEmpty {
            let ring = Path(ellipseIn: CGRect(x: at.x - 12, y: at.y - 12, width: 24, height: 24))
            c.stroke(ring, with: .color(fl.contains(.glare) || fl.contains(.burn) ? .red : .yellow), lineWidth: 2)
        }
        label(&c, "\(g.light.number)", at, color: .black, size: 9, anchor: .center)
    }

    private func isOutlined(_ o: StageObject) -> Bool { selection == .object(o.id) }

    // MARK: Pohled shora

    private func drawTop(_ c: inout GraphicsContext) {
        let r = plan.room, st = plan.stage, s = pr.scale
        let P = { (x: Double, y: Double) in pr.point(V3(x, y, 0)) }
        let origin = P(0, 0)
        let roomRect = CGRect(x: origin.x, y: origin.y, width: CGFloat(r.w) * s, height: CGFloat(r.d) * s)
        c.fill(Path(roomRect), with: .color(Color(white: 0.07)))

        var grid = Path()
        for x in stride(from: 1.0, to: r.w, by: 1) { grid.move(to: P(x, 0)); grid.addLine(to: P(x, r.d)) }
        for y in stride(from: 1.0, to: r.d, by: 1) { grid.move(to: P(0, y)); grid.addLine(to: P(r.w, y)) }
        c.stroke(grid, with: .color(.white.opacity(0.05)), lineWidth: 1)

        // publikum
        let ay0 = st.y + st.d + 0.8, ay1 = r.d - 0.3
        if ay0 < ay1 {
            let a = P(0.4, ay0), b = P(r.w - 0.4, ay1)
            let rect = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
            c.fill(Path(rect), with: .color(.red.opacity(0.06)))
            c.stroke(Path(rect), with: .color(.red.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            label(&c, "PUBLIKUM (zóna oslnění)", CGPoint(x: a.x + 6, y: a.y + 12), color: .red.opacity(0.8))
        }

        // pódium
        let sa = P(st.x - st.w / 2, st.y), sb = P(st.x + st.w / 2, st.y + st.d)
        let stageRect = CGRect(x: sa.x, y: sa.y, width: sb.x - sa.x, height: sb.y - sa.y)
        c.fill(Path(stageRect), with: .color(Color(white: 0.14)))
        c.stroke(Path(stageRect), with: .color(Color(white: 0.4)), lineWidth: 1.5)
        label(&c, "PÓDIUM \(fmt(st.w)) × \(fmt(st.d)) m · výška \(fmt(st.h)) m", CGPoint(x: sa.x + 6, y: sa.y + 12), color: Color(white: 0.65))

        // truss
        for (y, name) in [(plan.trussFrontY, "přední"), (plan.trussBackY, "zadní")] {
            var t = Path()
            t.move(to: P(st.x - st.w / 2 - 0.4, y)); t.addLine(to: P(st.x + st.w / 2 + 0.4, y))
            c.stroke(t, with: .color(Color(white: 0.6)), style: StrokeStyle(lineWidth: 2, dash: [7, 4]))
            label(&c, "\(name) truss \(fmt(plan.truss.h)) m", CGPoint(x: P(st.x + st.w / 2 + 0.5, y).x, y: P(0, y).y), size: 9)
        }

        // dveře a okna
        for o in plan.openings {
            let a: CGPoint, b: CGPoint, e = o.pos + o.w
            switch o.wall {
            case .back: a = P(o.pos, 0); b = P(e, 0)
            case .front: a = P(o.pos, r.d); b = P(e, r.d)
            case .left: a = P(0, o.pos); b = P(0, e)
            case .right: a = P(r.w, o.pos); b = P(r.w, e)
            }
            var p = Path(); p.move(to: a); p.addLine(to: b)
            c.stroke(p, with: .color(o.type == .door ? Color(red: 0.85, green: 0.6, blue: 0.32) : Color(red: 0.35, green: 0.66, blue: 1)), lineWidth: 6)
        }
        c.stroke(Path(roomRect), with: .color(Color(white: 0.4)), lineWidth: 2)
        label(&c, "\(fmt(r.w)) m", CGPoint(x: roomRect.midX, y: roomRect.minY - 8), anchor: .center)
        label(&c, "\(fmt(r.d)) m", CGPoint(x: roomRect.minX - 6, y: roomRect.midY), anchor: .trailing)
        label(&c, "POZADÍ (zadní stěna)", CGPoint(x: roomRect.midX, y: roomRect.minY + 10), color: Color(white: 0.4), anchor: .center)

        // heatmapa osvětlenosti
        if showHeat {
            let cell = 0.5
            for x in stride(from: 0.0, to: r.w, by: cell) {
                for y in stride(from: 0.0, to: r.d, by: cell) {
                    let p = V3(x + cell / 2, y + cell / 2, plan.surfaceZ(x: x + cell / 2, y: y + cell / 2))
                    let e = geo.reduce(0) { $0 + $1.illuminance(at: p, normal: V3(0, 0, 1)) }
                    if e < 1 { continue }
                    let t = clamp(log10(1 + e) / log10(3500), 0, 1)
                    let a = P(x, y)
                    c.fill(Path(CGRect(x: a.x, y: a.y, width: CGFloat(cell) * s + 0.6, height: CGFloat(cell) * s + 0.6)),
                           with: .color(Color(hue: (1 - t) * 0.66, saturation: 0.9, brightness: 0.35 + t * 0.6).opacity(0.75)))
                }
            }
        }

        // objekty
        for o in plan.objects {
            let p = P(o.x, o.y)
            let base = plan.surfaceZ(x: o.x, y: o.y) + o.lift
            let lit = shade(o.color, V3(o.x, o.y, base + o.h), V3(0, 0, 1))
            let shape: Path = o.kind == .box
                ? Path(CGRect(x: p.x - CGFloat(o.w) * s / 2, y: p.y - CGFloat(o.d) * s / 2, width: CGFloat(o.w) * s, height: CGFloat(o.d) * s))
                : Path(ellipseIn: CGRect(x: p.x - max(3, CGFloat(o.r) * s), y: p.y - max(3, CGFloat(o.r) * s), width: 2 * max(3, CGFloat(o.r) * s), height: 2 * max(3, CGFloat(o.r) * s)))
            c.fill(shape, with: .color(lit))
            c.stroke(shape, with: .color(isOutlined(o) ? .white : Color(white: 0.65)), lineWidth: isOutlined(o) ? 2.5 : 1)
            label(&c, o.name, CGPoint(x: p.x, y: p.y + (o.kind == .box ? CGFloat(o.d) * s / 2 : CGFloat(o.r) * s) + 10), size: 9, anchor: .center)
        }

        // kužely a stopy (aditivně)
        c.blendMode = .plusLighter
        for g in geo {
            let o = P(g.origin.x, g.origin.y), ax = P(g.axis.p.x, g.axis.p.y)
            let pts = g.rim.map { P($0.p.x, $0.p.y) }
            if showCones { coneFill(&c, convexHull([o] + pts), apex: o, end: ax, g) }
            if g.rim.filter({ $0.surface.onGround }).count >= LightGeometry.rimCount / 2 { footprint(&c, pts, ax, g) }
        }
        c.blendMode = .normal

        // osy a zaměřovač
        for g in geo {
            let o = P(g.origin.x, g.origin.y), ax = P(g.axis.p.x, g.axis.p.y)
            var line = Path(); line.move(to: o); line.addLine(to: ax)
            c.stroke(line, with: .color(g.color.color.opacity(0.9)), lineWidth: 1.2)
            if selection == .light(g.light.id) {
                var d = Path()
                d.addLines([CGPoint(x: ax.x, y: ax.y - 7), CGPoint(x: ax.x + 7, y: ax.y), CGPoint(x: ax.x, y: ax.y + 7), CGPoint(x: ax.x - 7, y: ax.y)])
                d.closeSubpath()
                c.fill(d, with: .color(.white))
            }
            fixtureIcon(&c, o, g)
        }
        label(&c, "▼ směr k publiku", CGPoint(x: roomRect.maxX - 6, y: roomRect.maxY + 16), size: 10, anchor: .trailing)
    }

    private func footprint(_ c: inout GraphicsContext, _ pts: [CGPoint], _ ax: CGPoint, _ g: LightGeometry) {
        let e = g.illuminance(at: g.axis.p, normal: g.axis.surface.normal)
        let a = clamp(e / 1800, 0.08, 0.85)
        let rr = max(4, pts.map { hypot($0.x - ax.x, $0.y - ax.y) }.max() ?? 4)
        let col = g.color.color
        let grad = Gradient(stops: [.init(color: col.opacity(a), location: 0), .init(color: col.opacity(a * 0.55), location: 0.7), .init(color: col.opacity(a * 0.08), location: 1)])
        c.fill(path(pts), with: .radialGradient(grad, center: ax, startRadius: 0, endRadius: rr))
    }

    /// Barva plochy po osvětlení (zjednodušený tone-mapping).
    private func shade(_ base: RGB, _ p: V3, _ n: V3) -> Color {
        var x = (0.0, 0.0, 0.0)
        for g in geo {
            let e = g.illuminance(at: p, normal: n)
            if e <= 0 { continue }
            x.0 += e * g.color.r; x.1 += e * g.color.g; x.2 += e * g.color.b
        }
        func ch(_ b: Double, _ v: Double) -> Double { clamp(b * (0.14 + 1.25 * (1 - exp(-v / 700))), 0, 1) }
        return Color(red: ch(base.r, x.0), green: ch(base.g, x.1), blue: ch(base.b, x.2))
    }

    private func fmt(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }

    // MARK: Elevace (zepředu / z boku)

    private func drawElevation(_ c: inout GraphicsContext) {
        let r = plan.room, st = plan.stage, s = pr.scale, front = pr.mode == .front
        let ext = front ? r.w : r.d
        let hc: (V3) -> Double = { pr.horizontal($0) }
        let E = { (h: Double, z: Double) in pr.elev(h, z) }
        let tl = E(0, r.h), br = E(ext, 0)
        let roomRect = CGRect(x: tl.x, y: tl.y, width: br.x - tl.x, height: br.y - tl.y)
        c.fill(Path(roomRect), with: .color(Color(white: 0.07)))

        var grid = Path()
        for h in stride(from: 1.0, to: ext, by: 1) { grid.move(to: E(h, 0)); grid.addLine(to: E(h, r.h)) }
        for z in stride(from: 1.0, to: r.h, by: 1) { grid.move(to: E(0, z)); grid.addLine(to: E(ext, z)) }
        c.stroke(grid, with: .color(.white.opacity(0.05)), lineWidth: 1)
        for h in stride(from: 0.0, through: ext, by: 2) { label(&c, String(Int(h)), CGPoint(x: E(h, 0).x, y: br.y + 12), size: 9, anchor: .center) }
        for z in stride(from: 0.0, through: r.h, by: 1) { label(&c, String(Int(z)), CGPoint(x: tl.x - 6, y: E(0, z).y), size: 9, anchor: .trailing) }
        label(&c, front ? "ČELNÍ POHLED (X–Z) – z publika na pódium" : "BOČNÍ POHLED (Y–Z) – pozadí vlevo, publikum vpravo",
              CGPoint(x: tl.x + 8, y: tl.y + 12), color: Color(white: 0.65), size: 11)

        // publikum (boční pohled)
        if !front {
            let a0 = st.y + st.d + 0.8, a1 = r.d - 0.3
            if a0 < a1 {
                let eye = plan.eyeHeight
                var l = Path(); l.move(to: E(a0, eye)); l.addLine(to: E(a1, eye))
                c.stroke(l, with: .color(.red.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                var y = a0 + 0.5
                while y < a1 {
                    let p = E(y, eye)
                    c.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(.red.opacity(0.7)))
                    y += 1.2
                }
                label(&c, "oči diváků \(fmt(eye)) m", CGPoint(x: E(a0, eye).x + 4, y: E(a0, eye).y - 8), color: .red.opacity(0.9))
            }
        }

        // pódium a truss
        let sh0 = front ? st.x - st.w / 2 : st.y, sh1 = front ? st.x + st.w / 2 : st.y + st.d
        let da = E(sh0, st.h), db = E(sh1, 0)
        let deck = CGRect(x: da.x, y: da.y, width: db.x - da.x, height: db.y - da.y)
        c.fill(Path(deck), with: .color(Color(white: 0.16)))
        c.stroke(Path(deck), with: .color(Color(white: 0.4)), lineWidth: 1)
        let tz = plan.truss.h
        var tr = Path()
        if front {
            tr.move(to: E(sh0 - 0.4, tz)); tr.addLine(to: E(sh1 + 0.4, tz))
            for h in [sh0 - 0.4, sh1 + 0.4] { tr.move(to: E(h, tz)); tr.addLine(to: E(h, 0)) }
        } else {
            for y in [plan.trussBackY, plan.trussFrontY] { tr.move(to: E(y, tz)); tr.addLine(to: E(y, 0)) }
            tr.move(to: E(plan.trussBackY, tz)); tr.addLine(to: E(plan.trussFrontY, tz))
        }
        c.stroke(tr, with: .color(Color(white: 0.6)), lineWidth: 2.5)
        label(&c, "truss \(fmt(tz)) m", CGPoint(x: E(front ? sh1 + 0.5 : plan.trussFrontY + 0.2, tz).x, y: E(0, tz).y), size: 10)

        // objekty
        for o in plan.objects {
            let hw = o.kind == .box ? (front ? o.w : o.d) / 2 : o.r
            let b = plan.surfaceZ(x: o.x, y: o.y) + o.lift
            let h0 = front ? o.x : o.y
            let a = E(h0 - hw, b + o.h), size = CGSize(width: CGFloat(hw * 2) * s, height: CGFloat(o.h) * s)
            let n = front ? V3(0, 1, 0) : V3(1, 0, 0)
            let fill = shade(o.color, V3(o.x, o.y, b + o.h / 2), n)
            let rect = CGRect(origin: a, size: size)
            let shape = o.hasHead ? Path(roundedRect: rect, cornerRadius: CGFloat(hw) * s) : Path(rect)
            c.fill(shape, with: .color(fill))
            c.stroke(shape, with: .color(isOutlined(o) ? .white : Color(white: 0.65)), lineWidth: isOutlined(o) ? 2.5 : 1)
            if o.hasHead {
                let hp = E(h0, b + o.h + 0.12)
                let head = Path(ellipseIn: CGRect(x: hp.x - 0.12 * s, y: hp.y - 0.12 * s, width: 0.24 * s, height: 0.24 * s))
                c.fill(head, with: .color(fill))
            }
            label(&c, o.name, CGPoint(x: a.x + size.width / 2, y: a.y - (o.hasHead ? 0.3 * s : 6)), size: 9, anchor: .center)
        }
        if plan.hazeOn { c.fill(Path(roomRect), with: .color(Color(red: 0.67, green: 0.75, blue: 0.9).opacity(0.03 + 0.07 * plan.hazeDensity))) }

        // kužely a světelné stopy
        c.blendMode = .plusLighter
        for g in geo {
            let o = E(hc(g.origin), g.origin.z), ax = E(hc(g.axis.p), g.axis.p.z)
            let pts = g.rim.map { E(hc($0.p), $0.p.z) }
            if showCones {
                coneFill(&c, convexHull([o] + pts), apex: o, end: ax, g)
                if plan.hazeOn {
                    var core = Path(); core.move(to: o); core.addLine(to: ax)
                    c.stroke(core, with: .color(g.color.color.opacity(0.55)), lineWidth: 1.5)
                }
            }
            let ground = g.rim.filter { $0.surface.onGround }
            if ground.count >= LightGeometry.rimCount / 3 && g.axis.surface.onGround {
                let hs = ground.map { hc($0.p) }
                let rx = max(0.15, ((hs.max() ?? 0) - (hs.min() ?? 0)) / 2) * Double(s)
                let e = g.illuminance(at: g.axis.p, normal: V3(0, 0, 1))
                let a = clamp(e / 1800, 0.1, 0.9)
                let oval = Path(ellipseIn: CGRect(x: ax.x - rx, y: ax.y - rx * 0.16, width: rx * 2, height: rx * 0.32))
                let grad = Gradient(colors: [g.color.color.opacity(a), g.color.color.opacity(0)])
                c.fill(oval, with: .radialGradient(grad, center: ax, startRadius: 0, endRadius: rx))
            }
        }
        c.blendMode = .normal

        // svítidla
        for g in geo {
            let p = E(hc(g.origin), g.origin.z)
            let selected = selection == .light(g.light.id)
            let angle = atan2(-g.direction.z, front ? g.direction.x : g.direction.y)
            var t = CGAffineTransform(translationX: p.x, y: p.y)
            t = t.rotated(by: CGFloat(angle))
            let body = Path(CGRect(x: -9, y: -5, width: 14, height: 10)).applying(t)
            c.fill(body, with: .color(Color(white: 0.17)))
            c.stroke(body, with: .color(selected ? .white : Color(white: 0.65)), lineWidth: selected ? 2.5 : 1)
            let lens = Path(CGRect(x: 5, y: -4, width: 4, height: 8)).applying(t)
            c.fill(lens, with: .color(g.color.color))
            if let fl = analysis.flags[g.light.id], !fl.isEmpty {
                c.stroke(Path(ellipseIn: CGRect(x: p.x - 13, y: p.y - 13, width: 26, height: 26)),
                         with: .color(fl.contains(.glare) || fl.contains(.burn) ? .red : .yellow), lineWidth: 2)
            }
            label(&c, "\(g.light.number)", CGPoint(x: p.x, y: p.y - 14), color: Color(white: 0.85), anchor: .center)
        }
        c.stroke(Path(roomRect), with: .color(Color(white: 0.4)), lineWidth: 2)
    }
}

// MARK: - Plátno s gesty

struct PlanCanvasView: View {
    @EnvironmentObject var store: PlannerStore
    let mode: PlanMode

    private enum Target {
        case light(UUID)
        case aim(UUID, Double)
        case object(UUID, Double, Double)
    }
    @State private var target: Target?
    @State private var picked = false
    @State private var zoom: CGFloat = 1
    @State private var baseZoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var basePan: CGSize = .zero

    /// Dotyková plocha pro výběr světla (iPhone: prst je větší než kurzor).
    private let hitRadius: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let pr = Projector(mode: mode, room: store.plan.room, size: geo.size, zoom: zoom, pan: pan)
            Canvas { ctx, _ in
                PlanRenderer(plan: store.plan, geo: store.geometry, analysis: store.analysis, selection: store.selection,
                             showCones: store.showCones, showHeat: store.showHeat, pr: pr).draw(&ctx)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        if !picked {
                            picked = true
                            target = pick(v.startLocation, pr)
                            if target != nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                        }
                        if target != nil { move(v.location, pr) }
                        else { pan = CGSize(width: basePan.width + v.translation.width, height: basePan.height + v.translation.height) }
                    }
                    .onEnded { v in
                        if target == nil {
                            basePan = pan
                            if hypot(v.translation.width, v.translation.height) < 6 { store.selection = nil }   // klepnutí do prázdna
                        }
                        picked = false; target = nil
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { zoom = min(6, max(1, baseZoom * $0.magnification)) }
                    .onEnded { _ in baseZoom = zoom }
            )
            .overlay(alignment: .bottomTrailing) {
                if zoom != 1 || pan != .zero {
                    Button { zoom = 1; baseZoom = 1; pan = .zero; basePan = .zero } label: {
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                            .padding(10).background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(10)
                }
            }
        }
    }

    private func snap(_ v: Double, _ step: Double) -> Double {
        store.snap ? (v / step).rounded() * step : round2(v)
    }

    private func pick(_ p: CGPoint, _ pr: Projector) -> Target? {
        let plan = store.plan
        // zaměřovač vybraného světla (jen shora)
        if mode == .top, case .light(let id)? = store.selection, let g = store.geometry.first(where: { $0.light.id == id }) {
            let a = pr.point(g.axis.p)
            if hypot(a.x - p.x, a.y - p.y) < hitRadius { return .aim(id, g.axis.p.z) }
        }
        var best: (UUID, CGFloat)?
        for g in store.geometry {
            let q = pr.point(g.origin), d = hypot(q.x - p.x, q.y - p.y)
            if d < hitRadius, d < (best?.1 ?? .infinity) { best = (g.light.id, d) }
        }
        if let b = best { store.selection = .light(b.0); return .light(b.0) }
        let (u, v) = pr.unproject(p)
        for o in plan.objects.reversed() {
            let hit: Bool
            if mode == .top {
                hit = o.kind == .box ? abs(u - o.x) <= o.w / 2 && abs(v - o.y) <= o.d / 2 : hypot(u - o.x, v - o.y) <= max(o.r, 0.25)
            } else {
                let h0 = mode == .front ? o.x : o.y
                let hw = o.kind == .box ? (mode == .front ? o.w : o.d) / 2 : max(o.r, 0.2)
                let b = plan.surfaceZ(x: o.x, y: o.y) + o.lift
                hit = abs(u - h0) <= hw && v >= b && v <= b + o.h
            }
            if hit {
                store.selection = .object(o.id)
                return .object(o.id, mode == .top ? o.x - u : (mode == .front ? o.x : o.y) - u, o.y - v)
            }
        }
        return nil
    }

    private func move(_ p: CGPoint, _ pr: Projector) {
        guard let t = target else { return }
        let (u, v) = pr.unproject(p)
        switch t {
        case .light(let id):
            guard let i = store.plan.lights.firstIndex(where: { $0.id == id }) else { return }
            switch mode {
            case .top: store.plan.lights[i].x = snap(u, 0.25); store.plan.lights[i].y = snap(v, 0.25)
            case .front: store.plan.lights[i].x = snap(u, 0.25); store.plan.lights[i].z = clamp(snap(v, 0.1), 0, store.plan.room.h)
            case .side: store.plan.lights[i].y = snap(u, 0.25); store.plan.lights[i].z = clamp(snap(v, 0.1), 0, store.plan.room.h)
            }
        case .aim(let id, let z):
            guard let i = store.plan.lights.firstIndex(where: { $0.id == id }) else { return }
            store.plan.lights[i].aim(at: V3(u, v, z))
        case .object(let id, let du, let dv):
            guard let i = store.plan.objects.firstIndex(where: { $0.id == id }) else { return }
            switch mode {
            case .top: store.plan.objects[i].x = snap(u + du, 0.25); store.plan.objects[i].y = snap(v + dv, 0.25)
            case .front: store.plan.objects[i].x = snap(u + du, 0.25)
            case .side: store.plan.objects[i].y = snap(u + du, 0.25)
            }
        }
    }
}
