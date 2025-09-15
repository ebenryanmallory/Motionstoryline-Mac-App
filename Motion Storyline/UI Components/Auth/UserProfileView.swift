import SwiftUI
import Clerk

struct UserProfileView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingProfile = false
    @State private var firstName = ""
    @State private var lastName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            // Profile Image
            VStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text(fullName)
                    .font(.title3)
                    .fontWeight(.medium)
                
                Text(authManager.user?.primaryEmailAddress?.emailAddress ?? "No email")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // User Information
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personal Information")
                        .font(.headline)
                    
                    if isEditingProfile {
                        HStack(spacing: 12) {
                            TextField("First name", text: $firstName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            TextField("Last name", text: $lastName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        HStack {
                            Button("Cancel") {
                                isEditingProfile = false
                                resetEditingFields()
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            Button("Save") {
                                Task {
                                    await authManager.updateProfile(
                                        firstName: firstName.isEmpty ? nil : firstName,
                                        lastName: lastName.isEmpty ? nil : lastName
                                    )
                                    isEditingProfile = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(authManager.isLoading)
                        }
                    } else {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Name")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(fullName)
                                    .font(.body)
                            }
                            
                            Spacer()
                            
                            Button("Edit") {
                                isEditingProfile = true
                                firstName = authManager.user?.firstName ?? ""
                                lastName = authManager.user?.lastName ?? ""
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Sign Out Button
            Button(action: {
                Task {
                    await authManager.signOut()
                }
            }) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Sign Out")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(authManager.isLoading)
        }
        .padding()
        .frame(width: 400, height: 500)
    }
    
    private var fullName: String {
        let first = authManager.user?.firstName ?? ""
        let last = authManager.user?.lastName ?? ""
        
        if first.isEmpty && last.isEmpty {
            return "No name set"
        } else if first.isEmpty {
            return last
        } else if last.isEmpty {
            return first
        } else {
            return "\(first) \(last)"
        }
    }
    
    private func resetEditingFields() {
        firstName = authManager.user?.firstName ?? ""
        lastName = authManager.user?.lastName ?? ""
    }
}

#Preview {
    UserProfileView()
        .environmentObject(AuthenticationManager())
} 