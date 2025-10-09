//
//  TrendView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI
import Charts

// Trends screen - shows charts of your sleep patterns
struct TrendsView: View {
    @ObservedObject var vm: SleepVM
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Show charts if we have data
                    if !vm.nights.isEmpty {
                        durationChart
                        midpointChart
                    } else {
                        // No data yet
                        Text("No data available")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Trends")
        }
    }
    
    // MARK: - Duration Chart (Bar Chart)
    
    private var durationChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep Duration (30 days)")
                .font(.headline)
            
            // Bar chart showing hours slept each night
            Chart(Array(vm.nights.prefix(30).reversed())) { night in
                BarMark(
                    x: .value("Date", night.date, unit: .day),
                    y: .value("Hours", (night.asleep ?? 0) / 3600.0)
                )
                .foregroundStyle(.blue.gradient)
            }
            .frame(height: 200)
            .chartYAxis {
                // Left side shows hours (0, 2, 4, 6, 8...)
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Midpoint Chart (Line Chart)
    
    private var midpointChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sleep Midpoint (30 days)")
                .font(.headline)
            
            // Line chart showing when the middle of your sleep happens
            Chart(Array(vm.nights.prefix(30).reversed()).filter { $0.midpoint != nil }) { night in
                LineMark(
                    x: .value("Date", night.date, unit: .day),
                    y: .value("Hour", midpointHour(night.midpoint!))
                )
                .foregroundStyle(.purple)
                .interpolationMethod(.catmullRom)  // Smooth curved line
            }
            .frame(height: 200)
            .chartYScale(domain: 0...24)  // 0-24 hours
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Function
    
    // Convert midpoint time to decimal hours (like 3:30 AM = 3.5)
    private func midpointHour(_ date: Date) -> Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(components.hour ?? 0) + Double(components.minute ?? 0) / 60.0
    }
}

// Preview for Xcode
#Preview {
    TrendsView(vm: SleepVM())
}
