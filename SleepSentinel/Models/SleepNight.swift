//
//  SleepNight.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import Foundation

// Stores data for one night of sleep
struct SleepNight: Identifiable, Codable {
    var id = UUID()
    var date: Date              // Night date (e.g., Jan 15)
    var inBed: TimeInterval?    // Time in bed (seconds)
    var asleep: TimeInterval?   // Time asleep (seconds)
    var bedtime: Date?          // When you went to bed
    var wake: Date?             // When you woke up
    var midpoint: Date?         // Middle of your sleep time
    var efficiency: Double?     // Sleep quality (0-100%)
}

// Helper functions
extension SleepNight {
    // Sleep time in hours
    var sleepHours: Double? {
        guard let asleep = asleep else { return nil }
        return asleep / 3600.0
    }
    
    // Formatted sleep time (like "7h 30m")
    var sleepFormatted: String {
        guard let asleep = asleep else { return "n/a" }
        let hours = Int(asleep / 3600)
        let minutes = Int((asleep.truncatingRemainder(dividingBy: 3600)) / 60)
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    // Check if we have all the data
    var isComplete: Bool {
        return bedtime != nil && wake != nil && asleep != nil
    }
    
    // Rate sleep quality
    var quality: SleepQuality {
        guard let efficiency = efficiency else { return .unknown }
        
        switch efficiency {
        case 85...100: return .excellent
        case 70..<85: return .good
        case 50..<70: return .fair
        default: return .poor
        }
    }
}

// Sleep quality levels
enum SleepQuality: String, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    case unknown = "Unknown"
}
