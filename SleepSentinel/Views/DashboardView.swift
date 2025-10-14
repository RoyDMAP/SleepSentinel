import SwiftUI

// Main dashboard - shows your sleep summary
struct DashboardView: View {
    @EnvironmentObject var vm: SleepVM
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Loading spinner
                    if vm.isLoading {
                        ProgressView("Loading...")
                            .padding()
                    }
                    
                    // Show last night's sleep or empty message
                    if let lastNight = vm.nights.first {
                        lastNightCard(lastNight)
                    } else if !vm.isLoading {
                        emptyStateCard
                    }
                    
                    // 4 metric boxes
                    if !vm.nights.isEmpty {
                        metricsGrid
                        
                        // Quick access cards
                        quickAccessCards
                        
                        // List of recent nights
                        recentNightsList
                    }
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
                        Image(systemName: vm.isLoading ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                            .symbolEffect(.rotate, isActive: vm.isLoading)
                    }
                    .disabled(vm.isLoading)
                }
            }
            .refreshable {
                await vm.runAnchoredFetch()
            }
        }
    }
    
    // MARK: - Last Night Card
    
    private func lastNightCard(_ night: SleepNight) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Last Night")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Show quality badge
                qualityBadge(night.quality)
            }
            
            HStack(alignment: .top) {
                // Sleep time
                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDuration(night.asleep))
                        .font(.system(size: 48, weight: .bold))
                    Text("asleep")
                        .foregroundStyle(.secondary)
                    
                    if let bedtime = night.bedtime, let wake = night.wake {
                        Text("\(bedtime, style: .time) - \(wake, style: .time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
                Spacer()
                
                // Efficiency circle
                if let efficiency = night.efficiency {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                            Circle()
                                .trim(from: 0, to: efficiency / 100)
                                .stroke(efficiencyColor(efficiency), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: efficiency)
                        }
                        .frame(width: 80, height: 80)
                        .overlay {
                            Text("\(Int(efficiency))%")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        Text("Efficiency")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Schedule status
            if let deviation = vm.getMidpointDeviation(night) {
                HStack(spacing: 6) {
                    Image(systemName: vm.isOnSchedule(night) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(vm.isOnSchedule(night) ? .green : .orange)
                    Text(scheduleStatusText(deviation: deviation, isOnSchedule: vm.isOnSchedule(night)))
                        .font(.subheadline)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func qualityBadge(_ quality: SleepQuality) -> some View {
        Text(quality.rawValue)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(qualityColor(quality).opacity(0.2))
            .foregroundStyle(qualityColor(quality))
            .clipShape(Capsule())
    }
    
    private func qualityColor(_ quality: SleepQuality) -> Color {
        switch quality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
    
    private func scheduleStatusText(deviation: Int, isOnSchedule: Bool) -> String {
        if isOnSchedule {
            return "On Schedule"
        } else if deviation > 0 {
            return "Later by \(abs(deviation)) min"
        } else {
            return "Earlier by \(abs(deviation)) min"
        }
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
            Text("Sleep data from Apple Health will appear here automatically")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            if !vm.hkAuthorized {
                Button(action: {
                    vm.requestHKAuth()
                }) {
                    Text("Grant Health Access")
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Metrics Grid (4 boxes)
    
    private var metricsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                metricCard("Consistency", value: vm.getMidpointStdDev().map { String(format: "±%.1fh", $0) } ?? "n/a", icon: "clock", color: .blue)
                metricCard("Social Jetlag", value: vm.getSocialJetlag().map { String(format: "%.1fh", $0) } ?? "n/a", icon: "calendar", color: .purple)
                metricCard("Regularity", value: vm.getRegularityIndex().map { String(format: "%.0f%%", $0) } ?? "n/a", icon: "checkmark.circle", color: .green)
                metricCard("Avg Sleep", value: averageSleep(), icon: "moon.fill", color: .indigo)
            }
        }
    }
    
    private func metricCard(_ title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            
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
                NavigationLink(destination: NightDetailView(night: night)) {
                    nightRow(night)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func nightRow(_ night: SleepNight) -> some View {
        HStack {
            // Date and times
            VStack(alignment: .leading, spacing: 4) {
                Text(night.date, style: .date)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if let bedtime = night.bedtime, let wake = night.wake {
                    Text("\(bedtime, style: .time) - \(wake, style: .time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            
            // Sleep duration
            VStack(alignment: .trailing, spacing: 4) {
                if let asleep = night.asleep {
                    Text(formatDuration(asleep))
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
                
                // Efficiency badge
                if let efficiency = night.efficiency {
                    Text("\(Int(efficiency))%")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(efficiencyColor(efficiency).opacity(0.2))
                        .foregroundStyle(efficiencyColor(efficiency))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Quick Access Cards

    private var quickAccessCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Access")
                .font(.headline)
            
            HStack(spacing: 12) {
                NavigationLink(destination: WeeklySummaryView()) {
                    quickAccessCard(
                        icon: "calendar.badge.clock",
                        title: "Weekly Summary",
                        color: .blue
                    )
                }
                
                NavigationLink(destination: InsightsView()) {
                    quickAccessCard(
                        icon: "lightbulb.fill",
                        title: "Insights",
                        color: .yellow
                    )
                }
            }
        }
    }

    private func quickAccessCard(icon: String, title: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        switch efficiency {
        case 85...100: return .green
        case 70..<85: return .blue
        case 50..<70: return .orange
        default: return .red
        }
    }
    
    // Calculate average sleep for last 7 nights
    private func averageSleep() -> String {
        let recent = Array(vm.nights.prefix(7))
        guard !recent.isEmpty else { return "n/a" }
        
        let sleepTimes = recent.compactMap { $0.asleep }
        guard !sleepTimes.isEmpty else { return "n/a" }
        
        let avg = sleepTimes.reduce(0, +) / Double(sleepTimes.count)
        let avgHours = avg / 3600.0
        
        //Guard against weird values
        guard avgHours.isFinite && avgHours >= 0 && avgHours <= 24 else { return "n/a" }
        
        return String(format: "%.1f", avgHours)
    }
}
// Preview for Xcode
#Preview {
    NavigationStack {
        DashboardView()
            .environmentObject(SleepVM())
    }
}
