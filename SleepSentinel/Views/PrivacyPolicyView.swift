//
//  PrivatePolicyView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI

// Privacy policy screen - explains how we protect your data
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // What this app does with your info
                sectionHeader("Privacy Policy")
                sectionContent("We protect your privacy. Your data never leaves your phone.")
                
                // Everything stays on your phone
                sectionHeader("Local Data Only")
                sectionContent("Your sleep data is saved only on your device. We don't use servers or the cloud.")
                
                // What we read from HealthKit
                sectionHeader("HealthKit Access")
                sectionContent("We only read your sleep data from Apple Health. This helps us show you sleep stats.")
                
                // No spying or tracking
                sectionHeader("No Tracking")
                sectionContent("We don't track what you do, collect personal info, or send data anywhere.")
                
                // You control your data
                sectionHeader("Data Export")
                sectionContent("You can export your sleep data as a file anytime. It stays on your phone until you share it.")
                
                // How to delete everything
                sectionHeader("Data Deletion")
                sectionContent("Delete all your data from Settings anytime. Deleting the app also removes everything.")
            }
            .padding()
        }
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Helper Views
    
    // Bold section title
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .padding(.top, 8)
    }
    
    // Regular text explanation
    private func sectionContent(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

// Preview for Xcode
#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
