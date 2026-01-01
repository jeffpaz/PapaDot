//  Views/FeedbackView.swift
import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("userName") private var userName: String = "Me"
    
    @State private var selectedCategory: FeedbackCategory = .general
    @State private var message: String = ""
    @State private var userEmail: String = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var showError = false
    
    private let feedbackService = FeedbackService()
    private let developerEmail = "your-email@example.com" // ← CHANGE THIS!
    
    // Use CloudKit or Email
    private let useCloudKit = true // Set to false to use email instead
    
    private var isValid: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.1, green: 0.4, blue: 0.2),
                        Color(red: 0.05, green: 0.25, blue: 0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.green)
                                .padding(.top, 20)
                            
                            Text("Send Feedback")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            
                            Text("Help us improve PapaDot!")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        
                        // Category Selector
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 12) {
                                ForEach(FeedbackCategory.allCases, id: \.self) { category in
                                    CategoryButton(
                                        category: category,
                                        isSelected: selectedCategory == category
                                    ) {
                                        selectedCategory = category
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Message Input
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Feedback")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            ZStack(alignment: .topLeading) {
                                if message.isEmpty {
                                    Text("Tell us what you think...")
                                        .foregroundStyle(.white.opacity(0.3))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                }
                                
                                TextEditor(text: $message)
                                    .scrollContentBackground(.hidden)
                                    .foregroundStyle(.white)
                                    .frame(minHeight: 150)
                                    .padding(8)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Email Input (optional)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Email (optional)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            
                            TextField("email@example.com", text: $userEmail)
                                .textFieldStyle(.plain)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Device Info
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Diagnostic Info (automatically included)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.6))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                InfoRow(label: "App Version", 
                                       value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                                InfoRow(label: "iOS Version", 
                                       value: UIDevice.current.systemVersion)
                                InfoRow(label: "Device", 
                                       value: UIDevice.current.model)
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Send Button
                        Button {
                            sendFeedback()
                        } label: {
                            HStack(spacing: 12) {
                                if isSending {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text("Send Feedback")
                                        .font(.headline.bold())
                                }
                            }
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                isValid && !isSending ?
                                LinearGradient(colors: [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                                LinearGradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                        }
                        .disabled(!isValid || isSending)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .disabled(isSending)
                }
            }
            .alert("Feedback Sent!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for your feedback! We appreciate you helping us improve PapaDot.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Failed to send feedback. Please try again or email us directly at \(developerEmail)")
            }
        }
    }
    
    private func sendFeedback() {
        isSending = true
        
        let feedback = Feedback(
            category: selectedCategory,
            message: message,
            userName: userName != "Me" ? userName : nil,
            userEmail: userEmail.isEmpty ? nil : userEmail
        )
        
        if useCloudKit {
            // Send to CloudKit
            Task {
                let success = await feedbackService.saveFeedback(feedback)
                await MainActor.run {
                    isSending = false
                    if success {
                        showSuccess = true
                    } else {
                        showError = true
                    }
                }
            }
        } else {
            // Send via Email
            if let url = feedbackService.emailURL(for: feedback, to: developerEmail) {
                UIApplication.shared.open(url)
                isSending = false
                dismiss()
            } else {
                isSending = false
                showError = true
            }
        }
    }
}

// MARK: - Category Button
struct CategoryButton: View {
    let category: FeedbackCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                
                Text(category.rawValue.components(separatedBy: " ").first ?? "")
                    .font(.caption.bold())
            }
            .foregroundStyle(isSelected ? .black : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isSelected ?
                Color.green :
                Color.white.opacity(0.1)
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}

#Preview {
    FeedbackView()
}
