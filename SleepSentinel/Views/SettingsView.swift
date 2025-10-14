import SwiftUI

// Settings screen - change preferences and manage data
struct SettingsView: View {
    @EnvironmentObject var vm: SleepVM
    @State private var showingExport = false
    @State private var showingClearAlert = false
    @State private var exportedCSV = ""
    @State private var targetBedtimeDate = Date()
    @State private var targetWakeDate = Date()
    @State private var isRefreshing = false
    @State private var isResyncing = false
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Sleep Goals
                Section {
                    // Pick your bedtime
                    DatePicker("Target Bedtime", selection: $targetBedtimeDate, displayedComponents: .hourAndMinute)
                        .onChange(of: targetBedtimeDate) { oldValue, newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            var newSettings = vm.settings
                            newSettings.targetBedtime = components
                            vm.updateSettings(newSettings)
                        }
                    
                    // Pick your wake time
                    DatePicker("Target Wake Time", selection: $targetWakeDate, displayedComponents: .hourAndMinute)
                        .onChange(of: targetWakeDate) { oldValue, newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            var newSettings = vm.settings
                            newSettings.targetWake = components
                            vm.updateSettings(newSettings)
                        }
                    
                    // Show calculated sleep duration
                    HStack {
                        Text("Target Sleep Duration")
                        Spacer()
                        Text(String(format: "%.1f hours", vm.settings.targetSleepHours))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Sleep Schedule")
                } footer: {
                    Text("Set your ideal bedtime and wake time to track schedule consistency")
                }
                
                // MARK: - Schedule Tolerance
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Schedule Tolerance")
                            Spacer()
                            Text("± \(vm.settings.midpointToleranceMinutes) min")
                                .foregroundStyle(.secondary)
                                .fontWeight(.medium)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(vm.settings.midpointToleranceMinutes) },
                                set: { newValue in
                                    var newSettings = vm.settings
                                    newSettings.midpointToleranceMinutes = Int(newValue)
                                    vm.updateSettings(newSettings)
                                }
                            ),
                            in: 15...120,
                            step: 15
                        )
                        .tint(.blue)
                        
                        HStack {
                            Text("15 min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("120 min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Schedule Tolerance")
                } footer: {
                    Text("How many minutes your sleep midpoint can vary and still be considered 'on schedule'")
                }
                
                // MARK: - Reminders
                Section {
                    Toggle(isOn: Binding(
                        get: { vm.settings.remindersEnabled },
                        set: { newValue in
                            var newSettings = vm.settings
                            newSettings.remindersEnabled = newValue
                            vm.updateSettings(newSettings)
                            if newValue {
                                Task { await vm.requestNotificationPermission() }
                            }
                        }
                    )) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.blue)
                            Text("Bedtime Reminders")
                        }
                    }
                    
                    if vm.settings.remindersEnabled {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                                .font(.caption)
                            Text("You'll receive a reminder 30 minutes before your target bedtime")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Notifications")
                }
                
                // MARK: - Data Sync
                Section {
                    // Regular refresh
                    Button(action: {
                        print("🔵 Refresh button tapped")
                        isRefreshing = true
                        Task {
                            await vm.runAnchoredFetch()
                            isRefreshing = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(.blue)
                                .symbolEffect(.rotate, isActive: isRefreshing || vm.isLoading)
                            Text("Refresh Sleep Data")
                            Spacer()
                            if isRefreshing || vm.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRefreshing || vm.isLoading)
                    
                    // Force full resync
                    Button(action: {
                        print("🟠 Force Resync button tapped")
                        isResyncing = true
                        vm.forceFullResync()
                        // Wait a bit for the resync to complete
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                            isResyncing = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.orange)
                                .symbolEffect(.rotate, isActive: isResyncing || vm.isLoading)
                            Text("Force Full Resync")
                            Spacer()
                            if isResyncing || vm.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isResyncing || vm.isLoading)
                    
                    // Debug button - now opens a dedicated view
                    NavigationLink(destination: DebugConsoleView()) {
                        HStack {
                            Image(systemName: "ladybug")
                                .foregroundStyle(.purple)
                            Text("Debug Console")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let lastUpdate = vm.lastUpdate {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            Text("Last Updated")
                            Spacer()
                            Text(lastUpdate, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "heart.text.square")
                            .foregroundStyle(vm.hkAuthorized ? .green : .red)
                        Text("HealthKit Status")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(vm.hkAuthorized ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(vm.hkAuthorized ? "Connected" : "Not Connected")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !vm.hkAuthorized {
                        Button(action: {
                            print("❤️ Connect to HealthKit tapped")
                            vm.requestHKAuth()
                        }) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.red)
                                Text("Connect to HealthKit")
                            }
                        }
                    }
                } header: {
                    Text("Data Sync")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Refresh: Updates with new data from HealthKit")
                        Text("• Force Full Resync: Clears cache and re-fetches all data")
                        Text("• Debug: Check Xcode console to see what's in HealthKit")
                    }
                    .font(.caption)
                }
                
                // MARK: - Export & Delete
                Section {
                    Button(action: {
                        print("📤 Export button tapped")
                        exportedCSV = vm.exportCSV()
                        showingExport = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundStyle(.blue)
                            Text("Export Sleep Data (CSV)")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        print("🗑️ Clear data button tapped")
                        showingClearAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Data")
                        }
                    }
                    
                    // TEMPORARY: Nuclear clear - remove after using once
                    Button(action: {
                        print("💣 NUCLEAR CLEAR - Wiping everything")
                        
                        vm.clearAllData()
                        
                        // Clear UserDefaults
                        UserDefaults.standard.removeObject(forKey: "nights")
                        UserDefaults.standard.removeObject(forKey: "anchor")
                        UserDefaults.standard.removeObject(forKey: "settings")
                        UserDefaults.standard.synchronize()
                        
                        print("✅ All data wiped - App will restart")
                        
                        // Force restart
                        Task {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            exit(0)
                        }
                    }) {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text("NUCLEAR CLEAR & RESTART")
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                            }
                            Text("Use this if Clear All Data doesn't work")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export your sleep data for external analysis, or clear all cached data from the app. Your HealthKit data will not be affected.")
                }
                
                // MARK: - Privacy & Info
                Section {
                    // Inferred Sleep link
                    NavigationLink(destination: InferredSleepView()) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .foregroundStyle(.purple)
                            Text("Inferred Sleep Data")
                        }
                    }
                    
                    NavigationLink(destination: PrivacyPolicyView()) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundStyle(.green)
                            Text("Privacy Policy")
                        }
                    }
                    
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.purple)
                        Text("Nights Tracked")
                        Spacer()
                        Text("\(vm.nights.count)")
                            .foregroundStyle(.secondary)
                            .fontWeight(.medium)
                    }
                    
                    // Show inferred candidates count
                    if !vm.inferredCandidates.isEmpty {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.orange)
                            Text("Pending Candidates")
                            Spacer()
                            Text("\(vm.inferredCandidates.count)")
                                .foregroundStyle(.orange)
                                .fontWeight(.medium)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.blue)
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SleepSentinel - Your personal sleep tracking companion")
                        Text("Created by Roy Dimapilis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadDatesFromSettings()
            }
            .sheet(isPresented: $showingExport) {
                ShareSheet(activityItems: [exportedCSV])
            }
            .alert("Clear All Data?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    print("🗑️ User confirmed clear")
                    vm.clearAllData()
                    // Force a small delay to ensure save completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        Task {
                            await vm.runAnchoredFetch()
                        }
                    }
                }
            } message: {
                Text("This will remove all cached sleep data from the app. Your data in HealthKit will not be affected. This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadDatesFromSettings() {
        if let hour = vm.settings.targetBedtime.hour,
           let minute = vm.settings.targetBedtime.minute {
            targetBedtimeDate = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        }
        
        if let hour = vm.settings.targetWake.hour,
           let minute = vm.settings.targetWake.minute {
            targetWakeDate = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        }
    }
}

// Preview for Xcode
#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(SleepVM())
    }
}
