import SwiftUI
import HealthKit
import UserNotifications

// Main brain of the app - handles all data and logic
@MainActor
final class SleepVM: ObservableObject {
    // Data the app shows
    @Published var nights: [SleepNight] = []
    @Published var settings = SleepSettings()
    @Published var hkAuthorized = false
    @Published var lastUpdate: Date?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Private stuff for HealthKit
    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private var anchor: HKQueryAnchor?
    
    // Motion detection
    let motionManager = MotionManager()
    @Published var inferredCandidates: [InferredSleepCandidate] = []
    
    init() {
        loadData()
        setupDayChangeObserver()
        
        // Fetch fresh data on app launch if authorized
        Task {
            if hkAuthorized {
                await runAnchoredFetch()
            }
        }
    }
    
    // MARK: - Save & Load Data
    
    private func loadData() {
        // Load settings
        if let data = UserDefaults.standard.data(forKey: "settings"),
           let decoded = try? JSONDecoder().decode(SleepSettings.self, from: data) {
            settings = decoded
        }
        
        // Load nights
        if let data = UserDefaults.standard.data(forKey: "nights"),
           let decoded = try? JSONDecoder().decode([SleepNight].self, from: data) {
            nights = decoded.sorted { $0.date > $1.date }
            print("📱 Loaded \(nights.count) nights from cache")
        }
        
        // Load HealthKit anchor
        if let data = UserDefaults.standard.data(forKey: "anchor"),
           let decoded = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) {
            anchor = decoded
            print("⚓ Loaded HealthKit anchor")
        }
    }
    
    private func saveSettings() {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "settings")
        }
    }
    
    private func saveNights() {
        if let encoded = try? JSONEncoder().encode(nights) {
            UserDefaults.standard.set(encoded, forKey: "nights")
            print("💾 Saved \(nights.count) nights to cache")
        }
    }
    
    private func saveAnchor(_ newAnchor: HKQueryAnchor?) {
        guard let newAnchor = newAnchor else { return }
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true) {
            UserDefaults.standard.set(encoded, forKey: "anchor")
            anchor = newAnchor
            print("⚓ Saved HealthKit anchor")
        }
    }
    
    // MARK: - HealthKit Permission
    
    func requestHKAuth() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit not available"
            return
        }
        
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            errorMessage = "Sleep Analysis type unavailable"
            return
        }
        
        let readTypes: Set<HKObjectType> = [sleepType]
        let writeTypes: Set<HKSampleType> = [sleepType]
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { [weak self] success, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if success {
                    print("✅ HealthKit authorization granted")
                    self.hkAuthorized = true
                    self.startObservers()
                    await self.runAnchoredFetch()
                    
                    // Start motion monitoring
                    self.motionManager.requestAuthorization()
                } else {
                    print("❌ HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                    self.errorMessage = error?.localizedDescription ?? "Authorization failed"
                }
            }
        }
    }
    
    // MARK: - Watch for New Sleep Data
    
    private func startObservers() {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        // Watch for new sleep data
        observerQuery = HKObserverQuery(sampleType: sleepType, predicate: nil) { [weak self] _, _, _ in
            Task { @MainActor in
                await self?.runAnchoredFetch()
            }
        }
        
        if let query = observerQuery {
            healthStore.execute(query)
            // Enable background delivery
            healthStore.enableBackgroundDelivery(for: sleepType, frequency: .immediate) { success, error in
                if success {
                    print("✅ Background delivery enabled")
                } else {
                    print("❌ Background delivery failed: \(error?.localizedDescription ?? "Unknown")")
                }
            }
        }
    }
    
    // Get new sleep data from HealthKit
    func runAnchoredFetch() async {
        isLoading = true
        defer { isLoading = false }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let endDate = Date()
        // Fetch last 180 days (6 months) of data
        let startDate = Calendar.current.date(byAdding: .day, value: -180, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
        print("🔄 Fetching sleep data from \(startDate) to \(endDate)")
        
        await withCheckedContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: sleepType,
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, newAnchor, error in
                Task { @MainActor in
                    guard let self = self else {
                        continuation.resume()
                        return
                    }
                    
                    if let error = error {
                        print("❌ Error fetching sleep data: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                    } else if let samples = samples as? [HKCategorySample] {
                        print("✅ Fetched \(samples.count) sleep samples")
                        self.processSamples(samples)
                    }
                    
                    self.saveAnchor(newAnchor)
                    self.lastUpdate = Date()
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }
    
    // Force a complete resync from HealthKit
    func forceFullResync() {
        print("🔄 Forcing full resync - clearing anchor and cache...")
        
        // Clear the anchor to fetch everything again
        anchor = nil
        UserDefaults.standard.removeObject(forKey: "anchor")
        
        // Clear existing nights
        nights = []
        
        // Fetch all data fresh from HealthKit
        Task {
            await runAnchoredFetch()
        }
    }
    
    // Debug: Check what's in HealthKit
    func debugHealthKitData() {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: nil, limit: 20, sortDescriptors: [sortDescriptor]) { query, results, error in
            if let samples = results as? [HKCategorySample] {
                Task { @MainActor in
                    print("🔍 DEBUG: Found \(samples.count) most recent sleep samples in HealthKit:")
                    for (index, sample) in samples.enumerated() {
                        let value = HKCategoryValueSleepAnalysis(rawValue: sample.value)
                        let type = self.sleepTypeString(value)
                        print("  \(index + 1). [\(type)] Start: \(sample.startDate), End: \(sample.endDate)")
                    }
                }
            } else {
                print("❌ DEBUG: No samples found or error: \(error?.localizedDescription ?? "unknown")")
            }
        }
        
        healthStore.execute(query)
    }
    
    private func sleepTypeString(_ value: HKCategoryValueSleepAnalysis?) -> String {
        guard let value = value else { return "Unknown" }
        switch value {
        case .inBed: return "In Bed"
        case .asleepUnspecified: return "Asleep"
        case .asleepCore: return "Core Sleep"
        case .asleepDeep: return "Deep Sleep"
        case .asleepREM: return "REM Sleep"
        case .awake: return "Awake"
        @unknown default: return "Unknown"
        }
    }
    
    // MARK: - Turn HealthKit Data into Nights
    
    private func processSamples(_ samples: [HKCategorySample]) {
        print("🔍 Processing \(samples.count) samples...")
        
        var nightsDict: [Date: [HKCategorySample]] = [:]
        
        // Group samples by night
        for sample in samples {
            let nightDate = getNightAnchor(for: sample.startDate)
            nightsDict[nightDate, default: []].append(sample)
        }
        
        print("📅 Found \(nightsDict.keys.count) unique nights")
        
        var newNights: [SleepNight] = []
        
        // Calculate stats for each night
        for (nightDate, samples) in nightsDict {
            var inBedTotal: TimeInterval = 0
            var asleepTotal: TimeInterval = 0
            var bedtime: Date?
            var wake: Date?
            
            for sample in samples.sorted(by: { $0.startDate < $1.startDate }) {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                
                // Update bedtime and wake time
                if bedtime == nil || sample.startDate < bedtime! {
                    bedtime = sample.startDate
                }
                if wake == nil || sample.endDate > wake! {
                    wake = sample.endDate
                }
                
                // Time in bed
                if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                    inBedTotal += duration
                }
                // Time asleep (all sleep stages)
                else if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    asleepTotal += duration
                    inBedTotal += duration  // Sleep time counts as in-bed time
                }
            }
            
            // Calculate midpoint
            var midpoint: Date?
            if let bt = bedtime, let wk = wake {
                midpoint = Date(timeIntervalSince1970: bt.timeIntervalSince1970 + (wk.timeIntervalSince(bt) / 2))
            }
            
            // Calculate efficiency
            let efficiency = (inBedTotal > 0 && asleepTotal > 0) ? (asleepTotal / inBedTotal) * 100 : nil
            
            newNights.append(SleepNight(
                date: nightDate,
                inBed: inBedTotal > 0 ? inBedTotal : nil,
                asleep: asleepTotal > 0 ? asleepTotal : nil,
                bedtime: bedtime,
                wake: wake,
                midpoint: midpoint,
                efficiency: efficiency
            ))
        }
        
        print("📊 Created \(newNights.count) new nights")
        
        // Merge with existing nights
        var existingDict = Dictionary(uniqueKeysWithValues: nights.map { ($0.date, $0) })
        for night in newNights {
            existingDict[night.date] = night
        }
        
        nights = Array(existingDict.values).sorted { $0.date > $1.date }
        
        print("💾 Total nights after merge: \(nights.count)")
        if let oldest = nights.last?.date, let newest = nights.first?.date {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            print("📅 Date range: \(formatter.string(from: oldest)) to \(formatter.string(from: newest))")
        }
        
        saveNights()
    }
    
    // Figure out which night a time belongs to
    private func getNightAnchor(for date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // Before noon = yesterday's night
        if hour < 12 {
            return calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: date)!)
        } else {
            return calendar.startOfDay(for: date)
        }
    }
    
    // Refresh when day changes
    private func setupDayChangeObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.runAnchoredFetch()
            }
        }
    }
    
    // MARK: - Calculate Sleep Stats
    
    // How consistent is sleep timing? (lower is better)
    func getMidpointStdDev() -> Double? {
        let recentNights = Array(nights.prefix(7))
        let midpoints = recentNights.compactMap { $0.midpoint?.timeIntervalSince1970 }
        guard midpoints.count >= 3 else { return nil }
        
        let mean = midpoints.reduce(0, +) / Double(midpoints.count)
        let variance = midpoints.map { pow($0 - mean, 2) }.reduce(0, +) / Double(midpoints.count)
        return sqrt(variance) / 3600.0
    }
    
    // Difference between weekday and weekend sleep
    func getSocialJetlag() -> Double? {
        let twoWeeks = Array(nights.prefix(14))
        var weekdayMidpoints: [TimeInterval] = []
        var weekendMidpoints: [TimeInterval] = []
        
        for night in twoWeeks {
            guard let midpoint = night.midpoint else { continue }
            let weekday = Calendar.current.component(.weekday, from: night.date)
            
            if weekday == 1 || weekday == 7 {  // Saturday or Sunday
                weekendMidpoints.append(midpoint.timeIntervalSince1970)
            } else {
                weekdayMidpoints.append(midpoint.timeIntervalSince1970)
            }
        }
        
        guard !weekdayMidpoints.isEmpty && !weekendMidpoints.isEmpty else { return nil }
        
        let weekdayAvg = weekdayMidpoints.reduce(0, +) / Double(weekdayMidpoints.count)
        let weekendAvg = weekendMidpoints.reduce(0, +) / Double(weekendMidpoints.count)
        
        return abs(weekendAvg - weekdayAvg) / 3600.0
    }
    
    // Percent of nights within target schedule
    func getRegularityIndex() -> Double? {
        let recentNights = Array(nights.prefix(30))
        guard !recentNights.isEmpty else { return nil }
        
        let targetMidpoint = getTargetMidpoint()
        let tolerance = TimeInterval(settings.midpointToleranceMinutes * 60)
        
        let inWindow = recentNights.filter { night in
            guard let midpoint = night.midpoint else { return false }
            return abs(midpoint.timeIntervalSince1970 - targetMidpoint) <= tolerance
        }.count
        
        return (Double(inWindow) / Double(recentNights.count)) * 100
    }
    
    private func getTargetMidpoint() -> TimeInterval {
        let calendar = Calendar.current
        
        // Get current date to anchor the calculation
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        
        // Create bedtime and wake time for today
        guard let bedHour = settings.targetBedtime.hour,
              let bedMinute = settings.targetBedtime.minute,
              let wakeHour = settings.targetWake.hour,
              let wakeMinute = settings.targetWake.minute else {
            return 0
        }
        
        var bedtimeDate = calendar.date(bySettingHour: bedHour, minute: bedMinute, second: 0, of: todayStart)!
        var wakeDate = calendar.date(bySettingHour: wakeHour, minute: wakeMinute, second: 0, of: todayStart)!
        
        // If wake time is earlier than bedtime (crosses midnight), add a day to wake time
        if wakeDate <= bedtimeDate {
            wakeDate = calendar.date(byAdding: .day, value: 1, to: wakeDate)!
        }
        
        // Calculate midpoint
        let midpoint = bedtimeDate.timeIntervalSince1970 + (wakeDate.timeIntervalSince(bedtimeDate) / 2)
        
        return midpoint
    }
    
    // Check if a specific night is on schedule
    func isOnSchedule(_ night: SleepNight) -> Bool {
        guard let midpoint = night.midpoint else { return false }
        let targetMidpoint = getTargetMidpoint()
        let tolerance = TimeInterval(settings.midpointToleranceMinutes * 60)
        return abs(midpoint.timeIntervalSince1970 - targetMidpoint) <= tolerance
    }
    
    // Get deviation from target in minutes
    func getMidpointDeviation(_ night: SleepNight) -> Int? {
        guard let midpoint = night.midpoint else { return nil }
        let targetMidpoint = getTargetMidpoint()
        let differenceInMinutes = (midpoint.timeIntervalSince1970 - targetMidpoint) / 60
        return Int(differenceInMinutes)
    }
    
    // MARK: - Settings & Notifications
    
    func updateSettings(_ newSettings: SleepSettings) {
        settings = newSettings
        saveSettings()
        
        if settings.remindersEnabled {
            scheduleReminders()
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["bedtimeReminder"])
        }
    }
    
    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
        saveSettings()
    }
    
    func requestNotificationPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("✅ Notification permission granted")
                if settings.remindersEnabled {
                    scheduleReminders()
                }
            } else {
                print("⚠️ Notification permission denied")
            }
        } catch {
            print("❌ Error requesting notification permission: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func scheduleReminders() {
        guard settings.remindersEnabled,
              let hour = settings.targetBedtime.hour,
              let minute = settings.targetBedtime.minute else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Bedtime Reminder"
        content.body = "Time to start winding down for bed"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = max(0, minute - 30)  // 30 minutes before bedtime
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "bedtimeReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("✅ Bedtime reminder scheduled for \(hour):\(minute - 30)")
            }
        }
    }
    
    // MARK: - Export Data
    
    func exportCSV() -> String {
        var csv = "Date,Time in Bed (hours),Time Asleep (hours),Efficiency (%),Bedtime,Wake Time,Midpoint,On Schedule\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        for night in nights.sorted(by: { $0.date < $1.date }) {
            let dateStr = dateFormatter.string(from: night.date)
            let inBedStr = night.inBed != nil ? String(format: "%.2f", night.inBed! / 3600.0) : "n/a"
            let asleepStr = night.asleep != nil ? String(format: "%.2f", night.asleep! / 3600.0) : "n/a"
            let efficiencyStr = night.efficiency != nil ? String(format: "%.1f", night.efficiency!) : "n/a"
            let bedtimeStr = night.bedtime != nil ? timeFormatter.string(from: night.bedtime!) : "n/a"
            let wakeStr = night.wake != nil ? timeFormatter.string(from: night.wake!) : "n/a"
            let midpointStr = night.midpoint != nil ? timeFormatter.string(from: night.midpoint!) : "n/a"
            let onScheduleStr = isOnSchedule(night) ? "Yes" : "No"
            
            csv += "\(dateStr),\(inBedStr),\(asleepStr),\(efficiencyStr),\(bedtimeStr),\(wakeStr),\(midpointStr),\(onScheduleStr)\n"
        }
        
        return csv
    }
    
    func clearAllData() {
        nights = []
        saveNights()
        anchor = nil
        UserDefaults.standard.removeObject(forKey: "anchor")
        lastUpdate = nil
        print("🗑️ Cleared all cached data")
    }
    
    // MARK: - Write Inferred Sleep to HealthKit
    
    /// Save an inferred sleep session to HealthKit
    func saveInferredSleep(candidate: InferredSleepCandidate, duration: TimeInterval) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("❌ Sleep type unavailable")
            return
        }
        
        let endDate: Date
        let startDate: Date
        
        if candidate.type == .sleepOnset {
            startDate = candidate.timestamp
            endDate = candidate.timestamp.addingTimeInterval(duration)
        } else {
            endDate = candidate.timestamp
            startDate = candidate.timestamp.addingTimeInterval(-duration)
        }
        
        // Create metadata to mark this as app-inferred
        let metadata: [String: Any] = [
            HKMetadataKeyWasUserEntered: true,
            "AppInferred": true,
            "InferenceSource": candidate.source.rawValue,
            "Confidence": candidate.confidence
        ]
        
        let sleepSample = HKCategorySample(
            type: sleepType,
            value: HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            start: startDate,
            end: endDate,
            metadata: metadata
        )
        
        healthStore.save(sleepSample) { success, error in
            if success {
                print("✅ Saved inferred sleep to HealthKit: \(startDate) to \(endDate)")
                Task { @MainActor in
                    await self.runAnchoredFetch()
                }
            } else {
                print("❌ Failed to save inferred sleep: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }
    
    /// Check for gaps in sleep data and suggest inferred candidates
    func findSleepGaps() async {
        print("🔍 Checking for sleep data gaps...")
        
        // Look at last 7 days
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: endDate)!
        
        // Get motion candidates for this period
        await withCheckedContinuation { continuation in
            motionManager.queryHistoricalMotion(from: startDate, to: endDate) { [weak self] candidates in
                guard let self = self else {
                    continuation.resume()
                    return
                }
                
                Task { @MainActor in
                    // Filter candidates to only show for nights with missing data
                    let filteredCandidates = candidates.filter { candidate in
                        let nightDate = self.getNightAnchor(for: candidate.timestamp)
                        let hasData = self.nights.contains { $0.date == nightDate }
                        return !hasData
                    }
                    
                    self.inferredCandidates = filteredCandidates
                    print("💡 Found \(filteredCandidates.count) inferred sleep candidates")
                    
                    continuation.resume()
                }
            }
        }
    }
    
    deinit {
        if let query = observerQuery {
            healthStore.stop(query)
        }
    }
}
