import Foundation

// MARK: - Knihovna svítidel

enum FixtureType: String, Codable, CaseIterable, Identifiable {
    case par = "PAR", beam = "Beam", wash = "Wash", spot = "Spot"
    case fresnel = "Fresnel", bar = "Bar", flood = "Flood", follow = "Follow"
    var id: String { rawValue }
}

enum LampTech: String, Codable, CaseIterable {
    case led, tungsten, discharge
    /// Orientační světelný výkon (lm na W příkonu).
    var lumensPerWatt: Double {
        switch self {
        case .led: return 35
        case .tungsten: return 14
        case .discharge: return 28
        }
    }
    var title: String {
        switch self {
        case .led: return "LED"
        case .tungsten: return "Žárovka"
        case .discharge: return "Výbojka"
        }
    }
}

struct Fixture: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var type: FixtureType
    var watt: Double
    var angle: Double
    var minAngle: Double
    var maxAngle: Double
    var stock: Int
    var tech: LampTech
    var lumens: Double { watt * tech.lumensPerWatt }
}

// MARK: - Barva

struct RGB: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    init(hex: UInt32) {
        self.init(Double((hex >> 16) & 255) / 255, Double((hex >> 8) & 255) / 255, Double(hex & 255) / 255)
    }
    static let white = RGB(hex: 0xFFFFFF)
    static let warm = RGB(hex: 0xFFCF9A)
    static let cool = RGB(hex: 0x9EC5FF)
    static let amber = RGB(hex: 0xFFB347)
    static let cyan = RGB(hex: 0x55E0FF)
    static let blue = RGB(hex: 0x4A6CFF)
}

// MARK: - Světlo

enum LightRole: String, Codable, CaseIterable, Identifiable {
    case auto, front, back, side, counter, background, fx
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: return "Auto"
        case .front: return "Přední (key/fill)"
        case .back: return "Zadní (backlight)"
        case .side: return "Boční (side)"
        case .counter: return "Kontra"
        case .background: return "Pozadí"
        case .fx: return "Efekt (paprsky)"
        }
    }
}

struct Light: Identifiable, Codable, Hashable {
    var id = UUID()
    var number: Int
    var fixtureID: String
    var x: Double
    var y: Double
    var z: Double
    /// 0 = k publiku (+Y), 90 = doprava (+X)
    var pan: Double = 180
    /// 0 = svisle dolů, 90 = vodorovně
    var tilt: Double = 30
    var angle: Double
    var intensity: Double = 80
    var color: RGB = .white
    var role: LightRole = .auto

    var position: V3 { V3(x, y, z) }
}

// MARK: - Scéna

struct Room: Codable { var w = 16.0, d = 18.0, h = 7.0 }
struct Stage: Codable { var x = 8.0, y = 1.5, w = 9.0, d = 6.0, h = 0.8 }
struct Truss: Codable { var h = 5.5, frontInset = 0.6, backInset = 0.6 }

enum OpeningType: String, Codable, CaseIterable { case door = "Dveře", window = "Okno" }
enum Wall: String, Codable, CaseIterable, Identifiable {
    case back = "Zadní", front = "Přední", left = "Levá", right = "Pravá"
    var id: String { rawValue }
}

struct Opening: Identifiable, Codable {
    var id = UUID()
    var type: OpeningType
    var wall: Wall
    /// Vzdálenost od levého rohu stěny (pohled zevnitř od publika) v metrech.
    var pos: Double
    var w: Double
    var h: Double
    var sill: Double
}

enum ObjectKind: String, Codable, CaseIterable { case box, cylinder }

struct StageObject: Identifiable, Codable {
    var id = UUID()
    var kind: ObjectKind
    var name: String
    var x: Double
    var y: Double
    var lift: Double = 0
    var w: Double = 0.7
    var d: Double = 0.6
    var r: Double = 0.3
    var h: Double = 1
    var color: RGB = RGB(hex: 0x7D8AA8)
    var hasHead = false
}

struct Plan: Codable {
    var room = Room()
    var stage = Stage()
    var truss = Truss()
    var eyeHeight = 1.2
    var hazeOn = false
    var hazeDensity = 0.6
    var openings: [Opening] = [
        Opening(type: .door, wall: .front, pos: 3, w: 1.4, h: 2.1, sill: 0),
        Opening(type: .door, wall: .right, pos: 2.5, w: 1.1, h: 2.1, sill: 0),
        Opening(type: .window, wall: .left, pos: 5, w: 2, h: 1.4, sill: 1.2),
        Opening(type: .window, wall: .left, pos: 11, w: 2, h: 1.4, sill: 1.2),
    ]
    var objects: [StageObject] = [
        StageObject(kind: .cylinder, name: "Herec", x: 8, y: 4.5, r: 0.22, h: 1.7, hasHead: true),
        StageObject(kind: .box, name: "Reproduktor L", x: 4.2, y: 6.6, w: 0.7, d: 0.6, h: 1.2, color: RGB(hex: 0x3A4560)),
        StageObject(kind: .box, name: "Reproduktor P", x: 11.8, y: 6.6, w: 0.7, d: 0.6, h: 1.2, color: RGB(hex: 0x3A4560)),
    ]
    var lights: [Light] = []
    var customFixtures: [Fixture] = []
    var nextNumber = 1
}
