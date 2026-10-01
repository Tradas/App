import SwiftUI
import UniformTypeIdentifiers

enum Selection: Hashable {
    case light(UUID)
    case object(UUID)
}

enum ViewMode: String, CaseIterable, Identifiable {
    case top = "Top (2D)", front = "Zepředu", side = "Z boku", threeD = "3D"
    var id: String { rawValue }
}

enum CameraPreset { case front, side, top, persp }
enum AppTab: Hashable { case plan, scene, library, lights, analysis }

/// Jediný zdroj pravdy: plán + z něj odvozená geometrie paprsků a analýza.
@MainActor
final class PlannerStore: ObservableObject {
    @Published var plan: Plan {
        didSet { refresh(); scheduleSave() }
    }
    @Published private(set) var geometry: [LightGeometry] = []
    @Published private(set) var analysis = AnalysisResult()
    @Published var selection: Selection?
    @Published var tab: AppTab = .plan
    @Published var viewMode: ViewMode = .top
    @Published var showCones = true
    @Published var showHeat = false
    @Published var snap = true
    @Published var replaceOnPreset = true
    @Published var cameraPreset: CameraPreset = .persp
    @Published var cameraToken = 0

    private var saveTask: Task<Void, Never>?
    private static let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("plan.json")

    init() {
        if let data = try? Data(contentsOf: Self.fileURL), let p = try? JSONDecoder().decode(Plan.self, from: data) {
            plan = p
        } else {
            var p = Plan()
            p.apply(.three, replace: true)
            plan = p
        }
        refresh()
    }

    private func refresh() {
        geometry = plan.makeGeometry()
        analysis = Analyzer.run(plan, geometry)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [plan] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            if let data = try? JSONEncoder().encode(plan) { try? data.write(to: Self.fileURL, options: .atomic) }
        }
    }

    // MARK: Bindings

    func lightBinding(_ id: UUID) -> Binding<Light>? {
        guard let initial = plan.lights.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.plan.lights.first(where: { $0.id == id }) ?? initial },
            set: { new in if let i = self.plan.lights.firstIndex(where: { $0.id == id }) { self.plan.lights[i] = new } })
    }

    func objectBinding(_ id: UUID) -> Binding<StageObject>? {
        guard let initial = plan.objects.first(where: { $0.id == id }) else { return nil }
        return Binding(
            get: { self.plan.objects.first(where: { $0.id == id }) ?? initial },
            set: { new in if let i = self.plan.objects.firstIndex(where: { $0.id == id }) { self.plan.objects[i] = new } })
    }

    // MARK: Úpravy

    func addFromLibrary(_ f: Fixture, count: Int) {
        var last: UUID?
        for _ in 0..<count {
            let k = plan.lights.count
            let pos = V3(plan.stage.x + Double(k % 9 - 4) * 0.9, plan.trussFrontY, plan.truss.h)
            last = plan.addLight(f, at: pos)
        }
        if let last { selection = .light(last) }
    }

    func duplicateSelected() {
        guard case .light(let id)? = selection, var l = plan.lights.first(where: { $0.id == id }) else { return }
        l.id = UUID(); l.number = plan.nextNumber; plan.nextNumber += 1; l.x += 0.5
        plan.lights.append(l)
        selection = .light(l.id)
    }

    func deleteSelected() {
        switch selection {
        case .light(let id)?: plan.lights.removeAll { $0.id == id }
        case .object(let id)?: plan.objects.removeAll { $0.id == id }
        case nil: break
        }
        selection = nil
    }

    func addObject(_ kind: String) {
        let base = (plan.stage.x, plan.stage.y + plan.stage.d / 2)
        var o: StageObject
        switch kind {
        case "speaker": o = StageObject(kind: .box, name: "Reproduktor", x: base.0, y: base.1, w: 0.7, d: 0.6, h: 1.2, color: RGB(hex: 0x3A4560))
        case "cube": o = StageObject(kind: .box, name: "Kostka", x: base.0, y: base.1, w: 0.8, d: 0.8, h: 0.8, color: RGB(hex: 0x8A6BD6))
        case "person": o = StageObject(kind: .cylinder, name: "Hudebník", x: base.0, y: base.1, r: 0.22, h: 1.7, color: RGB(hex: 0xD6A24A), hasHead: true)
        case "riser": o = StageObject(kind: .box, name: "Riser", x: base.0, y: base.1, w: 2, d: 2, h: 0.4, color: RGB(hex: 0x2F394F))
        default: o = StageObject(kind: .cylinder, name: "Válec", x: base.0, y: base.1, r: 0.4, h: 1, color: RGB(hex: 0x4A9D8A))
        }
        plan.objects.append(o)
        selection = .object(o.id)
    }

    func snapToTruss(_ id: UUID) {
        guard let i = plan.lights.firstIndex(where: { $0.id == id }) else { return }
        let l = plan.lights[i]
        plan.lights[i].z = plan.truss.h
        plan.lights[i].y = abs(l.y - plan.trussFrontY) < abs(l.y - plan.trussBackY) ? plan.trussFrontY : plan.trussBackY
    }

    func apply(_ preset: Preset) {
        plan.apply(preset, replace: replaceOnPreset)
        selection = nil
    }

    func resetAll() {
        var p = Plan()
        p.apply(.three, replace: true)
        plan = p
        selection = nil
    }

    func focus(light id: UUID) {
        selection = .light(id)
        tab = .plan
    }

    func requestCamera(_ p: CameraPreset) {
        cameraPreset = p
        cameraToken += 1
    }

    func importPlan(from url: URL) {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        if let data = try? Data(contentsOf: url), let p = try? JSONDecoder().decode(Plan.self, from: data) {
            plan = p
            selection = nil
        }
    }
}

/// Dokument pro export/import plánu (JSON).
struct PlanDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var plan: Plan

    init(plan: Plan) { self.plan = plan }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        plan = try JSONDecoder().decode(Plan.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try JSONEncoder().encode(plan))
    }
}

// MARK: - Barvy

extension RGB {
    var color: Color { Color(red: r, green: g, blue: b) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
    init(_ color: Color) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(Double(r), Double(g), Double(b))
    }
}
