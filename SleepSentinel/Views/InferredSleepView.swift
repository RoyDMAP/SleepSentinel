import SwiftUI

struct InferredSleepView: View {
    @EnvironmentObject var vm: SleepVM
    @State private var selectedCandidate: InferredSleepCandidate?
    @State private var sleepDuration: Double = 8.0 // hours
    @State private var showingSaveSheet = false
    @State private var isScanning = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Info card
                    infoCard
                    
                    // Find gaps button
                    Button(action: {
                        isScanning = true
                        Task {
                            await vm.findSleepGaps()
                            isScanning = false
                        }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("Scan for Missing Sleep Data")
                            Spacer()
                            if isScanning {
                                ProgressView()
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isScanning)
                    .padding(.horizontal)
                    
                    // Motion monitoring status
                    statusCard
                    
                    // Candidates list
                    if vm.inferredCandidates.isEmpty {
                        emptyStateView
                    } else {
                        candidatesList
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Inferred Sleep")
            .sheet(item: $selectedCandidate) { candidate in
                candidateDetailSheet(candidate)
            }
        }
    }
    
    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .font(.title2)
                    .foregroundStyle(.purple)
                Text("Motion-Based Detection")
                    .font(.headline)
            }
            
            Text("SleepSentinel uses your device's motion sensors to detect when you might have fallen asleep or woken up. This helps fill gaps when HealthKit data is unavailable.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("These are suggestions only - you can review and accept them to add to your sleep history.")
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private var statusCard: some View {
        HStack {
            Image(systemName: vm.motionManager.isMonitoring ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .foregroundStyle(vm.motionManager.isMonitoring ? .green : .gray)
            
            Text("Motion Monitoring")
                .fontWeight(.medium)
            
            Spacer()
            
            Text(vm.motionManager.isMonitoring ? "Active" : "Inactive")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(vm.motionManager.isMonitoring ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .foregroundStyle(vm.motionManager.isMonitoring ? .green : .gray)
                .clipShape(Capsule())
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private var candidatesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Found \(vm.inferredCandidates.count) Candidates")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(vm.inferredCandidates) { candidate in
                candidateRow(candidate)
            }
        }
    }
    
    private func candidateRow(_ candidate: InferredSleepCandidate) -> some View {
        Button(action: {
            selectedCandidate = candidate
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: candidate.type == .sleepOnset ? "moon.fill" : "sun.max.fill")
                            .foregroundStyle(candidate.type == .sleepOnset ? .blue : .orange)
                        
                        Text(candidate.type.rawValue)
                            .font(.headline)
                    }
                    
                    Text(candidate.timestamp, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Text(candidate.timestamp, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.medium")
                            .font(.caption)
                        Text("Confidence: \(Int(candidate.confidence * 100))%")
                            .font(.caption)
                    }
                    .foregroundStyle(.purple)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "moon.stars")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("No Candidates Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Tap 'Scan for Missing Sleep Data' to check for nights where motion data might fill gaps in your sleep tracking")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .padding(40)
    }
    
    private func candidateDetailSheet(_ candidate: InferredSleepCandidate) -> some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Event Type")
                        Spacer()
                        Text(candidate.type.rawValue)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Detected At")
                        Spacer()
                        Text(candidate.timestamp, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(candidate.timestamp, style: .time)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Confidence")
                        Spacer()
                        Text("\(Int(candidate.confidence * 100))%")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Source")
                        Spacer()
                        Text(candidate.source.rawValue)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Detection Details")
                }
                
                Section {
                    VStack(spacing: 12) {
                        Text("Estimated Sleep Duration")
                            .font(.subheadline)
                        
                        HStack {
                            Text("\(Int(sleepDuration)) hours")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Slider(value: $sleepDuration, in: 4...12, step: 0.5)
                    }
                } header: {
                    Text("Configure Sleep Session")
                } footer: {
                    Text("This will create a sleep session of approximately \(Int(sleepDuration)) hours based on the detected \(candidate.type.rawValue.lowercased()) time.")
                }
                
                Section {
                    Button(action: {
                        saveInferredSleep(candidate)
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept & Save to HealthKit")
                            Spacer()
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        selectedCandidate = nil
                    }) {
                        HStack {
                            Spacer()
                            Text("Dismiss")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Review Candidate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedCandidate = nil
                    }
                }
            }
        }
    }
    
    private func saveInferredSleep(_ candidate: InferredSleepCandidate) {
        let durationInSeconds = sleepDuration * 3600
        vm.saveInferredSleep(candidate: candidate, duration: durationInSeconds)
        
        // Remove from candidates list
        if let index = vm.inferredCandidates.firstIndex(where: { $0.id == candidate.id }) {
            vm.inferredCandidates.remove(at: index)
        }
        
        selectedCandidate = nil
    }
}

#Preview {
    NavigationStack {
        InferredSleepView()
            .environmentObject(SleepVM())
    }
}
