//  Views/GameSetup/CreateGameView.swift
import SwiftUI
import ContactsUI

struct CreateGameView: View {
    @Environment(GameManager.self) var manager
    @Environment(\.dismiss) var dismiss
    
    @State private var wagerText = "1"
    @State private var players: [Player] = []
    @State private var showingContactPicker = false
    @State private var showingPar3Selection = false
    
    @AppStorage("userName") private var userName: String = "Me"
    @AppStorage("userPhoneNumber") private var userPhoneNumber: String = ""
    @AppStorage("userContactID") private var userContactID: String = ""
    
    @State private var showingUserProfileSetup = false
    
    private var allPlayers: [Player] {
        [Player(name: userName, phoneNumber: userPhoneNumber)] + players
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Wager per Dot") {
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("1", text: $wagerText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Players (\(allPlayers.count)/4)") {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(userName)
                                .font(.headline.bold())
                            if !userPhoneNumber.isEmpty {
                                Text(userPhoneNumber)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Change") {
                            showingUserProfileSetup = true
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 8)
                    
                    ForEach(players) { player in
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name)
                                    .font(.subheadline)
                                if !player.phoneNumber.isEmpty {
                                    Text(player.phoneNumber)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Remove") {
                                players.removeAll { $0.id == player.id }
                            }
                            .foregroundStyle(.red)
                        }
                    }
                    
                    Button {
                        showingContactPicker = true
                    } label: {
                        Label("Add Player", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .foregroundStyle(.blue)
                }
                
                Section {
                    Button("Create Game") {
                        // Only create with host player - others will join via code
                        showingPar3Selection = true
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .disabled(userName == "Me" || userContactID.isEmpty)
                }
            }
            .navigationTitle("New Game")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPicker { contact in
                    addPlayerFromContact(contact)
                }
            }
            .sheet(isPresented: $showingPar3Selection) {
                Par3SelectionView(
                    wager: Int(wagerText) ?? 1,
                    players: allPlayers
                )
            }
            .sheet(isPresented: $showingUserProfileSetup) {
                UserProfileSetupView(
                    userName: $userName,
                    userPhoneNumber: $userPhoneNumber,
                    userContactID: $userContactID
                )
            }
            .onAppear {
                // Show profile setup if user hasn't set it up yet
                if userName == "Me" || userContactID.isEmpty {
                    showingUserProfileSetup = true
                }
            }
        }
    }
    
    private func addPlayerFromContact(_ contact: CNContact) {
        let firstName = contact.givenName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !firstName.isEmpty,
              !allPlayers.contains(where: { $0.name.lowercased() == firstName.lowercased() }) else { return }
        
        // Get phone number if available
        let phoneNumber = contact.phoneNumbers.first?.value.stringValue ?? ""
        
        players.append(Player(name: firstName.capitalized, phoneNumber: phoneNumber))
    }
}

#Preview {
    CreateGameView()
        .environment(GameManager())
}
