import SwiftUI
import HealthKit

struct DebugConsoleView: View {
    @EnvironmentObject var vm: SleepVM
    @State private var debugOutput: String = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "ladybug.fill")
                    .foregroundStyle(.purple)
                Text("Debug Console")
                    .font(.headline)
                Spacer()
                Button(action: {
                    debugOutput = ""
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            
            // Console output
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 8) {
                        if debugOutput.isEmpty {
                            Text("Tap 'Run Debug' to see HealthKit diagnostic information")
                                .foregroundStyle(.secondary)
                                .italic()
                                .padding()
                        } else {
                            Text(debugOutput)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                                .id("bottom")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: debugOutput) { _, _ in
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .background(Color.black)
            .foregroundStyle(.green)
            
            // Action buttons
            VStack(spacing: 12) {
                Button(action: {
                    runDebug()
                }) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        }
                        Image(systemName: "play.fill")
                        Text("Run Debug")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .disabled(isLoading)
                
                // NEW: Check Midpoints button
                Button(action: {
                    checkMidpoints()
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Check Midpoints")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        checkHealthKitPermissions()
                    }) {
                        HStack {
                            Image(systemName: "heart.text.square")
                            Text("Check Permissions")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button(action: {
                        checkCachedData()
                    }) {
                        HStack {
                            Image(systemName: "internaldrive")
                            Text("Check Cache")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
        }
        .navigationTitle("Debug Console")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Debug Functions
    
    private func runDebug() {
        isLoading = true
        debugOutput = ""
        
        appendOutput("🔍 ====== HEALTHKIT DEBUG START ======")
        appendOutput("📍 Current date/time: \(Date())")
        appendOutput("📱 App has \(vm.nights.count) nights cached")
        
        if let mostRecent = vm.nights.first {
            appendOutput("📅 Most recent cached night: \(mostRecent.date)")
            if let bedtime = mostRecent.bedtime {
                appendOutput("   Bedtime: \(bedtime)")
            }
            if let wake = mostRecent.wake {
                appendOutput("   Wake: \(wake)")
            }
        } else {
            appendOutput("⚠️ No nights in cache")
        }
        
        appendOutput("\n🔎 Querying HealthKit...")
        
        // Run the actual HealthKit query
        vm.debugHealthKitWithCallback { result in
            DispatchQueue.main.async {
                appendOutput(result)
                appendOutput("\n🔍 ====== HEALTHKIT DEBUG END ======")
                isLoading = false
            }
        }
    }
    
    private func checkMidpoints() {
        debugOutput = ""
        appendOutput("🔍 ====== MIDPOINTS DEBUG ======")
        appendOutput("📊 Checking \(vm.nights.count) nights:")
        
        let calendar = Calendar.current
        let recentNights = Array(vm.nights.prefix(7))
        
        for (index, night) in recentNights.enumerated() {
            appendOutput("\nNight \(index + 1): \(formatDate(night.date))")
            appendOutput("   Bedtime: \(night.bedtime?.description ?? "nil")")
            appendOutput("   Wake: \(night.wake?.description ?? "nil")")
            appendOutput("   Midpoint: \(night.midpoint?.description ?? "nil")")
            
            if let midpoint = night.midpoint {
                let hour = calendar.component(.hour, from: midpoint)
                let minute = calendar.component(.minute, from: midpoint)
                appendOutput("   Midpoint time: \(hour):\(String(format: "%02d", minute))")
            }
            
            if let asleep = night.asleep {
                appendOutput("   Sleep duration: \(String(format: "%.1fh", asleep / 3600.0))")
            }
        }
        
        // Calculate what's breaking
        let midpoints = recentNights.compactMap { $0.midpoint?.timeIntervalSince1970 }
        if midpoints.count >= 3 {
            let mean = midpoints.reduce(0, +) / Double(midpoints.count)
            let variance = midpoints.map { pow($0 - mean, 2) }.reduce(0, +) / Double(midpoints.count)
            let stdDev = sqrt(variance) / 3600.0
            
            appendOutput("\n📊 Midpoint stats:")
            appendOutput("   Count: \(midpoints.count)")
            appendOutput("   Std Dev: \(String(format: "%.2f hours", stdDev))")
            appendOutput("   (Should be 0.5-2h for normal sleep)")
            
            if stdDev > 12 {
                appendOutput("\n⚠️ PROBLEM DETECTED!")
                appendOutput("   Std Dev is \(String(format: "%.1f", stdDev)) hours!")
                appendOutput("   This means midpoints are scattered across days")
                appendOutput("   Possible causes:")
                appendOutput("   - Corrupted timestamps in cache")
                appendOutput("   - Wrong timezone calculations")
                appendOutput("   - Mixed old and new data")
            }
        }
        
        appendOutput("\n🔍 ====== MIDPOINTS DEBUG END ======")
    }
    
    private func checkHealthKitPermissions() {
        debugOutput = ""
        appendOutput("🔐 ====== HEALTHKIT PERMISSIONS CHECK ======")
        appendOutput("📱 HealthKit Available: \(HKHealthStore.isHealthDataAvailable())")
        appendOutput("✅ HealthKit Authorized: \(vm.hkAuthorized ? "YES" : "NO")")
        
        if !vm.hkAuthorized {
            appendOutput("\n⚠️ HealthKit is NOT authorized!")
            appendOutput("💡 Go to Settings and tap 'Connect to HealthKit'")
        } else {
            appendOutput("\n✅ HealthKit is properly connected")
        }
        
        appendOutput("\n📊 Last Update: \(vm.lastUpdate?.description ?? "Never")")
        appendOutput("🔍 ====== PERMISSIONS CHECK END ======")
    }
    
    private func checkCachedData() {
        debugOutput = ""
        appendOutput("💾 ====== CACHED DATA CHECK ======")
        appendOutput("📊 Total nights cached: \(vm.nights.count)")
        
        if vm.nights.isEmpty {
            appendOutput("\n⚠️ No cached data found")
            appendOutput("💡 This could mean:")
            appendOutput("   - No sleep data in HealthKit")
            appendOutput("   - Data was cleared")
            appendOutput("   - First time running the app")
        } else {
            if let oldest = vm.nights.last?.date {
                appendOutput("📅 Oldest night: \(formatDate(oldest))")
            }
            if let newest = vm.nights.first?.date {
                appendOutput("📅 Newest night: \(formatDate(newest))")
            }
            
            appendOutput("\n📊 Last 5 nights:")
            for (index, night) in vm.nights.prefix(5).enumerated() {
                let sleepHours = night.asleep != nil ? String(format: "%.1fh", night.asleep! / 3600.0) : "n/a"
                let efficiency = night.efficiency != nil ? String(format: "%.0f%%", night.efficiency!) : "n/a"
                appendOutput("   \(index + 1). \(formatDate(night.date)): \(sleepHours) sleep, \(efficiency) efficiency")
            }
        }
        
        appendOutput("\n💾 ====== CACHED DATA CHECK END ======")
    }
    
    private func appendOutput(_ text: String) {
        if debugOutput.isEmpty {
            debugOutput = text
        } else {
            debugOutput += "\n" + text
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        DebugConsoleView()
            .environmentObject(SleepVM())
    }
}
