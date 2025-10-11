import SwiftUI

// Bottom tab bar with 4 screens
struct MainTabView: View {
    @EnvironmentObject var vm: SleepVM
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Dashboard (main screen)
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
            
            // Tab 2: Trends (charts)
            TrendsView()
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(1)
            
            // Tab 3: Timeline (visual bars)
            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
                .tag(2)
            
            // Tab 4: Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            // Request HealthKit authorization if not already done
            if !vm.hkAuthorized {
                vm.requestHKAuth()
            }
        }
    }
}

// Preview for Xcode
#Preview {
    MainTabView()
        .environmentObject(SleepVM())
}
