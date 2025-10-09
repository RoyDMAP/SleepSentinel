//
//  SleepSettings.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import Foundation

// Stores user preferences and app settings
struct SleepSettings: Codable {
    var targetBedtime = DateComponents(hour: 23, minute: 0)  // Default: 11:00 PM
    var targetWake = DateComponents(hour: 7, minute: 0)      // Default: 7:00 AM
    var midpointToleranceMinutes = 45                        // ± 45 minutes is "on schedule"
    var remindersEnabled = false                             // Bedtime reminders on/off
    var hasCompletedOnboarding = false                       // First-time setup done?
}

// Helper functions
extension SleepSettings {
    // Get target bedtime as a readable time
    var bedtimeFormatted: String {
        guard let hour = targetBedtime.hour, let minute = targetBedtime.minute else {
            return "11:00 PM"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return formatter.string(from: date)
    }
    
    // Get target wake time as a readable time
    var wakeFormatted: String {
        guard let hour = targetWake.hour, let minute = targetWake.minute else {
            return "7:00 AM"
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return formatter.string(from: date)
    }
    
    // Calculate how many hours of sleep this schedule allows
    var targetSleepHours: Double {
        guard let bedHour = targetBedtime.hour,
              let bedMinute = targetBedtime.minute,
              let wakeHour = targetWake.hour,
              let wakeMinute = targetWake.minute else {
            return 8.0
        }
        
        var bedTimeMinutes = bedHour * 60 + bedMinute
        let wakeTimeMinutes = wakeHour * 60 + wakeMinute
        
        // Handle going to bed before midnight and waking after
        if wakeTimeMinutes < bedTimeMinutes {
            bedTimeMinutes -= 24 * 60
        }
        
        let totalMinutes = wakeTimeMinutes - bedTimeMinutes
        return Double(totalMinutes) / 60.0
    }
    
    // Check if settings are valid
    var isValid: Bool {
        return targetBedtime.hour != nil &&
               targetBedtime.minute != nil &&
               targetWake.hour != nil &&
               targetWake.minute != nil
    }
}
