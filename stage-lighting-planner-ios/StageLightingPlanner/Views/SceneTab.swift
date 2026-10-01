import SwiftUI

/// Rozměry místnosti, pódia a trussu, haze, dveře a okna, import/export plánu.
struct SceneTab: View {
    @EnvironmentObject var store: PlannerStore
    @State private var exporting = false
    @State private var importing = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Místnost") {
                    NumberRow(title: "Šířka X", value: $store.plan.room.w, range: 6...60, step: 0.5, unit: "m")
                    NumberRow(title: "Hloubka Y", value: $store.plan.room.d, range: 6...60, step: 0.5, unit: "m")
                    NumberRow(title: "Výška", value: $store.plan.room.h, range: 3...20, unit: "m")
                }
                Section("Pódium") {
                    NumberRow(title: "Šířka", value: $store.plan.stage.w, range: 2...40, step: 0.5, unit: "m")
                    NumberRow(title: "Hloubka", value: $store.plan.stage.d, range: 2...30, step: 0.5, unit: "m")
                    NumberRow(title: "Výška podia", value: $store.plan.stage.h, range: 0...3, step: 0.05, unit: "m")
                    NumberRow(title: "Střed X", value: $store.plan.stage.x, range: 0...store.plan.room.w, step: 0.25, unit: "m")
                    NumberRow(title: "Od zadní stěny", value: $store.plan.stage.y, range: 0...store.plan.room.d, step: 0.25, unit: "m")
                }
                Section("Truss") {
                    NumberRow(title: "Výška trussu", value: $store.plan.truss.h, range: 2...store.plan.room.h, unit: "m")
                    NumberRow(title: "Přední – odstup", value: $store.plan.truss.frontInset, range: 0...3, unit: "m")
                    NumberRow(title: "Zadní – odstup", value: $store.plan.truss.backInset, range: 0...3, unit: "m")
                }
                Section("Publikum a haze") {
                    NumberRow(title: "Výška očí", value: $store.plan.eyeHeight, range: 0.8...2, unit: "m")
                    Toggle("Haze zapnuto", isOn: $store.plan.hazeOn)
                    NumberRow(title: "Hustota haze", value: $store.plan.hazeDensity, range: 0...1, step: 0.05)
                }
                Section("Dveře a okna") {
                    ForEach($store.plan.openings) { $o in
                        VStack(alignment: .leading) {
                            HStack {
                                Picker("Typ", selection: $o.type) { ForEach(OpeningType.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                                Picker("Stěna", selection: $o.wall) { ForEach(Wall.allCases) { Text($0.rawValue).tag($0) } }
                            }
                            .pickerStyle(.menu)
                            NumberRow(title: "Pozice", value: $o.pos, range: 0...60, unit: "m")
                            NumberRow(title: "Šířka", value: $o.w, range: 0.4...10, unit: "m")
                            NumberRow(title: "Výška", value: $o.h, range: 0.4...6, unit: "m")
                            NumberRow(title: "Parapet", value: $o.sill, range: 0...4, unit: "m")
                        }
                    }
                    .onDelete { store.plan.openings.remove(atOffsets: $0) }
                    Button("+ Dveře") { store.plan.openings.append(Opening(type: .door, wall: .front, pos: 6, w: 1.2, h: 2.1, sill: 0)) }
                    Button("+ Okno") { store.plan.openings.append(Opening(type: .window, wall: .right, pos: 8, w: 2, h: 1.4, sill: 1.2)) }
                }
                Section("Plán") {
                    Button("Exportovat (JSON)") { exporting = true }
                    Button("Importovat (JSON)") { importing = true }
                    Button("Reset", role: .destructive) { store.resetAll() }
                }
            }
            .navigationTitle("Scéna")
        }
        .fileExporter(isPresented: $exporting, document: PlanDocument(plan: store.plan), contentType: .json, defaultFilename: "plan-osvetleni") { _ in }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result { store.importPlan(from: url) }
        }
    }
}
