//
//  MainTabView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI

// Bottom tab bar with 4 screens
struct MainTabView: View {
    @ObservedObject var vm: SleepVM
    
    var body: some View {
        TabView {
            // Tab 1: Dashboard (main screen)
            DashboardView(vm: vm)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
            
            // Tab 2: Trends (charts)
            TrendsView(vm: vm)
                .tabItem {
                    Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                }
            
            // Tab 3: Timeline (visual bars)
            TimelineView(vm: vm)
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
            
            // Tab 4: Settings
            SettingsView(vm: vm)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}

// Preview for Xcode
#Preview {
    MainTabView(vm: SleepVM())
}
