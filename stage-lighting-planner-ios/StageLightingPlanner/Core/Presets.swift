import Foundation

enum Preset: String, CaseIterable, Identifiable {
    case full, three, back, side, counter, background, haze
    var id: String { rawValue }

    var title: String {
        switch self {
        case .full: return "⭐ Doporučené rozmístění"
        case .three: return "Trojbodové svícení"
        case .back: return "Backlight"
        case .side: return "Side light"
        case .counter: return "Kontra"
        case .background: return "Nasvícení pozadí"
        case .haze: return "Haze"
        }
    }
    var summary: String {
        switch self {
        case .full: return "Trojbodové + pozadí + side + kontra + haze: maximální hloubka a kontrast při bezpečných úhlech."
        case .three: return "Key (profil) + fill (wash) zepředu pod ~45° a dva backlighty ze zadního trussu."
        case .back: return "Řada PARů ze zadního trussu – oddělí herce od pozadí, svítí svisle dolů na pódium."
        case .side: return "Boční světla z výšky 2,2 m přes pódium (teplá / studená) – tvar těla."
        case .counter: return "Úzké beamy ze zadního trussu křížem přes pódium; bezpečný tilt, zapne haze."
        case .background: return "Wash ze zadního trussu na zadní stěnu místnosti."
        case .haze: return "Zapne haze a přidá vějíř beamů nad pódiem, aby byly paprsky vidět."
        }
    }
}

private struct Spec {
    var prefs: [String]
    var type: FixtureType
    var pos: V3
    var aim: V3
    var angle: Double? = nil
    var intensity: Double
    var color: RGB
    var role: LightRole
}

extension Plan {
    /// Vybere svítidlo z knihovny: nejdřív volné (ve skladu), jinak první shodné, jinak podle typu.
    func pickFixture(prefs: [String], type: FixtureType) -> Fixture {
        let all = allFixtures
        for p in prefs {
            if let f = all.first(where: { $0.name.contains(p) && used($0.id) < $0.stock }) { return f }
        }
        for p in prefs {
            if let f = all.first(where: { $0.name.contains(p) }) { return f }
        }
        return all.first(where: { $0.type == type && used($0.id) < $0.stock })
            ?? all.first(where: { $0.type == type }) ?? all[0]
    }

    @discardableResult
    mutating func addLight(_ f: Fixture, at pos: V3, aim: V3? = nil, angle: Double? = nil,
                           intensity: Double = 80, color: RGB? = nil, role: LightRole = .auto) -> UUID {
        var l = Light(number: nextNumber, fixtureID: f.id, x: pos.x, y: pos.y, z: pos.z,
                      angle: min(max(angle ?? f.angle, f.minAngle), f.maxAngle))
        nextNumber += 1
        l.intensity = intensity
        l.color = color ?? (f.tech == .tungsten ? RGB.warm : RGB.white)
        l.role = role
        l.aim(at: aim ?? chestPoint)
        lights.append(l)
        return l.id
    }

    mutating func apply(_ preset: Preset, replace: Bool) {
        if replace { lights = [] }
        let names: [Preset] = preset == .full ? [.three, .background, .side, .counter, .haze] : [preset]
        for p in names {
            for s in specs(p) { addLight(pickFixture(prefs: s.prefs, type: s.type), at: s.pos, aim: s.aim, angle: s.angle, intensity: s.intensity, color: s.color, role: s.role) }
        }
        if [.haze, .counter, .full].contains(preset) { hazeOn = true; hazeDensity = 0.5 }
    }

    private func specs(_ p: Preset) -> [Spec] {
        let cx = stage.x, cy = stage.y + stage.d / 2, sw = stage.w, deck = stage.h
        let yF = trussFrontY, yB = trussBackY, tz = truss.h, chest = chestPoint
        switch p {
        case .three:
            let backAim = V3(cx, cy + 0.3, deck + 1.2)
            return [
                Spec(prefs: ["Source Four", "FS-600", "Junior"], type: .spot, pos: V3(cx - sw * 0.22, yF, tz), aim: chest, angle: 36, intensity: 100, color: .warm, role: .front),
                Spec(prefs: ["Rotating Wash", "TMH-20", "Color Wash"], type: .wash, pos: V3(cx + sw * 0.28, yF, tz), aim: chest, angle: 40, intensity: 55, color: .cool, role: .front),
                Spec(prefs: ["PAR 64 Cameo", "Varytec"], type: .par, pos: V3(cx - 1.2, yB, tz), aim: backAim, intensity: 50, color: .white, role: .back),
                Spec(prefs: ["PAR 64 Cameo", "Varytec"], type: .par, pos: V3(cx + 1.2, yB, tz), aim: backAim, intensity: 50, color: .white, role: .back),
            ]
        case .back:
            return [-0.3, -0.1, 0.1, 0.3].map {
                Spec(prefs: ["Varytec", "PAR 64 RGBWA"], type: .par, pos: V3(cx + $0 * sw, yB, tz), aim: V3(cx + $0 * sw, cy + 0.4, deck + 1.2), intensity: 70, color: .cool, role: .back)
            }
        case .side:
            var out: [Spec] = []
            for (sx, col) in [(-1.0, RGB.amber), (1.0, RGB.cyan)] {
                for dy in [-1.2, 1.0] {
                    out.append(Spec(prefs: ["PAR 64 Cameo", "Punch"], type: .par, pos: V3(cx + sx * (sw / 2 + 0.9), cy + dy, deck + 2.2),
                                    aim: V3(cx - sx * sw * 0.38, cy + dy, deck), intensity: 65, color: col, role: .side))
                }
            }
            return out
        case .counter:
            return [-3.2, -1.1, 1.1, 3.2].enumerated().map { i, k in
                Spec(prefs: ["Vector", "Beam BAR"], type: .beam, pos: V3(cx + k * sw / 9, yB, tz), aim: V3(cx - k * sw / 18, cy + 1.4, deck),
                     intensity: 100, color: i % 2 == 1 ? .cyan : .white, role: .counter)
            }
        case .background:
            return [-0.3, 0, 0.3].map {
                Spec(prefs: ["Wall Wash", "Rotating Wash"], type: .wash, pos: V3(cx + $0 * sw, yB, tz), aim: V3(cx + $0 * sw, 0, 2.4), angle: 50, intensity: 65, color: .blue, role: .background)
            }
        case .haze:
            let my = (yF + yB) / 2
            return [-3, -1, 1, 3].map {
                Spec(prefs: ["Vector", "Beam BAR"], type: .beam, pos: V3(cx + $0 * sw / 9, my, tz), aim: V3(cx - $0 * sw / 9 * 1.4, cy + 1.2, deck), intensity: 100, color: .white, role: .fx)
            }
        case .full:
            return []
        }
    }
}
