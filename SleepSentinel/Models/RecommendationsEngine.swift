//
//  RecommendationsEngine.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/11/25.
//

import Foundation

// Generates personalized sleep recommendations based on user's data
class RecommendationsEngine {
    
    // Generate recommendations based on sleep patterns
    static func generateRecommendations(
        nights: [SleepNight],
        settings: SleepSettings,
        isOnScheduleCheck: (SleepNight) -> Bool
    ) -> [SleepRecommendation] {
        var recommendations: [SleepRecommendation] = []
        
        guard !nights.isEmpty else {
            return [SleepRecommendation(
                id: UUID(),
                title: "Start Tracking",
                description: "Begin tracking your sleep to receive personalized recommendations",
                category: .general,
                priority: .low,
                actionable: false
            )]
        }
        
        let recentNights = Array(nights.prefix(14))
        
        // Check sleep duration
        if let durationRec = checkSleepDuration(nights: recentNights) {
            recommendations.append(durationRec)
        }
        
        // Check consistency
        if let consistencyRec = checkConsistency(nights: recentNights) {
            recommendations.append(consistencyRec)
        }
        
        // Check schedule adherence
        if let scheduleRec = checkScheduleAdherence(nights: recentNights, isOnSchedule: isOnScheduleCheck) {
            recommendations.append(scheduleRec)
        }
        
        // Check sleep efficiency
        if let efficiencyRec = checkSleepEfficiency(nights: recentNights) {
            recommendations.append(efficiencyRec)
        }
        
        // Check social jetlag
        if let jetlagRec = checkSocialJetlag(nights: recentNights) {
            recommendations.append(jetlagRec)
        }
        
        // Check bedtime patterns
        if let bedtimeRec = checkBedtimePatterns(nights: recentNights, settings: settings) {
            recommendations.append(bedtimeRec)
        }
        
        // Sort by priority
        recommendations.sort { $0.priority.rawValue > $1.priority.rawValue }
        
        // If everything is good, add positive reinforcement
        if recommendations.isEmpty || recommendations.allSatisfy({ $0.priority == .low }) {
            recommendations.insert(SleepRecommendation(
                id: UUID(),
                title: "Great Sleep Habits! 🌟",
                description: "Your sleep patterns are excellent. Keep maintaining your current routine!",
                category: .positive,
                priority: .low,
                actionable: false
            ), at: 0)
        }
        
        return recommendations
    }
    
    // MARK: - Individual Checks
    
    private static func checkSleepDuration(nights: [SleepNight]) -> SleepRecommendation? {
        let sleepTimes = nights.compactMap { $0.asleep }
        guard !sleepTimes.isEmpty else { return nil }
        
        let avgHours = sleepTimes.reduce(0, +) / Double(sleepTimes.count) / 3600.0
        
        if avgHours < 6.5 {
            return SleepRecommendation(
                id: UUID(),
                title: "Increase Sleep Duration",
                description: "You're averaging \(String(format: "%.1f", avgHours)) hours of sleep. Aim for 7-9 hours for optimal health and performance.",
                category: .duration,
                priority: .high,
                actionable: true,
                action: "Try going to bed 30 minutes earlier tonight"
            )
        } else if avgHours > 9.5 {
            return SleepRecommendation(
                id: UUID(),
                title: "Monitor Oversleeping",
                description: "You're averaging \(String(format: "%.1f", avgHours)) hours. While rest is important, consistently sleeping over 9 hours may indicate underlying issues.",
                category: .duration,
                priority: .medium,
                actionable: true,
                action: "Consider consulting a healthcare provider if fatigue persists"
            )
        }
        
        return nil
    }
    
    private static func checkConsistency(nights: [SleepNight]) -> SleepRecommendation? {
        let midpoints = nights.compactMap { $0.midpoint?.timeIntervalSince1970 }
        guard midpoints.count >= 5 else { return nil }
        
        let mean = midpoints.reduce(0, +) / Double(midpoints.count)
        let variance = midpoints.map { pow($0 - mean, 2) }.reduce(0, +) / Double(midpoints.count)
        let stdDev = sqrt(variance) / 3600.0
        
        if stdDev > 2.0 {
            return SleepRecommendation(
                id: UUID(),
                title: "Improve Sleep Consistency",
                description: "Your sleep timing varies by ±\(String(format: "%.1f", stdDev)) hours. Consistent sleep schedules improve sleep quality.",
                category: .consistency,
                priority: .high,
                actionable: true,
                action: "Try to go to bed and wake up at the same time every day, even on weekends"
            )
        } else if stdDev > 1.0 {
            return SleepRecommendation(
                id: UUID(),
                title: "Maintain Sleep Routine",
                description: "Your sleep timing varies by ±\(String(format: "%.1f", stdDev)) hours. A bit more consistency could help.",
                category: .consistency,
                priority: .medium,
                actionable: true,
                action: "Set a consistent bedtime alarm to improve your routine"
            )
        }
        
        return nil
    }
    
    private static func checkScheduleAdherence(nights: [SleepNight], isOnSchedule: (SleepNight) -> Bool) -> SleepRecommendation? {
        let onScheduleCount = nights.filter(isOnSchedule).count
        let percentage = (Double(onScheduleCount) / Double(nights.count)) * 100
        
        if percentage < 50 {
            return SleepRecommendation(
                id: UUID(),
                title: "Align with Target Schedule",
                description: "You're only on schedule \(Int(percentage))% of the time. Sticking to your target sleep times can improve sleep quality.",
                category: .schedule,
                priority: .high,
                actionable: true,
                action: "Review your target bedtime and make it realistic for your lifestyle"
            )
        } else if percentage < 75 {
            return SleepRecommendation(
                id: UUID(),
                title: "Improve Schedule Adherence",
                description: "You're on schedule \(Int(percentage))% of the time. You're doing well, but there's room for improvement.",
                category: .schedule,
                priority: .medium,
                actionable: true,
                action: "Try winding down 1 hour before your target bedtime"
            )
        }
        
        return nil
    }
    
    private static func checkSleepEfficiency(nights: [SleepNight]) -> SleepRecommendation? {
        let efficiencies = nights.compactMap { $0.efficiency }
        guard !efficiencies.isEmpty else { return nil }
        
        let avgEfficiency = efficiencies.reduce(0, +) / Double(efficiencies.count)
        
        if avgEfficiency < 75 {
            return SleepRecommendation(
                id: UUID(),
                title: "Improve Sleep Efficiency",
                description: "Your average sleep efficiency is \(Int(avgEfficiency))%. This means you're spending too much time awake in bed.",
                category: .efficiency,
                priority: .high,
                actionable: true,
                action: "Only use your bed for sleep. If you can't fall asleep after 20 minutes, get up and do a calm activity"
            )
        } else if avgEfficiency < 85 {
            return SleepRecommendation(
                id: UUID(),
                title: "Good Sleep Efficiency",
                description: "Your sleep efficiency is \(Int(avgEfficiency))%. A bit of improvement could help you feel more rested.",
                category: .efficiency,
                priority: .low,
                actionable: true,
                action: "Avoid screens 30 minutes before bed to improve sleep onset"
            )
        }
        
        return nil
    }
    
    private static func checkSocialJetlag(nights: [SleepNight]) -> SleepRecommendation? {
        var weekdayMidpoints: [TimeInterval] = []
        var weekendMidpoints: [TimeInterval] = []
        
        for night in nights {
            guard let midpoint = night.midpoint else { continue }
            let weekday = Calendar.current.component(.weekday, from: night.date)
            
            if weekday == 1 || weekday == 7 {
                weekendMidpoints.append(midpoint.timeIntervalSince1970)
            } else {
                weekdayMidpoints.append(midpoint.timeIntervalSince1970)
            }
        }
        
        guard !weekdayMidpoints.isEmpty && !weekendMidpoints.isEmpty else { return nil }
        
        let weekdayAvg = weekdayMidpoints.reduce(0, +) / Double(weekdayMidpoints.count)
        let weekendAvg = weekendMidpoints.reduce(0, +) / Double(weekendMidpoints.count)
        let jetlag = abs(weekendAvg - weekdayAvg) / 3600.0
        
        if jetlag > 2.0 {
            return SleepRecommendation(
                id: UUID(),
                title: "Reduce Weekend Sleep Shifts",
                description: "Your weekend sleep differs by \(String(format: "%.1f", jetlag)) hours from weekdays. This 'social jetlag' can affect your energy levels.",
                category: .socialJetlag,
                priority: .high,
                actionable: true,
                action: "Try to keep weekend sleep times within 1 hour of your weekday schedule"
            )
        } else if jetlag > 1.0 {
            return SleepRecommendation(
                id: UUID(),
                title: "Mild Social Jetlag",
                description: "Your weekend sleep differs by \(String(format: "%.1f", jetlag)) hours. Reducing this gap could improve Monday energy.",
                category: .socialJetlag,
                priority: .medium,
                actionable: true,
                action: "Avoid sleeping in more than 1 hour on weekends"
            )
        }
        
        return nil
    }
    
    private static func checkBedtimePatterns(nights: [SleepNight], settings: SleepSettings) -> SleepRecommendation? {
        let lateBedtimes = nights.filter { night in
            guard let bedtime = night.bedtime else { return false }
            let hour = Calendar.current.component(.hour, from: bedtime)
            return hour >= 1 && hour < 6 // Between 1 AM and 6 AM
        }
        
        if lateBedtimes.count > nights.count / 2 {
            return SleepRecommendation(
                id: UUID(),
                title: "Earlier Bedtime Recommended",
                description: "You're frequently going to bed after 1 AM. Earlier bedtimes align better with natural circadian rhythms.",
                category: .bedtime,
                priority: .medium,
                actionable: true,
                action: "Gradually shift your bedtime 15 minutes earlier each week"
            )
        }
        
        return nil
    }
}

// MARK: - Data Models

struct SleepRecommendation: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let category: RecommendationCategory
    let priority: RecommendationPriority
    let actionable: Bool
    var action: String? = nil
    
    enum RecommendationCategory: String {
        case duration = "Duration"
        case consistency = "Consistency"
        case schedule = "Schedule"
        case efficiency = "Efficiency"
        case socialJetlag = "Social Jetlag"
        case bedtime = "Bedtime"
        case positive = "Positive"
        case general = "General"
        
        var icon: String {
            switch self {
            case .duration: return "clock.fill"
            case .consistency: return "chart.line.uptrend.xyaxis"
            case .schedule: return "calendar.badge.clock"
            case .efficiency: return "gauge.high"
            case .socialJetlag: return "airplane"
            case .bedtime: return "moon.fill"
            case .positive: return "star.fill"
            case .general: return "info.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .duration: return "blue"
            case .consistency: return "purple"
            case .schedule: return "orange"
            case .efficiency: return "green"
            case .socialJetlag: return "red"
            case .bedtime: return "indigo"
            case .positive: return "yellow"
            case .general: return "gray"
            }
        }
    }
    
    enum RecommendationPriority: Int {
        case high = 3
        case medium = 2
        case low = 1
        
        var label: String {
            switch self {
            case .high: return "High Priority"
            case .medium: return "Medium Priority"
            case .low: return "Good Job"
            }
        }
    }
}
