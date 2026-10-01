import SwiftUI

/// Hlavní obrazovka: 2D shora, elevace zepředu/z boku a 3D pohled + inspektor ve spodním panelu.
struct PlanTab: View {
    @EnvironmentObject var store: PlannerStore

    private var inspectorShown: Binding<Bool> {
        Binding(get: { store.selection != nil }, set: { if !$0 { store.selection = nil } })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Pohled", selection: $store.viewMode) {
                    ForEach(ViewMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(8)

                ZStack(alignment: .topLeading) {
                    switch store.viewMode {
                    case .top: PlanCanvasView(mode: .top)
                    case .front: PlanCanvasView(mode: .front)
                    case .side: PlanCanvasView(mode: .side)
                    case .threeD:
                        SceneKitView()
                        HStack {
                            camButton("Zepředu", .front)
                            camButton("Z boku", .side)
                            camButton("Shora", .top)
                            camButton("Persp.", .persp)
                        }
                        .padding(8)
                    }
                }
                .background(Color(white: 0.04))

                Text(hint).font(.caption2).foregroundStyle(.secondary).padding(6)
            }
            .navigationTitle("Plánovač osvětlení")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Toggle("Haze", isOn: $store.plan.hazeOn)
                        Toggle("Kužely", isOn: $store.showCones)
                        Toggle("Heatmapa (top)", isOn: $store.showHeat)
                        Toggle("Mřížka 0,25 m", isOn: $store.snap)
                    } label: { Image(systemName: "slider.horizontal.3") }
                }
            }
            .sheet(isPresented: inspectorShown) {
                InspectorView()
                    .presentationDetents([.fraction(0.3), .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.3)))
            }
        }
    }

    private func camButton(_ title: String, _ p: CameraPreset) -> some View {
        Button(title) { store.requestCamera(p) }
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
    }

    private var hint: String {
        switch store.viewMode {
        case .top: return "Přetáhněte světlo (i mimo pódium). Kosočtverec = zaměřovač (kam svítí). Klepnutím vyberete světlo nebo objekt."
        case .front: return "Čelní pohled: tažením měníte X a výšku Z světla."
        case .side: return "Boční pohled: tažením měníte Y a výšku Z. Publikum je vpravo, červená čára = oči diváků."
        case .threeD: return "Tažením otáčíte kameru, štípnutím zoomujete, klepnutím vyberete světlo. Haze zvýrazní kužely."
        }
    }
}
