//  Views/OfflineModeBanner.swift
import SwiftUI

struct OfflineModeBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.title3)
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Mode")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                
                Text("CloudKit unavailable - no multiplayer sync")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color.orange.opacity(0.8), Color.red.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
}

#Preview {
    OfflineModeBanner()
}
