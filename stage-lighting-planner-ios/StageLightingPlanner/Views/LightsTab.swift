import SwiftUI

/// Seznam světel a objektů na pódiu.
struct LightsTab: View {
    @EnvironmentObject var store: PlannerStore

    var body: some View {
        NavigationStack {
            List {
                Section("Světla (\(store.plan.lights.count))") {
                    if store.plan.lights.isEmpty { Text("Žádná světla. Přidejte je z Knihovny nebo v Analýze použijte Režimy.").foregroundStyle(.secondary) }
                    ForEach(store.plan.lights) { l in
                        let fx = store.plan.fixture(for: l)
                        Button { store.focus(light: l.id) } label: {
                            HStack {
                                Circle().fill(l.color.color).frame(width: 14, height: 14)
                                VStack(alignment: .leading) {
                                    Text("#\(l.number) \(fx.name)").font(.subheadline.bold()).foregroundStyle(.primary)
                                    Text("\(fx.type.rawValue) · \(l.role.title) · z \(round2(l.z)) m").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                ForEach(Array(store.analysis.flags[l.id] ?? []), id: \.self) { f in
                                    Chip(text: flagText(f), tint: f == .glare || f == .burn ? .red : .yellow)
                                }
                            }
                        }
                    }
                    .onDelete { store.plan.lights.remove(atOffsets: $0) }
                }
                Section("Objekty na pódiu") {
                    ForEach(store.plan.objects) { o in
                        Button {
                            store.selection = .object(o.id); store.tab = .plan
                        } label: {
                            HStack {
                                Circle().fill(o.color.color).frame(width: 14, height: 14)
                                Text(o.name).foregroundStyle(.primary)
                                Spacer()
                                Text(o.kind == .box ? "kostka" : "válec").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { store.plan.objects.remove(atOffsets: $0) }
                    Menu("+ Přidat objekt") {
                        Button("🔊 Reproduktor (kostka)") { store.addObject("speaker") }
                        Button("🧊 Kostka") { store.addObject("cube") }
                        Button("🛢️ Válec") { store.addObject("cyl") }
                        Button("🧍 Hudebník (válec)") { store.addObject("person") }
                        Button("▭ Riser") { store.addObject("riser") }
                    }
                }
                if !store.plan.lights.isEmpty {
                    Section { Button("Smazat všechna světla", role: .destructive) { store.plan.lights = []; store.selection = nil } }
                }
            }
            .navigationTitle("Světla a objekty")
        }
    }

    private func flagText(_ f: LightFlag) -> String {
        switch f {
        case .glare: return "oslnění"
        case .burn: return "přepal"
        case .low: return "úhel"
        case .off: return "mimo"
        }
    }
}
