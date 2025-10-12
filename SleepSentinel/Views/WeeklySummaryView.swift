import SwiftUI
import Charts

struct WeeklySummaryView: View {
    @EnvironmentObject var vm: SleepVM
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if vm.nights.isEmpty {
                        emptyStateView
                    } else {
                        // Week comparison header
                        weekComparisonHeader
                        
                        // Key metrics comparison
                        metricsComparison
                        
                        // Sleep quality trend
                        qualityTrendChart
                        
                        // Day by day comparison
                        dayByDayComparison
                        
                        // Best and worst nights
                        bestWorstNights
                    }
                }
                .padding()
            }
            .navigationTitle("Weekly Summary")
        }
    }
    
    // MARK: - Week Comparison Header
    
    private var weekComparisonHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("This Week")
                        .font(.headline)
                    Text(weekDateRange(offset: 0))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Last Week")
                        .font(.headline)
                    Text(weekDateRange(offset: -7))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Metrics Comparison
    
    private var metricsComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Key Metrics")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                comparisonCard(
                    title: "Avg Sleep",
                    thisWeek: getWeeklyAverage(offset: 0),
                    lastWeek: getWeeklyAverage(offset: -7),
                    format: "%.1fh",
                    higherIsBetter: true
                )
                
                comparisonCard(
                    title: "Avg Efficiency",
                    thisWeek: getWeeklyEfficiency(offset: 0),
                    lastWeek: getWeeklyEfficiency(offset: -7),
                    format: "%.0f%%",
                    higherIsBetter: true
                )
                
                comparisonCard(
                    title: "Consistency",
                    thisWeek: getWeeklyConsistency(offset: 0),
                    lastWeek: getWeeklyConsistency(offset: -7),
                    format: "±%.1fh",
                    higherIsBetter: false
                )
                
                comparisonCard(
                    title: "On Schedule",
                    thisWeek: getWeeklyRegularity(offset: 0),
                    lastWeek: getWeeklyRegularity(offset: -7),
                    format: "%.0f%%",
                    higherIsBetter: true
                )
            }
        }
    }
    
    private func comparisonCard(title: String, thisWeek: Double?, lastWeek: Double?, format: String, higherIsBetter: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let thisWeek = thisWeek {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: format, thisWeek))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let lastWeek = lastWeek {
                        let change = thisWeek - lastWeek
                        let isImprovement = higherIsBetter ? change > 0 : change < 0
                        
                        HStack(spacing: 2) {
                            Image(systemName: change > 0 ? "arrow.up" : change < 0 ? "arrow.down" : "minus")
                                .font(.caption2)
                            Text(String(format: format, abs(change)))
                                .font(.caption)
                        }
                        .foregroundStyle(isImprovement ? .green : change == 0 ? .secondary : .red)
                    }
                }
            } else {
                Text("n/a")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Quality Trend Chart
    
    private var qualityTrendChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Quality Trend")
                .font(.headline)
            
            let twoWeeks = Array(vm.nights.prefix(14).reversed())
            
            Chart(twoWeeks) { night in
                if let efficiency = night.efficiency {
                    LineMark(
                        x: .value("Date", night.date),
                        y: .value("Efficiency", efficiency)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Date", night.date),
                        y: .value("Efficiency", efficiency)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let percent = value.as(Double.self) {
                            Text("\(Int(percent))%")
                        }
                    }
                    AxisGridLine()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Day by Day Comparison
    
    private var dayByDayComparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Day by Day")
                .font(.headline)
            
            ForEach(0..<7, id: \.self) { dayOffset in
                let thisWeekNight = getNight(daysAgo: dayOffset)
                let lastWeekNight = getNight(daysAgo: dayOffset + 7)
                
                dayComparisonRow(
                    dayName: dayName(daysAgo: dayOffset),
                    thisWeek: thisWeekNight,
                    lastWeek: lastWeekNight
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func dayComparisonRow(dayName: String, thisWeek: SleepNight?, lastWeek: SleepNight?) -> some View {
        HStack {
            Text(dayName)
                .font(.subheadline)
                .frame(width: 60, alignment: .leading)
            
            // This week
            if let thisWeek = thisWeek, let asleep = thisWeek.asleep {
                Text(formatHours(asleep))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
            } else {
                Text("-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            
            Image(systemName: "arrow.left.arrow.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            // Last week
            if let lastWeek = lastWeek, let asleep = lastWeek.asleep {
                Text(formatHours(asleep))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            } else {
                Text("-")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Best and Worst Nights
    
    private var bestWorstNights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week's Highlights")
                .font(.headline)
            
            let thisWeekNights = getWeekNights(offset: 0)
            
            if let best = thisWeekNights.max(by: { ($0.asleep ?? 0) < ($1.asleep ?? 0) }) {
                highlightCard(
                    title: "Best Night",
                    night: best,
                    icon: "star.fill",
                    color: .green
                )
            }
            
            if let worst = thisWeekNights.min(by: { ($0.asleep ?? 0) < ($1.asleep ?? 0) }) {
                highlightCard(
                    title: "Needs Improvement",
                    night: worst,
                    icon: "moon.zzz.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func highlightCard(title: String, night: SleepNight, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(night.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let asleep = night.asleep {
                    Text(formatHours(asleep))
                        .font(.headline)
                }
            }
            
            Spacer()
            
            if let efficiency = night.efficiency {
                VStack {
                    Text("\(Int(efficiency))%")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("Efficiency")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            Text("No Weekly Data")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Weekly summaries will appear once you have at least a week of sleep data")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .padding(40)
    }
    
    // MARK: - Helper Functions
    
    private func weekDateRange(offset: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(byAdding: .day, value: offset, to: today)!
        let endOfWeek = calendar.date(byAdding: .day, value: offset + 6, to: today)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
    }
    
    private func getWeekNights(offset: Int) -> [SleepNight] {
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.date(byAdding: .day, value: offset, to: today)!
        let endDate = calendar.date(byAdding: .day, value: offset + 7, to: today)!
        
        return vm.nights.filter { $0.date >= startDate && $0.date < endDate }
    }
    
    private func getWeeklyAverage(offset: Int) -> Double? {
        let nights = getWeekNights(offset: offset)
        let sleepTimes = nights.compactMap { $0.asleep }
        guard !sleepTimes.isEmpty else { return nil }
        return sleepTimes.reduce(0, +) / Double(sleepTimes.count) / 3600.0
    }
    
    private func getWeeklyEfficiency(offset: Int) -> Double? {
        let nights = getWeekNights(offset: offset)
        let efficiencies = nights.compactMap { $0.efficiency }
        guard !efficiencies.isEmpty else { return nil }
        return efficiencies.reduce(0, +) / Double(efficiencies.count)
    }
    
    private func getWeeklyConsistency(offset: Int) -> Double? {
        let nights = getWeekNights(offset: offset)
        let midpoints = nights.compactMap { $0.midpoint?.timeIntervalSince1970 }
        guard midpoints.count >= 3 else { return nil }
        
        let mean = midpoints.reduce(0, +) / Double(midpoints.count)
        let variance = midpoints.map { pow($0 - mean, 2) }.reduce(0, +) / Double(midpoints.count)
        return sqrt(variance) / 3600.0
    }
    
    private func getWeeklyRegularity(offset: Int) -> Double? {
        let nights = getWeekNights(offset: offset)
        guard !nights.isEmpty else { return nil }
        
        let onSchedule = nights.filter { vm.isOnSchedule($0) }.count
        return (Double(onSchedule) / Double(nights.count)) * 100
    }
    
    private func getNight(daysAgo: Int) -> SleepNight? {
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        let targetDayStart = calendar.startOfDay(for: targetDate)
        
        return vm.nights.first { calendar.startOfDay(for: $0.date) == targetDayStart }
    }
    
    private func dayName(daysAgo: Int) -> String {
        let calendar = Calendar.current
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private func formatHours(_ interval: TimeInterval) -> String {
        let hours = interval / 3600.0
        return String(format: "%.1fh", hours)
    }
}

#Preview {
    NavigationStack {
        WeeklySummaryView()
            .environmentObject(SleepVM())
    }
}
