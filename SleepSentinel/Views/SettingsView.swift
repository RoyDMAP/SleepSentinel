import SwiftUI

// Settings screen - change preferences and manage data
struct SettingsView: View {
    @EnvironmentObject var vm: SleepVM
    @State private var showingExport = false
    @State private var showingClearAlert = false
    @State private var exportedCSV = ""
    @State private var targetBedtimeDate = Date()
    @State private var targetWakeDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Sleep Goals
                Section {
                    // Pick your bedtime
                    DatePicker("Target Bedtime", selection: $targetBedtimeDate, displayedComponents: .hourAndMinute)
                        .onChange(of: targetBedtimeDate) { newValue in
                            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                            var newSettings = vm.settings
                            newSettings.targetBedtime = components
                            vm.updateSettings(newSettings)
                        }
                    
                    // Pick your wake time
                    DatePicker("Target Wake Time", selection: $targetWakeDate, displayedComponents: .hourAndMinute)
                        .onChange(of: targetWakeDate) { newValue in
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
                        Task {
                            await vm.runAnchoredFetch()
                        }
                    }) {
                        HStack {
                            Image(systemName: vm.isLoading ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                                .foregroundStyle(.blue)
                            Text("Refresh Sleep Data")
                            Spacer()
                            if vm.isLoading {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(vm.isLoading)
                    
                    // Force full resync
                    Button(action: {
                        vm.forceFullResync()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundStyle(.orange)
                            Text("Force Full Resync")
                        }
                    }
                    .disabled(vm.isLoading)
                    
                    // Debug button
                    Button(action: {
                        vm.debugHealthKitData()
                    }) {
                        HStack {
                            Image(systemName: "ladybug")
                                .foregroundStyle(.purple)
                            Text("Debug HealthKit Data")
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
                        showingClearAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Data")
                        }
                    }
                } header: {
                    Text("Data Management")
                } footer: {
                    Text("Export your sleep data for external analysis, or clear all cached data from the app. Your HealthKit data will not be affected.")
                }
                
                // MARK: - Privacy & Info
                Section {
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
                    Text("SleepSentinel - Your personal sleep tracking companion")
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
                    vm.clearAllData()
                    Task {
                        await vm.runAnchoredFetch()
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
