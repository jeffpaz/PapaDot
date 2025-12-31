//  Views/UserProfileSetupView.swift
import SwiftUI
import ContactsUI

struct UserProfileSetupView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var userName: String
    @Binding var userPhoneNumber: String
    @Binding var userContactID: String
    
    @State private var showingContactPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.blue)
                
                VStack(spacing: 10) {
                    Text("Select Your Contact")
                        .font(.title2.bold())
                    
                    Text("We need your contact info for payments and messaging")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if userName != "Me" && !userContactID.isEmpty {
                    VStack(spacing: 5) {
                        Text(userName)
                            .font(.headline)
                        if !userPhoneNumber.isEmpty {
                            Text(userPhoneNumber)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Button {
                    showingContactPicker = true
                } label: {
                    Label(userName == "Me" ? "Select from Contacts" : "Change Contact",
                          systemImage: "person.crop.circle.badge.checkmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                if userName != "Me" && !userContactID.isEmpty {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundStyle(.blue)
                }
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Your Profile")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(userName == "Me" || userContactID.isEmpty)
            .sheet(isPresented: $showingContactPicker) {
                ContactPicker { contact in
                    saveUserContact(contact)
                }
            }
        }
    }
    
    private func saveUserContact(_ contact: CNContact) {
        // Save full name
        let fullName = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        userName = fullName.isEmpty ? contact.givenName : fullName
        
        // Save phone number
        if let phoneNumber = contact.phoneNumbers.first?.value.stringValue {
            userPhoneNumber = phoneNumber
        }
        
        // Save contact identifier for future reference
        userContactID = contact.identifier
    }
}

// MARK: - Contact Picker
struct ContactPicker: UIViewControllerRepresentable {
    let onSelect: (CNContact) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let onSelect: (CNContact) -> Void
        
        init(onSelect: @escaping (CNContact) -> Void) {
            self.onSelect = onSelect
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onSelect(contact)
        }
    }
}

#Preview {
    @Previewable @State var name = "Me"
    @Previewable @State var phone = ""
    @Previewable @State var id = ""
    
    return UserProfileSetupView(userName: $name, userPhoneNumber: $phone, userContactID: $id)
}
