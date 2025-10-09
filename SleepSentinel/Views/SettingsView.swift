//
//  SettingsView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI

// Settings screen - change preferences and manage data
struct SettingsView: View {
    @ObservedObject var vm: SleepVM
    @State private var showingExport = false
    @State private var showingClearAlert = false
    @State private var exportedCSV = ""
    @State private var targetBedtimeDate = Date()
    @State private var targetWakeDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Sleep Goals
                Section("Sleep Goals") {
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
                    
                    // How close you need to be (15-120 minutes)
                    Stepper("Tolerance: \(vm.settings.midpointToleranceMinutes) min", value: Binding(
                        get: { vm.settings.midpointToleranceMinutes },
                        set: { newValue in
                            var newSettings = vm.settings
                            newSettings.midpointToleranceMinutes = newValue
                            vm.updateSettings(newSettings)
                        }
                    ), in: 15...120, step: 15)
                }
                
                // MARK: - Reminders
                Section("Reminders") {
                    // Turn reminders on/off
                    Toggle("Bedtime Reminders", isOn: Binding(
                        get: { vm.settings.remindersEnabled },
                        set: { newValue in
                            var newSettings = vm.settings
                            newSettings.remindersEnabled = newValue
                            vm.updateSettings(newSettings)
                            if newValue {
                                Task { await vm.requestNotificationPermission() }
                            }
                        }
                    ))
                    
                    // Explain what reminders do
                    if vm.settings.remindersEnabled {
                        Text("You'll get a reminder 10 minutes before your bedtime")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Data Management
                Section("Data Management") {
                    // Export button
                    Button("Export Sleep Data (CSV)") {
                        exportedCSV = vm.exportCSV()
                        showingExport = true
                    }
                    
                    // Show when last updated
                    if let lastUpdate = vm.lastUpdate {
                        HStack {
                            Text("Last Updated")
                            Spacer()
                            Text(lastUpdate, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Refresh data button
                    Button("Sync from HealthKit") {
                        Task { await vm.runAnchoredFetch() }
                    }
                    .disabled(vm.isLoading)
                    
                    // Delete everything button (red)
                    Button("Clear All Data", role: .destructive) {
                        showingClearAlert = true
                    }
                }
                
                // MARK: - Privacy & Info
                Section("Privacy & Info") {
                    // Link to privacy policy
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                    
                    // How many nights tracked
                    HStack {
                        Text("Nights Tracked")
                        Spacer()
                        Text("\(vm.nights.count)")
                            .foregroundStyle(.secondary)
                    }
                    
                    // App version
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                // Load current times when screen opens
                if let hour = vm.settings.targetBedtime.hour,
                   let minute = vm.settings.targetBedtime.minute {
                    targetBedtimeDate = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
                }
                if let hour = vm.settings.targetWake.hour,
                   let minute = vm.settings.targetWake.minute {
                    targetWakeDate = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
                }
            }
            .sheet(isPresented: $showingExport) {
                // Show share sheet for CSV
                ShareSheet(activityItems: [exportedCSV])
            }
            .alert("Clear All Data?", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    vm.clearAllData()
                }
            } message: {
                Text("This will delete all your sleep data. You can't undo this.")
            }
        }
    }
}

// Preview for Xcode
#Preview {
    SettingsView(vm: SleepVM())
}
