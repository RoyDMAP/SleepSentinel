//
//  OnboardingView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI

// First-time welcome screens (swipe through 3 pages)
struct OnboardingView: View {
    @EnvironmentObject var vm: SleepVM
    @State private var currentPage = 0
    
    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)      // Page 1
            privacyPage.tag(1)      // Page 2
            permissionsPage.tag(2)  // Page 3
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
    
    // MARK: - Page 1: Welcome
    
    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Moon icon
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            // Title
            Text("Welcome to SleepSentinel")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Description
            Text("Track and improve your sleep with science-backed insights")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            // Next button
            Button("Continue") {
                withAnimation {
                    currentPage = 1
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 50)
        }
        .padding()
    }
    
    // MARK: - Page 2: Privacy
    
    private var privacyPage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Lock shield icon
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            // Title
            Text("Your Privacy Matters")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Privacy promises
            VStack(alignment: .leading, spacing: 12) {
                Label("All data stays on your device", systemImage: "checkmark.circle.fill")
                Label("No cloud sync or tracking", systemImage: "checkmark.circle.fill")
                Label("You control all exports", systemImage: "checkmark.circle.fill")
            }
            .padding()
            
            Spacer()
            
            // Next button
            Button("Continue") {
                withAnimation {
                    currentPage = 2
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, 50)
        }
        .padding()
    }
    
    // MARK: - Page 3: Permissions
    
    private var permissionsPage: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Heart icon
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 80))
                .foregroundStyle(.red)
            
            // Title
            Text("HealthKit Access")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Explanation
            Text("We need access to your sleep data from HealthKit to provide insights")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Spacer()
            
            // Grant access button
            Button("Grant Access") {
                vm.requestHKAuth()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if vm.hkAuthorized {
                        withAnimation {
                            vm.completeOnboarding()
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            
            // Skip button
            Button("Skip for Now") {
                vm.completeOnboarding()
            }
            .foregroundStyle(.secondary)
            .padding(.bottom, 50)
        }
        .padding()
    }
}

// Preview for Xcode
#Preview {
    OnboardingView()  // ← No vm parameter
        .environmentObject(SleepVM())
}
