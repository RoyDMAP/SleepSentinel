import Foundation
import CoreMotion

// Manages motion detection for inferring sleep onset and wake times
@MainActor
class MotionManager: ObservableObject {
    private let activityManager = CMMotionActivityManager()
    private let motionManager = CMMotionManager()
    
    @Published var inferredSleepCandidates: [InferredSleepCandidate] = []
    @Published var isMonitoring = false
    
    // MARK: - Check Authorization
    
    func requestAuthorization() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("❌ Motion activity not available on this device")
            return
        }
        
        // Start monitoring to trigger permission request
        startMonitoring()
    }
    
    // MARK: - Start/Stop Monitoring
    
    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable() else {
            print("❌ Motion activity not available")
            return
        }
        
        print("🏃 Starting motion monitoring...")
        isMonitoring = true
        
        // Monitor activity changes (walking, stationary, etc.)
        activityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self = self, let activity = activity else { return }
            self.processActivity(activity)
        }
    }
    
    func stopMonitoring() {
        print("⏸️ Stopping motion monitoring")
        activityManager.stopActivityUpdates()
        isMonitoring = false
    }
    
    // MARK: - Process Motion Data
    
    private func processActivity(_ activity: CMMotionActivity) {
        // Look for stationary periods that might indicate sleep
        if activity.stationary {
            detectPotentialSleepOnset(at: activity.startDate)
        }
        
        // Look for movement that might indicate waking up
        if activity.walking || activity.running {
            detectPotentialWake(at: activity.startDate)
        }
    }
    
    // MARK: - Sleep Onset Detection
    
    private func detectPotentialSleepOnset(at date: Date) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // Only consider times between 8 PM and 4 AM as potential sleep onset
        guard (hour >= 20 || hour <= 4) else { return }
        
        // Check if we already have a candidate near this time
        let existingCandidate = inferredSleepCandidates.first { candidate in
            candidate.type == .sleepOnset &&
            abs(candidate.timestamp.timeIntervalSince(date)) < 1800 // Within 30 minutes
        }
        
        guard existingCandidate == nil else { return }
        
        print("😴 Detected potential sleep onset at \(date)")
        
        let candidate = InferredSleepCandidate(
            id: UUID(),
            timestamp: date,
            type: .sleepOnset,
            confidence: 0.7,
            source: .motionActivity
        )
        
        inferredSleepCandidates.append(candidate)
        cleanOldCandidates()
    }
    
    // MARK: - Wake Detection
    
    private func detectPotentialWake(at date: Date) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        
        // Only consider times between 4 AM and 11 AM as potential wake
        guard (hour >= 4 && hour <= 11) else { return }
        
        // Check if we already have a candidate near this time
        let existingCandidate = inferredSleepCandidates.first { candidate in
            candidate.type == .wake &&
            abs(candidate.timestamp.timeIntervalSince(date)) < 1800 // Within 30 minutes
        }
        
        guard existingCandidate == nil else { return }
        
        print("☀️ Detected potential wake at \(date)")
        
        let candidate = InferredSleepCandidate(
            id: UUID(),
            timestamp: date,
            type: .wake,
            confidence: 0.7,
            source: .motionActivity
        )
        
        inferredSleepCandidates.append(candidate)
        cleanOldCandidates()
    }
    
    // MARK: - Historical Query for Gap Filling
    
    func queryHistoricalMotion(from startDate: Date, to endDate: Date, completion: @escaping ([InferredSleepCandidate]) -> Void) {
        guard CMMotionActivityManager.isActivityAvailable() else {
            completion([])
            return
        }
        
        print("🔍 Querying historical motion from \(startDate) to \(endDate)")
        
        activityManager.queryActivityStarting(from: startDate, to: endDate, to: .main) { activities, error in
            if let error = error {
                print("❌ Error querying motion: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let activities = activities else {
                completion([])
                return
            }
            
            print("✅ Found \(activities.count) motion activities")
            
            var candidates: [InferredSleepCandidate] = []
            
            // Analyze activities for sleep patterns
            for activity in activities {
                // Look for extended stationary periods at night
                if activity.stationary {
                    let hour = Calendar.current.component(.hour, from: activity.startDate)
                    if (hour >= 20 || hour <= 4) {
                        candidates.append(InferredSleepCandidate(
                            id: UUID(),
                            timestamp: activity.startDate,
                            type: .sleepOnset,
                            confidence: activity.confidence.rawValue >= 2 ? 0.8 : 0.6,
                            source: .motionActivity
                        ))
                    }
                }
                
                // Look for movement in the morning
                if (activity.walking || activity.running) {
                    let hour = Calendar.current.component(.hour, from: activity.startDate)
                    if (hour >= 4 && hour <= 11) {
                        candidates.append(InferredSleepCandidate(
                            id: UUID(),
                            timestamp: activity.startDate,
                            type: .wake,
                            confidence: activity.confidence.rawValue >= 2 ? 0.8 : 0.6,
                            source: .motionActivity
                        ))
                    }
                }
            }
            
            completion(candidates)
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanOldCandidates() {
        // Remove candidates older than 7 days
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        inferredSleepCandidates.removeAll { $0.timestamp < weekAgo }
    }
    
    // Call this when you're done with motion monitoring
    func cleanup() {
        stopMonitoring()
    }
}

// MARK: - Data Models

struct InferredSleepCandidate: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: SleepEventType
    let confidence: Double // 0.0 to 1.0
    let source: InferenceSource
    var userAccepted: Bool = false
    var userRejected: Bool = false
    
    enum SleepEventType: String, Codable {
        case sleepOnset = "Sleep Onset"
        case wake = "Wake"
    }
    
    enum InferenceSource: String, Codable {
        case motionActivity = "Motion Activity"
        case deviceMotion = "Device Motion"
        case pattern = "Pattern Analysis"
    }
}
