import SwiftUI

struct ContentView: View {
    init() {
        // Customize tab bar with frosted glass effect
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Customize navigation bar with frosted glass effect
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(light: UIColor(red: 0.20, green: 0.18, blue: 0.22, alpha: 1.0), dark: UIColor(red: 1.0, green: 0.71, blue: 0.82, alpha: 1.0)),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(light: UIColor(red: 0.20, green: 0.18, blue: 0.22, alpha: 1.0), dark: UIColor(red: 1.0, green: 0.71, blue: 0.82, alpha: 1.0))
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
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

extension UIColor {
    convenience init(light: UIColor, dark: UIColor) {
        self.init { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return dark
            default:
                return light
            }
        }
    }
}
