import Foundation

enum SurfaceKind {
    case deck, floor, ceil, wallB, wallF, wallL, wallR, none

    var normal: V3 {
        switch self {
        case .deck, .floor, .none: return V3(0, 0, 1)
        case .ceil: return V3(0, 0, -1)
        case .wallB: return V3(0, 1, 0)
        case .wallF: return V3(0, -1, 0)
        case .wallL: return V3(1, 0, 0)
        case .wallR: return V3(-1, 0, 0)
        }
    }
    var onGround: Bool { self == .deck || self == .floor }
}

struct Hit {
    var t: Double
    var p: V3
    var surface: SurfaceKind
}

// MARK: - Plán: pomocné výpočty

extension Plan {
    var trussFrontY: Double { stage.y + stage.d - truss.frontInset }
    var trussBackY: Double { stage.y + truss.backInset }
    /// Referenční bod (hruď herce uprostřed pódia).
    var chestPoint: V3 { V3(stage.x, stage.y + stage.d / 2, stage.h + 1.5) }
    var allFixtures: [Fixture] { FixtureLibrary.builtIn + customFixtures }

    func inStage(x: Double, y: Double) -> Bool {
        x >= stage.x - stage.w / 2 && x <= stage.x + stage.w / 2 && y >= stage.y && y <= stage.y + stage.d
    }
    func surfaceZ(x: Double, y: Double) -> Double { inStage(x: x, y: y) ? stage.h : 0 }
    func fixture(for light: Light) -> Fixture {
        allFixtures.first { $0.id == light.fixtureID } ?? FixtureLibrary.builtIn[0]
    }
    func used(_ fixtureID: String) -> Int { lights.filter { $0.fixtureID == fixtureID }.count }

    /// Paprsek z `o` ve směru `d` – první dopad na pódium, podlahu, strop nebo stěnu místnosti.
    func traceRay(origin o: V3, dir d: V3, maxT: Double = 40) -> Hit {
        var bestT = maxT
        var bestS = SurfaceKind.none
        let tol = 0.02

        func test(_ t: Double, _ s: SurfaceKind) {
            guard t > 1e-3, t < bestT else { return }
            let p = o + d * t
            if p.x >= -tol, p.x <= room.w + tol, p.y >= -tol, p.y <= room.d + tol, p.z >= -tol, p.z <= room.h + tol {
                bestT = t
                bestS = s
            }
        }

        if d.z < -1e-6 {
            let td = (stage.h - o.z) / d.z
            if td > 1e-3 {
                let p = o + d * td
                if inStage(x: p.x, y: p.y) { test(td, .deck) }
            }
            test(-o.z / d.z, .floor)
        }
        if d.z > 1e-6 { test((room.h - o.z) / d.z, .ceil) }
        if d.x > 1e-6 { test((room.w - o.x) / d.x, .wallR) } else if d.x < -1e-6 { test(-o.x / d.x, .wallL) }
        if d.y > 1e-6 { test((room.d - o.y) / d.y, .wallF) } else if d.y < -1e-6 { test(-o.y / d.y, .wallB) }
        return Hit(t: bestT, p: o + d * bestT, surface: bestS)
    }

    func makeGeometry() -> [LightGeometry] {
        lights.map { LightGeometry(light: $0, fixture: fixture(for: $0), plan: self) }
    }
}

// MARK: - Světlo: směr a zaměření

extension Light {
    var direction: V3 {
        let t = rad(tilt), p = rad(pan)
        return V3(sin(t) * sin(p), sin(t) * cos(p), -cos(t))
    }

    /// Nastaví pan/tilt tak, aby světlo mířilo na bod `target`.
    mutating func aim(at target: V3) {
        let v = target - position
        let hz = hypot(v.x, v.y)
        tilt = round2(clamp(deg(atan2(hz, -v.z)), 0, 150))
        if hz > 1e-3 { pan = round2(deg(atan2(v.x, v.y))) }
    }
}

// MARK: - Geometrie kuželu a osvětlenost

struct LightGeometry {
    static let rimCount = 28

    let light: Light
    let fixture: Fixture
    let origin: V3
    let direction: V3
    /// Půlúhel kuželu [rad].
    let halfAngle: Double
    /// Svítivost na ose [cd].
    let candela: Double
    let cosField: Double
    let rim: [Hit]
    let axis: Hit

    var color: RGB { light.color }

    init(light: Light, fixture: Fixture, plan: Plan) {
        let o = light.position
        let d = light.direction
        let h = rad(clamp(light.angle / 2, 0.5, 80))
        let lm = fixture.lumens * light.intensity / 100
        let helper = abs(d.z) < 0.9 ? V3(0, 0, 1) : V3(1, 0, 0)
        let u = norm3(cross3(d, helper))
        let v = cross3(d, u)
        var rim: [Hit] = []
        for k in 0..<LightGeometry.rimCount {
            let f = Double(k) / Double(LightGeometry.rimCount) * 2 * .pi
            let dir = norm3(d * cos(h) + (u * cos(f) + v * sin(f)) * sin(h))
            rim.append(plan.traceRay(origin: o, dir: dir))
        }
        self.light = light
        self.fixture = fixture
        self.origin = o
        self.direction = d
        self.halfAngle = h
        self.candela = lm / (2 * .pi * (1 - cos(h)))
        self.cosField = cos(min(h * 1.5, .pi))
        self.rim = rim
        self.axis = plan.traceRay(origin: o, dir: d)
    }

    /// Osvětlenost [lx] v bodě `p` na ploše s normálou `n` (nil = kolmo ke směru světla).
    func illuminance(at p: V3, normal n: V3?) -> Double {
        let v = p - origin
        let d2 = dot3(v, v)
        let dist = max(d2.squareRoot(), 1e-6)
        let dir = v / dist
        let c = dot3(dir, direction)
        if c <= cosField { return 0 }
        let f = 1 - smoothstep(0.5 * halfAngle, 1.5 * halfAngle, acos(clamp(c, -1, 1)))
        let ci = n.map { max(0, -dot3(dir, $0)) } ?? 1
        return candela * f * ci / max(d2, 0.25)
    }
}
