import SwiftUI

struct ContentView: View {
    init() {
        // Customize tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            SessionsView()
                .tabItem {
                    Label("Sessions", systemImage: "clock.fill")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "chart.xyaxis.line")
                }
        }
        .accentColor(Theme.primary)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
