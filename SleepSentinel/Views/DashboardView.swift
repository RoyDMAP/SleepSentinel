//
//  DashboardView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI

// Main dashboard - shows your sleep summary
struct DashboardView: View {
    @ObservedObject var vm: SleepVM
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Loading spinner
                    if vm.isLoading {
                        ProgressView("Loading...")
                    }
                    
                    // Show last night's sleep or empty message
                    if let lastNight = vm.nights.first {
                        lastNightCard(lastNight)
                    } else {
                        emptyStateCard
                    }
                    
                    // 4 metric boxes
                    metricsGrid
                    
                    // List of recent nights
                    recentNightsList
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Refresh button
                    Button {
                        Task { await vm.runAnchoredFetch() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
    
    // MARK: - Last Night Card
    
    private func lastNightCard(_ night: SleepNight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last Night")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            HStack(alignment: .top) {
                // Sleep time
                VStack(alignment: .leading) {
                    Text(formatDuration(night.asleep))
                        .font(.system(size: 48, weight: .bold))
                    Text("asleep")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                // Efficiency circle
                if let efficiency = night.efficiency {
                    VStack {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: efficiency / 100)
                                .stroke(efficiencyColor(efficiency), lineWidth: 8)
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 70, height: 70)
                        .overlay {
                            Text("\(Int(efficiency))%")
                                .fontWeight(.semibold)
                        }
                        Text("Efficiency")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Empty State
    
    private var emptyStateCard: some View {
        VStack(spacing: 15) {
            Image(systemName: "bed.double.fill")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("No Sleep Data Yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Sleep data from your device will appear here")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Metrics Grid (4 boxes)
    
    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
            metricCard("Consistency", value: vm.getMidpointStdDev().map { String(format: "±%.1fh", $0) } ?? "n/a", icon: "clock", color: .blue)
            metricCard("Social Jetlag", value: vm.getSocialJetlag().map { String(format: "%.1fh", $0) } ?? "n/a", icon: "calendar", color: .purple)
            metricCard("Regularity", value: vm.getRegularityIndex().map { String(format: "%.0f%%", $0) } ?? "n/a", icon: "checkmark.circle", color: .green)
            metricCard("Avg Sleep", value: averageSleep(), icon: "moon.fill", color: .indigo)
        }
    }
    
    private func metricCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Recent Nights List
    
    private var recentNightsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Nights")
                .font(.headline)
            ForEach(Array(vm.nights.prefix(7))) { night in
                nightRow(night)
            }
        }
    }
    
    private func nightRow(_ night: SleepNight) -> some View {
        HStack {
            // Date and times
            VStack(alignment: .leading, spacing: 4) {
                Text(night.date, style: .date)
                    .fontWeight(.medium)
                if let bedtime = night.bedtime, let wake = night.wake {
                    Text("\(bedtime, style: .time) - \(wake, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            
            // Sleep duration
            if let asleep = night.asleep {
                Text(formatDuration(asleep))
                    .fontWeight(.semibold)
            }
            
            // Efficiency badge
            if let efficiency = night.efficiency {
                Text("\(Int(efficiency))%")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Helper Functions
    
    // Turn seconds into "7:30" format
    private func formatDuration(_ interval: TimeInterval?) -> String {
        guard let interval = interval else { return "n/a" }
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%d:%02d", hours, minutes)
    }
    
    // Color based on efficiency score
    private func efficiencyColor(_ efficiency: Double) -> Color {
        efficiency >= 85 ? .green : efficiency >= 70 ? .orange : .red
    }
    
    // Calculate average sleep for last 7 nights
    private func averageSleep() -> String {
        let recent = Array(vm.nights.prefix(7))
        let sleepTimes = recent.compactMap { $0.asleep }
        guard !sleepTimes.isEmpty else { return "n/a" }
        let avg = sleepTimes.reduce(0, +) / Double(sleepTimes.count)
        return String(format: "%.1fh", avg / 3600.0)
    }
}

// Preview for Xcode
#Preview {
    DashboardView(vm: SleepVM())
}
