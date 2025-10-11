//
//  SleepSentinelApp.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI

// Main entry point - this is where the app starts
@main
struct SleepSentinelApp: App {
    @StateObject private var sleepVM = SleepVM()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sleepVM)
                .onAppear {
                    // Call the non-async version
                    sleepVM.requestHKAuth()
                }
        }
    }
}
