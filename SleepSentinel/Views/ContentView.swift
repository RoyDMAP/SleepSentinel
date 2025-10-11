//
//  ContentView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI

// Main starting point - decides what screen to show
struct ContentView: View {
    @EnvironmentObject var vm: SleepVM
    
    var body: some View {
        Group {
            // First time? Show welcome screens
            if !vm.settings.hasCompletedOnboarding {
                OnboardingView()
            }
            // Already set up? Show main app
            else {
                MainTabView()
            }
        }
        // Show error messages if something goes wrong
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

// Preview for Xcode
#Preview {
    ContentView()
        .environmentObject(SleepVM())
}
