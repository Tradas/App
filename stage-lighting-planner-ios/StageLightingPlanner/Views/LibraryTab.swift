import SwiftUI

struct LibraryTab: View {
    @EnvironmentObject var store: PlannerStore
    @State private var query = ""
    @State private var type: FixtureType?
    @State private var showingCustom = false

    private var items: [Fixture] {
        store.plan.allFixtures.filter {
            (type == nil || $0.type == type) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            List(items) { fx in
                FixtureRow(fixture: fx, used: store.plan.used(fx.id)) { store.addFromLibrary(fx, count: $0) }
            }
            .searchable(text: $query, prompt: "Hledat svítidlo")
            .navigationTitle("Knihovna")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Vše") { type = nil }
                        ForEach(FixtureType.allCases) { t in Button(t.rawValue) { type = t } }
                    } label: { Label(type?.rawValue ?? "Typ", systemImage: "line.3.horizontal.decrease.circle") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCustom = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingCustom) { CustomFixtureSheet() }
        }
    }
}

struct FixtureRow: View {
    let fixture: Fixture
    let used: Int
    let onAdd: (Int) -> Void
    @State private var qty = 1

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(fixture.name).font(.subheadline.bold())
                HStack(spacing: 6) {
                    Chip(text: fixture.type.rawValue, tint: .orange)
                    Text("\(Int(fixture.watt)) W · \(fixture.minAngle == fixture.maxAngle ? "\(Int(fixture.angle))" : "\(Int(fixture.minAngle))–\(Int(fixture.maxAngle))")°")
                    Text("použito \(used)/\(fixture.stock)").foregroundStyle(used > fixture.stock ? Color.red : Color.secondary)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Stepper("", value: $qty, in: 1...40).labelsHidden().fixedSize()
            Text("\(qty)×").font(.caption).frame(width: 28)
            Button { onAdd(qty) } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                .buttonStyle(.borderless)
        }
    }
}

struct CustomFixtureSheet: View {
    @EnvironmentObject var store: PlannerStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var type = FixtureType.par
    @State private var tech = LampTech.led
    @State private var watt = 200.0
    @State private var minA = 10.0
    @State private var angle = 25.0
    @State private var maxA = 45.0
    @State private var stock = 4

    var body: some View {
        NavigationStack {
            Form {
                TextField("Název", text: $name)
                Picker("Typ", selection: $type) { ForEach(FixtureType.allCases) { Text($0.rawValue).tag($0) } }
                Picker("Technologie", selection: $tech) { ForEach(LampTech.allCases, id: \.self) { Text($0.title).tag($0) } }
                NumberRow(title: "Příkon", value: $watt, range: 10...3000, step: 10, unit: "W")
                NumberRow(title: "Úhel min", value: $minA, range: 1...120, step: 1, unit: "°")
                NumberRow(title: "Úhel výchozí", value: $angle, range: 1...120, step: 1, unit: "°")
                NumberRow(title: "Úhel max", value: $maxA, range: 1...120, step: 1, unit: "°")
                Stepper("Počet ks: \(stock)", value: $stock, in: 1...200)
            }
            .navigationTitle("Vlastní světlo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Zrušit") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Přidat") {
                        let lo = min(minA, maxA), hi = max(minA, maxA)
                        store.plan.customFixtures.append(Fixture(id: "custom-\(UUID().uuidString)", name: name, type: type, watt: watt,
                                                                 angle: clamp(angle, lo, hi), minAngle: lo, maxAngle: hi, stock: stock, tech: tech))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
