//
//  InsightsView.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/12/25.
//

import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var vm: SleepVM
    @State private var recommendations: [SleepRecommendation] = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header card
                    headerCard
                    
                    // Recommendations list
                    if recommendations.isEmpty {
                        emptyStateView
                    } else {
                        recommendationsList
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep Insights")
            .onAppear {
                generateRecommendations()
            }
            .refreshable {
                generateRecommendations()
            }
        }
    }
    
    // MARK: - Header Card
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                
                Text("Personalized Insights")
                    .font(.headline)
            }
            
            Text("Based on your sleep patterns from the last 2 weeks, here are personalized recommendations to improve your sleep quality.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Recommendations List
    
    private var recommendationsList: some View {
        VStack(spacing: 15) {
            ForEach(recommendations) { recommendation in
                recommendationCard(recommendation)
            }
        }
    }
    
    private func recommendationCard(_ recommendation: SleepRecommendation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with priority badge
            HStack {
                Image(systemName: recommendation.category.icon)
                    .foregroundStyle(colorForCategory(recommendation.category))
                
                Text(recommendation.title)
                    .font(.headline)
                
                Spacer()
                
                priorityBadge(recommendation.priority)
            }
            
            // Description
            Text(recommendation.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Action button
            if recommendation.actionable, let action = recommendation.action {
                HStack {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.caption)
                    Text(action)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(colorForCategory(recommendation.category).opacity(0.15))
                .foregroundStyle(colorForCategory(recommendation.category))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Category tag
            HStack {
                Text(recommendation.category.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorForCategory(recommendation.category).opacity(0.3), lineWidth: 2)
        )
    }
    
    private func priorityBadge(_ priority: SleepRecommendation.RecommendationPriority) -> some View {
        Text(priority.label)
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(priorityColor(priority))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
    
    private func priorityColor(_ priority: SleepRecommendation.RecommendationPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
    
    private func colorForCategory(_ category: SleepRecommendation.RecommendationCategory) -> Color {
        switch category.color {
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "indigo": return .indigo
        case "yellow": return .yellow
        default: return .gray
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundStyle(.gray)
            
            Text("Building Your Profile")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Track your sleep for a few more nights to receive personalized recommendations")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
        }
        .padding(40)
    }
    
    // MARK: - Generate Recommendations
    
    private func generateRecommendations() {
        recommendations = RecommendationsEngine.generateRecommendations(
            nights: vm.nights,
            settings: vm.settings,
            isOnScheduleCheck: { night in vm.isOnSchedule(night) }
        )
    }
}

#Preview {
    NavigationStack {
        InsightsView()
            .environmentObject(SleepVM())
    }
}
