//
//  NightDetailView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/11/25.
//

import SwiftUI

struct NightDetailView: View {
    let night: SleepNight
    @EnvironmentObject var vm: SleepVM
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Main sleep info card
                VStack(alignment: .leading, spacing: 12) {
                    Text(night.date, style: .date)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let bedtime = night.bedtime, let wake = night.wake {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Bedtime")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(bedtime, style: .time)
                                    .font(.title3)
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Wake Time")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(wake, style: .time)
                                    .font(.title3)
                                    .fontWeight(.medium)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                // Sleep metrics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sleep Metrics")
                        .font(.headline)
                    
                    if night.asleep != nil{
                        metricRow(title: "Time Asleep", value: night.sleepFormatted, icon: "moon.fill")
                    }
                    
                    if let inBed = night.inBed {
                        let hours = inBed / 3600.0
                        metricRow(title: "Time in Bed", value: String(format: "%.1fh", hours), icon: "bed.double.fill")
                    }
                    
                    if let efficiency = night.efficiency {
                        metricRow(title: "Sleep Efficiency", value: "\(Int(efficiency))%", icon: "chart.bar.fill")
                    }
                    
                    if let midpoint = night.midpoint {
                        metricRow(title: "Sleep Midpoint", value: midpoint.formatted(date: .omitted, time: .shortened), icon: "clock.fill")
                    }
                }
                
                // Schedule adherence
                if let deviation = vm.getMidpointDeviation(night) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Schedule Status")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: vm.isOnSchedule(night) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(vm.isOnSchedule(night) ? .green : .orange)
                            Text(vm.isOnSchedule(night) ? "On Schedule" : "Off Schedule by \(abs(deviation)) minutes")
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Sleep Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func metricRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 30)
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        NightDetailView(night: SleepNight(
            date: Date(),
            inBed: 28800,
            asleep: 25200,
            bedtime: Date().addingTimeInterval(-28800),
            wake: Date(),
            midpoint: Date().addingTimeInterval(-14400),
            efficiency: 87.5
        ))
        .environmentObject(SleepVM())
    }
}
