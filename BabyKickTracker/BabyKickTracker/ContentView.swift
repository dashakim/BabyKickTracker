import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: "timer")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }
        }
        .accentColor(.pink)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
