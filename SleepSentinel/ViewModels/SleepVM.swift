//
//  SleepVM.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

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
    
    init() {
        loadData()
        setupDayChangeObserver()
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
        }
        
        // Load HealthKit anchor
        if let data = UserDefaults.standard.data(forKey: "anchor"),
           let decoded = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) {
            anchor = decoded
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
        }
    }
    
    private func saveAnchor(_ newAnchor: HKQueryAnchor?) {
        guard let newAnchor = newAnchor else { return }
        if let encoded = try? NSKeyedArchiver.archivedData(withRootObject: newAnchor, requiringSecureCoding: true) {
            UserDefaults.standard.set(encoded, forKey: "anchor")
            anchor = newAnchor
        }
    }
    
    // MARK: - HealthKit Permission
    
    func requestHKAuth() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit not available"
            return
        }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [sleepType])
            hkAuthorized = true
            startObservers()
            await runAnchoredFetch()
        } catch {
            errorMessage = error.localizedDescription
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
        }
    }
    
    // Get new sleep data from HealthKit
    func runAnchoredFetch() async {
        isLoading = true
        defer { isLoading = false }
        
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -90, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
        
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
                    
                    if let samples = samples as? [HKCategorySample] {
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
    
    // MARK: - Turn HealthKit Data into Nights
    
    private func processSamples(_ samples: [HKCategorySample]) {
        var nightsDict: [Date: [HKCategorySample]] = [:]
        
        // Group samples by night
        for sample in samples {
            let nightDate = getNightAnchor(for: sample.startDate)
            nightsDict[nightDate, default: []].append(sample)
        }
        
        var newNights: [SleepNight] = []
        
        // Calculate stats for each night
        for (nightDate, samples) in nightsDict {
            var inBedTotal: TimeInterval = 0
            var asleepTotal: TimeInterval = 0
            var bedtime: Date?
            var wake: Date?
            
            for sample in samples.sorted(by: { $0.startDate < $1.startDate }) {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                
                // Time in bed
                if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
                    inBedTotal += duration
                    if bedtime == nil || sample.startDate < bedtime! {
                        bedtime = sample.startDate
                    }
                    if wake == nil || sample.endDate > wake! {
                        wake = sample.endDate
                    }
                }
                // Time asleep (all sleep stages)
                else if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                        sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                    asleepTotal += duration
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
        
        // Merge with existing nights
        var existingDict = Dictionary(uniqueKeysWithValues: nights.map { ($0.date, $0) })
        for night in newNights {
            existingDict[night.date] = night
        }
        
        nights = Array(existingDict.values).sorted { $0.date > $1.date }
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
        let bedtimeDate = calendar.date(from: settings.targetBedtime) ?? Date()
        var wakeDate = calendar.date(from: settings.targetWake) ?? Date()
        
        if wakeDate < bedtimeDate {
            wakeDate = calendar.date(byAdding: .day, value: 1, to: wakeDate)!
        }
        
        return bedtimeDate.timeIntervalSince1970 + (wakeDate.timeIntervalSince(bedtimeDate) / 2)
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
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            if granted {
                scheduleReminders()
            }
        } catch {
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
        dateComponents.minute = max(0, minute - 10)  // 10 minutes before bedtime
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "bedtimeReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Export Data
    
    func exportCSV() -> String {
        var csv = "Date,Time in Bed (hours),Time Asleep (hours),Efficiency (%),Bedtime,Wake Time,Midpoint\n"
        
        for night in nights.sorted(by: { $0.date < $1.date }) {
            let formatter = ISO8601DateFormatter()
            let dateStr = formatter.string(from: night.date)
            let inBedStr = night.inBed != nil ? String(format: "%.2f", night.inBed! / 3600.0) : "n/a"
            let asleepStr = night.asleep != nil ? String(format: "%.2f", night.asleep! / 3600.0) : "n/a"
            let efficiencyStr = night.efficiency != nil ? String(format: "%.1f", night.efficiency!) : "n/a"
            let bedtimeStr = night.bedtime != nil ? formatter.string(from: night.bedtime!) : "n/a"
            let wakeStr = night.wake != nil ? formatter.string(from: night.wake!) : "n/a"
            let midpointStr = night.midpoint != nil ? formatter.string(from: night.midpoint!) : "n/a"
            
            csv += "\(dateStr),\(inBedStr),\(asleepStr),\(efficiencyStr),\(bedtimeStr),\(wakeStr),\(midpointStr)\n"
        }
        
        return csv
    }
    
    func clearAllData() {
        nights = []
        saveNights()
        anchor = nil
        UserDefaults.standard.removeObject(forKey: "anchor")
    }
}
