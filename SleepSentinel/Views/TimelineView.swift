//
//  TimelineView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI

// Timeline screen - shows sleep as visual bars (like a calendar)
struct TimelineView: View {
    @ObservedObject var vm: SleepVM
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 15) {
                    // Show bars for last 14 nights
                    if !vm.nights.isEmpty {
                        ForEach(Array(vm.nights.prefix(14))) { night in
                            timelineBar(night)
                        }
                    } else {
                        // No data yet
                        Text("No timeline data")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Timeline")
        }
    }
    
    // MARK: - One Night's Sleep Bar
    
    private func timelineBar(_ night: SleepNight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show the date
            Text(night.date, style: .date)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // The visual bar showing sleep time
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Gray background (full 12-hour bar)
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 30)
                    
                    // Colored bar showing actual sleep
                    if let bedtime = night.bedtime, let wake = night.wake {
                        let startOffset = timeToOffset(bedtime, in: geometry.size.width)
                        let width = duration(from: bedtime, to: wake, in: geometry.size.width)
                        
                        Rectangle()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: width, height: 30)
                            .offset(x: startOffset)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .frame(height: 30)
            
            // Time labels (8 PM to 8 AM)
            HStack {
                Text("8 PM")
                Spacer()
                Text("12 AM")
                Spacer()
                Text("4 AM")
                Spacer()
                Text("8 AM")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Functions
    
    // Convert a time to position on the bar (8 PM = start, 8 AM = end)
    private func timeToOffset(_ date: Date, in width: CGFloat) -> CGFloat {
        let hour = Calendar.current.component(.hour, from: date)
        let minute = Calendar.current.component(.minute, from: date)
        
        var adjustedHour = hour
        // Times after midnight count as next day (so 1 AM becomes 25)
        if hour < 12 {
            adjustedHour += 24
        }
        
        // Calculate hours since 8 PM (20:00)
        let hoursSince8PM = Double(adjustedHour - 20) + Double(minute) / 60.0
        
        // Bar represents 12 hours (8 PM to 8 AM)
        return width * CGFloat(hoursSince8PM / 12.0)
    }
    
    // Calculate how wide the sleep bar should be
    private func duration(from start: Date, to end: Date, in width: CGFloat) -> CGFloat {
        let durationHours = end.timeIntervalSince(start) / 3600.0
        return width * CGFloat(durationHours / 12.0)
    }
}

// Preview for Xcode
#Preview {
    TimelineView(vm: SleepVM())
}
