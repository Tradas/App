import SwiftUI

/// Režimy osvětlení (automatické rozmístění) + skóre a doporučení.
struct AnalysisTab: View {
    @EnvironmentObject var store: PlannerStore

    var body: some View {
        let a = store.analysis
        NavigationStack {
            List {
                Section("Skóre") {
                    HStack(spacing: 18) {
                        gauge("Hloubka", a.depth)
                        gauge("Kontrast", a.contrast)
                        gauge("Bezpečnost", a.safety)
                    }
                    .frame(maxWidth: .infinity)
                    LabeledContent("Průměr na pódiu", value: "\(Int(a.avgLux)) lx")
                    LabeledContent("Rovnoměrnost", value: String(format: "%.2f", a.uniformity))
                    LabeledContent("Pokrytí ≥ 150 lx", value: "\(Int(a.coverage * 100)) %")
                    LabeledContent("Maximum", value: "\(Int(a.maxLux)) lx")
                    LabeledContent("Příkon", value: String(format: "%.1f kW (%d světel)", a.watt / 1000, a.count))
                }
                Section("Doporučení a varování") {
                    ForEach(a.messages) { m in
                        Button {
                            if let id = m.lightID { store.focus(light: id) }
                        } label: {
                            HStack(alignment: .top) {
                                Text(icon(m.severity))
                                Text(m.text).font(.footnote).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            }
                        }
                        .disabled(m.lightID == nil)
                    }
                }
                Section {
                    Toggle("Nahradit stávající světla", isOn: $store.replaceOnPreset)
                    ForEach(Preset.allCases) { p in
                        Button { store.apply(p) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.title).font(.subheadline.bold()).foregroundStyle(p == .full ? Color.orange : Color.primary)
                                Text(p.summary).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: { Text("Režimy osvětlení") } footer: {
                    Text("Hodnoty osvětlenosti jsou orientační (odvozené z příkonu a technologie). Před ostrým nasazením ověřte fotometrická data svítidel.")
                }
            }
            .navigationTitle("Analýza")
        }
    }

    private func gauge(_ title: String, _ v: Int) -> some View {
        VStack {
            Gauge(value: Double(v), in: 0...100) { Text(title) } currentValueLabel: { Text("\(v)") }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(v >= 70 ? Color.green : (v >= 40 ? Color.yellow : Color.red))
            Text(title).font(.caption)
        }
    }

    private func icon(_ s: Severity) -> String {
        switch s {
        case .bad: return "⛔"
        case .warn: return "⚠️"
        case .info: return "ℹ️"
        case .ok: return "✅"
        }
    }
}
