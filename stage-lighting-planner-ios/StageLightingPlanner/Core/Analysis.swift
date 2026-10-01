import Foundation

enum LightFlag: String { case glare, low, burn, off }
enum Severity: Int { case bad = 0, warn, info, ok }

struct Message: Identifiable {
    let id = UUID()
    var severity: Severity
    var text: String
    var lightID: UUID?
}

struct AnalysisResult {
    var messages: [Message] = []
    var flags: [UUID: Set<LightFlag>] = [:]
    var depth = 0
    var contrast = 0
    var safety = 100
    var avgLux = 0.0
    var uniformity = 0.0
    var coverage = 0.0
    var maxLux = 0.0
    var watt = 0.0
    var count = 0
}

/// Hloubka, kontrast a bezpečnost rozmístění + varování (oslnění, nízký úhel, přepal front zóny, paprsky mimo pódium).
enum Analyzer {
    static let glareLux = 40.0
    static let burnLux = 3500.0

    static func run(_ plan: Plan, _ geo: [LightGeometry]) -> AnalysisResult {
        var r = AnalysisResult()
        let st = plan.stage, room = plan.room
        let x0 = st.x - st.w / 2, x1 = st.x + st.w / 2, y0 = st.y, y1 = st.y + st.d
        let up = V3(0, 0, 1)

        func add(_ s: Severity, _ t: String, _ id: UUID? = nil) { r.messages.append(Message(severity: s, text: t, lightID: id)) }
        func flag(_ id: UUID, _ f: LightFlag) { r.flags[id, default: []].insert(f) }
        func name(_ g: LightGeometry) -> String { "#\(g.light.number) \(g.fixture.name)" }
        func f1(_ v: Double) -> String { String(format: "%.1f", v) }
        // úzké efektové paprsky (≤ 15°) se do plošných hodnot nepočítají
        func total(_ p: V3) -> Double {
            geo.reduce(0) { $0 + ($1.light.angle > 15 ? $1.illuminance(at: p, normal: up) : 0) }
        }

        // --- pokrytí pódia
        var n = 0.0, sum = 0.0, mn = Double.infinity, mx = 0.0, fSum = 0.0, fN = 0.0, fMax = 0.0, cov = 0.0
        var fPt: V3?
        for x in stride(from: x0 + 0.25, to: x1, by: 0.5) {
            for y in stride(from: y0 + 0.25, to: y1, by: 0.5) {
                let e = total(V3(x, y, st.h))
                n += 1; sum += e; mn = min(mn, e); mx = max(mx, e)
                if e >= 150 { cov += 1 }
                if y > y1 - 1.5 {
                    fSum += e; fN += 1
                    if e > fMax { fMax = e; fPt = V3(x, y, st.h) }
                }
            }
        }
        let avg = n > 0 ? sum / n : 0
        let fAvg = fN > 0 ? fSum / fN : 0
        r.avgLux = avg
        r.uniformity = avg > 0 ? mn / avg : 0
        r.coverage = n > 0 ? cov / n : 0
        r.maxLux = mx
        r.count = geo.count
        r.watt = geo.reduce(0) { $0 + $1.fixture.watt * $1.light.intensity / 100 }

        // --- rozdělení světel na přední / boční / zadní vůči herci
        let chest = plan.chestPoint
        var front = 0.0, back = 0.0, side = 0.0, fL = 0.0, fR = 0.0
        var bgHits = 0, narrow = 0
        var elevations: [(g: LightGeometry, el: Double)] = []
        for g in geo {
            let e = g.illuminance(at: chest, normal: nil)
            let dx = g.origin.x - chest.x, dy = g.origin.y - chest.y
            let az = abs(deg(atan2(dx, dy)))
            if e > 0 {
                if az < 60 {
                    front += e
                    if dx < 0 { fL += e } else { fR += e }
                    elevations.append((g, deg(atan2(g.origin.z - chest.z, hypot(dx, dy)))))
                } else if az < 120 { side += e } else { back += e }
            }
            if g.axis.surface == .wallB { bgHits += 1 }
            if g.light.angle <= 15 { narrow += 1 }
        }

        // --- oslnění publika, úhly, paprsky mimo pódium
        let ay0 = y1 + 0.8, ay1 = room.d - 0.3
        var aud: [V3] = []
        for y in stride(from: ay0, through: ay1, by: 0.8) {
            for x in stride(from: 0.4, through: room.w - 0.4, by: 0.8) { aud.append(V3(x, y, plan.eyeHeight)) }
        }
        var glareCount = 0
        for g in geo {
            var cnt = 0, mE = 0.0
            for pa in aud {
                let u = norm3(pa - g.origin)
                if u.y < 0.26 { continue }                       // světlo je mimo zorné pole diváka (dívá se k pódiu)
                if dot3(u, g.direction) <= g.cosField { continue } // divák není v kuželu
                let e = g.illuminance(at: pa, normal: nil)
                if e > glareLux { cnt += 1; mE = max(mE, e) }
            }
            if cnt > 0 {
                glareCount += 1
                flag(g.light.id, .glare)
                let pct = Int((Double(cnt) / Double(aud.count) * 100).rounded())
                add(mE > 250 ? .bad : .warn,
                    "Oslnění publika: \(name(g)) svítí do očí divákům (≈ \(pct) % plochy, až \(Int(mE.rounded())) lx v očích). Zvyšte tilt k pódiu, zúžte kužel nebo světlo zastíňte.", g.light.id)
            }
            let l = g.light
            let sideAcross = l.role == .side && abs(cos(rad(l.pan))) < 0.5
            if l.tilt > 90 && l.role != .background && l.role != .fx {
                flag(l.id, .low)
                add(.warn, "\(name(g)) míří vzhůru (tilt \(Int(l.tilt))°) – paprsek mine pódium.", l.id)
            } else if l.tilt > 70 && l.tilt <= 90 && !sideAcross {
                flag(l.id, .low)
                add(.warn, "Nízký úhel: \(name(g)) má tilt \(Int(l.tilt))° od svislice – téměř vodorovný paprsek hrozí oslněním a odleskem. Doporučeno ≤ 60°.", l.id)
            }
            if l.role != .fx {
                func ok(_ h: Hit) -> Bool { h.surface == .deck || h.surface == .wallB }
                let frac = Double(g.rim.filter(ok).count) / Double(g.rim.count)
                if !ok(g.axis) && frac < 0.5 {
                    let where_: String
                    switch g.axis.surface {
                    case .floor: where_ = "podlahu mimo pódium"
                    case .wallL: where_ = "levou stěnu"
                    case .wallR: where_ = "pravou stěnu"
                    case .wallF: where_ = "přední stěnu"
                    case .ceil: where_ = "strop"
                    default: where_ = "prostor"
                    }
                    flag(l.id, .off)
                    add(.warn, "Mimo pódium: \(name(g)) míří na \(where_).", l.id)
                } else if frac < 0.6 && l.role != .side {
                    flag(l.id, .off)
                    add(.info, "\(name(g)): jen \(Int((frac * 100).rounded())) % kuželu dopadá na pódium nebo pozadí.", l.id)
                }
            }
            if g.origin.x < -0.01 || g.origin.x > room.w + 0.01 || g.origin.y < -0.01 || g.origin.y > room.d + 0.01 || g.origin.z > room.h {
                add(.info, "\(name(g)) je mimo prostor místnosti.", l.id)
            }
        }

        // --- přepal front zóny
        if let fp = fPt, fMax > burnLux || (fAvg > 2.2 * avg && fAvg > 400) {
            let top = geo.filter { $0.light.angle > 15 }
                .map { (g: $0, e: $0.illuminance(at: fp, normal: up)) }
                .sorted { $0.e > $1.e }.prefix(2).filter { $0.e > 0 }
            top.forEach { flag($0.g.light.id, .burn) }
            let ids = top.map { "#\($0.g.light.number)" }.joined(separator: ", ")
            add(.bad, "Přepal front zóny (přední 1,5 m pódia): max \(Int(fMax)) lx, průměr \(Int(fAvg)) lx vs. \(Int(avg)) lx na celém pódiu. Hlavní zdroje: \(ids) – snižte intenzitu nebo je rozprostřete.", top.first?.g.light.id)
        }

        // --- hloubka a kontrast
        if geo.isEmpty {
            add(.info, "Zatím žádná světla – použijte záložku Analýza → Režimy (⭐ Doporučené rozmístění) nebo přidejte světla z Knihovny.")
        } else {
            let ratioB = front > 0 ? back / front : (back > 0 ? 9 : 0)
            if back == 0 { add(.warn, "Chybí zadní světlo (backlight/kontra). Bez něj je herec plochý a splývá s pozadím – přidejte 2 světla na zadní truss ve výšce ≥ 4 m.") }
            else if ratioB < 0.3 { add(.info, "Zadní světlo je slabé (\(Int(ratioB * 100)) % předního) – pro hloubku zvyšte na 60–120 %.") }
            else if ratioB > 2.5 { add(.info, "Zadní světlo výrazně převyšuje přední – tváře budou ve stínu (silueta). Zvyšte key nebo snižte backlight.") }
            if front > 0 && side == 0 { add(.info, "Boční světlo (side light) chybí – přidáním z výšky 1,5–2,5 m se vyniknou tvary těla a oddělí se od pozadí.") }
            if bgHits == 0 { add(.info, "Pozadí není nasvíceno – wash na zadní stěnu (barevný, tlumenější než herec) zvýší vizuální hloubku.") }
            if front > 0 {
                let hi = max(fL, fR), lo = min(fL, fR)
                if lo == 0 { add(.info, "Přední světlo jen z jedné strany – přidejte fill z opačné strany (poměr key:fill ≈ 2:1) pro měkčí stíny.") }
                else {
                    let q = hi / lo
                    if q < 1.2 { add(.info, "Poměr key:fill je \(f1(q)):1 – plochý obraz. Snižte fill na ~50 % klíčového světla.") }
                    else if q > 5 { add(.info, "Poměr key:fill je \(f1(q)):1 – stíny jsou tvrdé. Přidejte nebo zvyšte fill.") }
                }
                for e in elevations where e.el < 25 || e.el > 65 {
                    add(.info, "\(name(e.g)): výška nad hercem \(Int(e.el.rounded()))° – ideální přední světlo je 35–55° (nižší zplošťuje a oslňuje, vyšší dělá stíny v očích).", e.g.light.id)
                }
            }
            if narrow > 0 && !plan.hazeOn { add(.info, "Máte \(narrow)× úzký paprsek (≤ 15°). Zapněte haze, jinak nebudou paprsky ve vzduchu vidět.") }
            if plan.hazeOn && narrow == 0 { add(.info, "Haze je zapnuté, ale nejsou tu úzké paprsky (Beam/Spot) – efekt se neuplatní.") }
            if plan.hazeOn && plan.hazeDensity > 0.8 { add(.info, "Husté haze zplošťuje kontrast – doporučeno 0,3–0,6.") }
            if plan.hazeOn && glareCount > 0 { add(.warn, "Haze zvyšuje viditelnost (a nepříjemnost) paprsků mířících do publika – nejdřív odstraňte oslnění.") }
        }
        if plan.truss.h > room.h - 0.3 { add(.bad, "Truss (\(f1(plan.truss.h)) m) je příliš blízko stropu místnosti (\(f1(room.h)) m).") }
        if plan.truss.h - st.h < 3 { add(.info, "Truss je jen \(f1(plan.truss.h - st.h)) m nad pódiem – kužele budou malé a světla budou oslňovat herce. Doporučeno ≥ 3,5 m.") }
        for fx in plan.allFixtures {
            let u = plan.used(fx.id)
            if u > fx.stock { add(.warn, "\(fx.name): použito \(u) ks, ale v inventáři jen \(fx.stock).") }
        }

        // --- skóre
        var depth = 0.0
        depth += 40 * clamp(back / max(front, 1e-6) / 0.6, 0, 1) * (back > 2.5 * front ? 0.6 : 1)
        depth += 20 * clamp(side / (0.25 * front + 1e-6), 0, 1)
        depth += bgHits > 0 ? 20 : 0
        depth += plan.hazeOn ? (narrow > 0 ? 20 : 10) : 0
        var contrast = 0.0
        if front > 0 {
            let lo = min(fL, fR)
            let q = lo > 0 ? max(fL, fR) / lo : Double.infinity
            if q == .infinity { contrast += 20 }
            else if q < 1.2 { contrast += 20 + (q - 1) * 100 }
            else if q <= 4 { contrast += 50 }
            else { contrast += 50 * clamp(1 - (q - 4) / 6, 0.2, 1) }
        }
        let pr = avg > 0 ? mx / avg : 0
        if pr < 1.5 { contrast += 50 * clamp((pr - 1) / 0.5, 0, 1) }
        else if pr <= 4 { contrast += 50 }
        else { contrast += 50 * clamp(1 - (pr - 4) / 6, 0.3, 1) }
        if geo.isEmpty { depth = 0; contrast = 0 }
        var safety = 100.0
        for set in r.flags.values {
            if set.contains(.glare) { safety -= 25 }
            if set.contains(.low) { safety -= 8 }
            if set.contains(.burn) { safety -= 10 }
            if set.contains(.off) { safety -= 4 }
        }
        if !geo.isEmpty && !r.messages.contains(where: { $0.severity == .bad || $0.severity == .warn }) {
            add(.ok, "Žádná varování – rozmístění je bezpečné a vyvážené.")
        }
        r.messages.sort { $0.severity.rawValue < $1.severity.rawValue }
        r.depth = Int(clamp(depth, 0, 100).rounded())
        r.contrast = Int(clamp(contrast, 0, 100).rounded())
        r.safety = Int(clamp(safety, 0, 100).rounded())
        return r
    }
}
