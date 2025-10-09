//
//  ShareSheet.swift
//  SleepSentinel
//
//  Created by Roy Dimapilis on 10/8/25.
//

import SwiftUI
import UIKit

// Bridge between SwiftUI and iOS share menu
// Shows the native share popup (text, email, files, etc.)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]  // What to share (like CSV text)
    
    // Create the iOS share controller
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    // Update (not needed for share sheet)
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// How to use:
// .sheet(isPresented: $showingExport) {
//     ShareSheet(activityItems: [csvData])
// }
