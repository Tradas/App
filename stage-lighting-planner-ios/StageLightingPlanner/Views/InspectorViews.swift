import SwiftUI

/// Panel vybraného světla nebo objektu (poloha, směr, barva…).
struct InspectorView: View {
    @EnvironmentObject var store: PlannerStore

    var body: some View {
        NavigationStack {
            Group {
                switch store.selection {
                case .light(let id)?:
                    if let b = store.lightBinding(id) { LightInspector(light: b) }
                case .object(let id)?:
                    if let b = store.objectBinding(id) { ObjectInspector(object: b) }
                case nil:
                    EmptyView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Hotovo") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }
        }
    }
}

struct LightInspector: View {
    @EnvironmentObject var store: PlannerStore
    @Binding var light: Light

    var body: some View {
        let plan = store.plan, fx = plan.fixture(for: light)
        Form {
            Section {
                HStack {
                    Text("#\(light.number) \(fx.name)").font(.headline)
                    Spacer()
                    Chip(text: fx.type.rawValue, tint: .orange)
                }
                Picker("Role", selection: $light.role) {
                    ForEach(LightRole.allCases) { Text($0.title).tag($0) }
                }
                if let g = store.geometry.first(where: { $0.light.id == light.id }) {
                    Text(stats(g)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Pozice") {
                NumberRow(title: "X (m)", value: $light.x, range: -3...(plan.room.w + 3), unit: "m")
                NumberRow(title: "Y (m)", value: $light.y, range: -3...(plan.room.d + 3), unit: "m")
                NumberRow(title: "Z výška (m)", value: $light.z, range: 0...plan.room.h, unit: "m")
                Button("Přichytit na truss") { store.snapToTruss(light.id) }
            }
            Section("Směr (kam svítí)") {
                NumberRow(title: "Pan", value: $light.pan, range: -180...180, step: 1, unit: "°")
                NumberRow(title: "Tilt", value: $light.tilt, range: 0...150, step: 1, unit: "°")
                Button("Na střed pódia (hruď)") { light.aim(at: plan.chestPoint) }
                Button("Svisle dolů") { light.tilt = 0 }
            }
            Section("Světlo") {
                NumberRow(title: "Úhel kuželu", value: $light.angle, range: fx.minAngle...fx.maxAngle, step: 0.5, unit: "°")
                NumberRow(title: "Intenzita", value: $light.intensity, range: 0...100, step: 1, unit: "%")
                ColorPicker("Barva (RGB)", selection: Binding(get: { light.color.color }, set: { light.color = RGB($0) }), supportsOpacity: false)
            }
            Section {
                Button("Duplikovat") { store.duplicateSelected() }
                Button("Smazat", role: .destructive) { store.deleteSelected() }
            }
        }
    }

    private func stats(_ g: LightGeometry) -> String {
        let e = g.illuminance(at: g.axis.p, normal: g.axis.surface.normal)
        let ground = g.rim.filter { $0.surface.onGround }
        let dia = ground.count > 3 ? (ground.map { hypot($0.p.x - g.axis.p.x, $0.p.y - g.axis.p.y) }.max() ?? 0) * 2 : 0
        return "Dopad na ose \(round2(g.axis.t)) m · E ≈ \(Int(e)) lx · stopa Ø ≈ \(round2(dia)) m"
    }
}

struct ObjectInspector: View {
    @EnvironmentObject var store: PlannerStore
    @Binding var object: StageObject

    var body: some View {
        let room = store.plan.room
        Form {
            Section {
                TextField("Název", text: $object.name)
                ColorPicker("Barva", selection: Binding(get: { object.color.color }, set: { object.color = RGB($0) }), supportsOpacity: false)
            }
            Section("Poloha a rozměry") {
                NumberRow(title: "X (m)", value: $object.x, range: 0...room.w, step: 0.05, unit: "m")
                NumberRow(title: "Y (m)", value: $object.y, range: 0...room.d, step: 0.05, unit: "m")
                NumberRow(title: "Zvednutí", value: $object.lift, range: 0...3, step: 0.05, unit: "m")
                if object.kind == .box {
                    NumberRow(title: "Šířka", value: $object.w, range: 0.1...6, step: 0.05, unit: "m")
                    NumberRow(title: "Hloubka", value: $object.d, range: 0.1...6, step: 0.05, unit: "m")
                } else {
                    NumberRow(title: "Poloměr", value: $object.r, range: 0.05...2, step: 0.05, unit: "m")
                }
                NumberRow(title: "Výška", value: $object.h, range: 0.1...4, step: 0.05, unit: "m")
            }
            Section { Button("Smazat", role: .destructive) { store.deleteSelected() } }
        }
    }
}
