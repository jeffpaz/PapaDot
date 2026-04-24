// Views/PlayerPickerView.swift
import SwiftUI
import Contacts
import ContactsUI

/// Unified player picker with three tabs:
///  1. Favorites — starred players for quick access
///  2. Contacts — full contacts list
///  3. Manual — type in a name/phone directly
struct PlayerPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FavoritesManager.self) var favorites

    let onAdd: (Player) -> Void

    @State private var selectedTab = 0
    @State private var contacts: [CNContact] = []
    @State private var searchText = ""
    @State private var isLoadingContacts = false
    @State private var contactsError: String?

    // Manual entry
    @State private var manualName = ""
    @State private var manualPhone = ""

    private var filteredContacts: [CNContact] {
        if searchText.isEmpty { return contacts }
        let q = searchText.lowercased()
        return contacts.filter {
            $0.givenName.lowercased().contains(q) ||
            $0.familyName.lowercased().contains(q)
        }
    }

    private var filteredFavorites: [Player] {
        if searchText.isEmpty { return favorites.favorites }
        let q = searchText.lowercased()
        return favorites.favorites.filter { $0.name.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Source", selection: $selectedTab) {
                    Label("Favorites", systemImage: "star.fill").tag(0)
                    Label("Contacts", systemImage: "person.2.fill").tag(1)
                    Label("Manual", systemImage: "pencil").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                // Search bar (for favorites + contacts tabs)
                if selectedTab < 2 {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search", text: $searchText)
                            .autocorrectionDisabled()
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                Divider()

                // Content
                switch selectedTab {
                case 0: favoritesTab
                case 1: contactsTab
                default: manualTab
                }
            }
            .navigationTitle("Add Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task {
                if contacts.isEmpty { await loadContacts() }
            }
        }
    }

    // MARK: - Favorites Tab

    private var favoritesTab: some View {
        Group {
            if filteredFavorites.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "star.slash")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "No favorites yet" : "No matches")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if searchText.isEmpty {
                        Text("Star players from the Contacts tab to add them here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredFavorites) { player in
                    PlayerRow(
                        name: player.name,
                        subtitle: player.phoneNumber,
                        isFavorite: true
                    ) {
                        addAndDismiss(player)
                    } onFavoriteToggle: {
                        favorites.remove(player)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Contacts Tab

    private var contactsTab: some View {
        Group {
            if isLoadingContacts {
                ProgressView("Loading contacts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let err = contactsError {
                VStack(spacing: 16) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredContacts, id: \.identifier) { contact in
                    let name = [contact.givenName, contact.familyName]
                        .filter { !$0.isEmpty }.joined(separator: " ")
                    let phone = contact.phoneNumbers.first?.value.stringValue ?? ""
                    let player = Player(name: name, phoneNumber: phone)
                    let isFav = favorites.isFavorite(player)

                    PlayerRow(
                        name: name,
                        subtitle: phone,
                        isFavorite: isFav
                    ) {
                        addAndDismiss(player)
                    } onFavoriteToggle: {
                        favorites.toggle(player)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Manual Tab

    private var manualTab: some View {
        Form {
            Section {
                TextField("Full Name", text: $manualName)
                    .autocorrectionDisabled()
                    .textContentType(.name)
                TextField("Phone Number (optional)", text: $manualPhone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            } footer: {
                Text("Enter a player's name directly — no contact required.")
            }

            Section {
                Button {
                    let player = Player(
                        name: manualName.trimmingCharacters(in: .whitespaces),
                        phoneNumber: manualPhone.trimmingCharacters(in: .whitespaces)
                    )
                    addAndDismiss(player)
                } label: {
                    Label("Add Player", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .disabled(manualName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Helpers

    private func addAndDismiss(_ player: Player) {
        onAdd(player)
        dismiss()
    }

    private func loadContacts() async {
        isLoadingContacts = true
        defer { isLoadingContacts = false }
        do {
            let store = CNContactStore()
            let auth = try await store.requestAccess(for: .contacts)
            guard auth else {
                contactsError = "Contacts access denied. Enable it in Settings → PapaDot → Contacts."
                return
            }
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)

            // Run on background thread — enumerateContacts blocks and must not run on main thread
            let sorted: [CNContact] = try await Task.detached(priority: .userInitiated) {
                var loaded: [CNContact] = []
                try store.enumerateContacts(with: request) { contact, _ in
                    if !contact.givenName.isEmpty || !contact.familyName.isEmpty {
                        loaded.append(contact)
                    }
                }
                return loaded.sorted { $0.familyName.lowercased() < $1.familyName.lowercased() }
            }.value

            contacts = sorted
        } catch {
            contactsError = "Failed to load contacts: \(error.localizedDescription)"
        }
    }
}

// MARK: - Player Row

private struct PlayerRow: View {
    let name: String
    let subtitle: String
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 42, height: 42)
                .overlay {
                    Text(String(name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

            // Name + phone
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Favorite star
            Button {
                onFavoriteToggle()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            // Add chevron
            Button {
                onTap()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

