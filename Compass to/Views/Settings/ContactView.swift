//
//  ContactView.swift
//  HideSpot
//
//  Created by Lukas Marius Hoeschen on 18.03.26.
//

import SwiftUI


struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var mail = ""
    @State private var message = ""
    @State private var contactReason = "General Feedback"
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var showError = false
    
    let reasons = ["Bug Report", "Feature Request", "General Feedback", "Pro Purchase Issue", "Other"]
    
    var body: some View {
        Form {
            Section("Contact Reason") {
                Picker("Reason", selection: $contactReason) {
                    ForEach(reasons, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
            }
            
            Section {
                TextField("Email", text: $mail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
            } header: {
                Text("Your Email")
            } footer: {
                Text("So I can get back to you.")
            }
            
            Section("Message") {
                ZStack(alignment: .topLeading) {
                    if message.isEmpty {
                        Text("Write something...")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }
                    TextEditor(text: $message)
                        .frame(minHeight: 120, maxHeight: 400)
                }
            }
            
            Section {
                Button {
                    Task { await send() }
                } label: {
                    HStack {
                        Spacer()
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Send")
                                .bold()
                        }
                        Spacer()
                    }
                }
                .disabled(message.isEmpty || mail.isEmpty || isSending)
            }
        }
        .navigationTitle("Contact")
        .navigationBarTitleDisplayMode(.large)
        .alert("Message Sent!", isPresented: $showSuccess) {
            Button("Done") {
                message = ""
                dismiss()
            }
        } message: {
            Text("Thanks for reaching out! I'll get back to you as soon as possible.")
        }
        .alert("Something went wrong", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text("Please try again or email us directly.")
        }
    }
    
    func send() async {
        isSending = true
        
        guard let url = URL(string: "https://lukas.hoeschen.org/apps/headThere/api/send_message.php") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "message": message,
            "mail": mail.isEmpty ? "no Mail" : mail,
            "contactReason": contactReason
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                showSuccess = true
//                appState.notify(.success)
            } else {
                showError = true
//                appState.notify(.error)
            }
        } catch {
            showError = true
//            appState.notify(.error)
        }
        
        isSending = false
    }
}

#Preview {
    NavigationStack {
        ContactView()
    }
}
