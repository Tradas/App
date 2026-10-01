import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: PlannerStore

    var body: some View {
        TabView(selection: $store.tab) {
            PlanTab().tabItem { Label("Plán", systemImage: "square.grid.3x3.topleft.filled") }.tag(AppTab.plan)
            SceneTab().tabItem { Label("Scéna", systemImage: "cube.transparent") }.tag(AppTab.scene)
            LibraryTab().tabItem { Label("Knihovna", systemImage: "books.vertical") }.tag(AppTab.library)
            LightsTab().tabItem { Label("Světla", systemImage: "lightbulb.led") }.tag(AppTab.lights)
            AnalysisTab().tabItem { Label("Analýza", systemImage: "chart.bar.doc.horizontal") }.tag(AppTab.analysis)
        }
        .tint(.orange)
    }
}
