import SwiftUI

struct AuthenticationView: View {
    @StateObject private var authManager = AuthenticationManager()
    @Environment(\.dismiss) private var dismiss
    @State private var authMode: AuthMode = .signIn
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var verificationCode: String = ""
    @State private var showingVerification: Bool = false
    @State private var showingPasswordReset: Bool = false
    @State private var newPassword: String = ""
    @State private var confirmNewPassword: String = ""
    
    enum AuthMode {
        case signIn
        case signUp
        case passwordReset
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    // Logo/Brand section
                    HStack(spacing: 12) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Motion Storyline")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Create stunning animations with ease")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                // Features banner
                HStack(spacing: 24) {
                    FeatureRow(icon: "wand.and.rays", text: "Intuitive tools")
                    FeatureRow(icon: "square.and.arrow.up", text: "Export formats")
                    FeatureRow(icon: "icloud", text: "Cloud sync")
                    FeatureRow(icon: "person.2", text: "Collaborate")
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue.opacity(0.1), .purple.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                
                // Main content
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 8) {
                        Text(authMode == .signIn ? "Welcome back" : authMode == .signUp ? "Create account" : "Reset password")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(authMode == .signIn ? "Sign in to your account" : authMode == .signUp ? "Get started with Motion Storyline" : "Enter your email to reset your password")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                    
                    // Error message
                    if let errorMessage = authManager.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    // Main form
                    if showingVerification {
                        verificationForm
                    } else if showingPasswordReset {
                        passwordResetForm
                    } else {
                        mainAuthForm
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .frame(width: 600, height: 700)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Main Authentication Form
    
    @ViewBuilder
    private var mainAuthForm: some View {
        VStack(spacing: 24) {
            // OAuth buttons
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image(systemName: "globe")
                        Text("Continue with Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(authManager.isLoading)
                
                Button(action: {
                    Task {
                        await authManager.signInWithApple()
                    }
                }) {
                    HStack {
                        Image(systemName: "applelogo")
                        Text("Continue with Apple")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(authManager.isLoading)
            }
            
            // Divider
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Email/Password form
            VStack(spacing: 16) {
                if authMode == .signUp {
                    HStack(spacing: 12) {
                        TextField("First name", text: $firstName)
                            .textFieldStyle(CustomTextFieldStyle())
                        
                        TextField("Last name", text: $lastName)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                }
                
                TextField("Email address", text: $email)
                    .textFieldStyle(CustomTextFieldStyle())
                
                if authMode != .passwordReset {
                    SecureField("Password", text: $password)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    if authMode == .signUp {
                        SecureField("Confirm password", text: $confirmPassword)
                            .textFieldStyle(CustomTextFieldStyle())
                    }
                }
            }
            
            // Action button
            Button(action: {
                Task {
                    await performMainAction()
                }
            }) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(authMode == .signIn ? "Sign In" : authMode == .signUp ? "Create Account" : "Send Reset Email")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(authManager.isLoading || !isFormValid)
            
            // Alternative actions
            VStack(spacing: 8) {
                if authMode == .signIn {
                    Button("Forgot your password?") {
                        authMode = .passwordReset
                    }
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
                
                HStack {
                    Text(authMode == .signIn ? "Don't have an account?" : authMode == .signUp ? "Already have an account?" : "Remember your password?")
                        .foregroundColor(.secondary)
                    
                    Button(authMode == .signIn ? "Sign up" : authMode == .signUp ? "Sign in" : "Sign in") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            authMode = authMode == .signIn ? .signUp : .signIn
                            clearForm()
                        }
                    }
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
                .font(.caption)
            }
            
            // Passwordless sign in option
            if authMode == .signIn {
                Button("Send me a magic link instead") {
                    Task {
                        await authManager.signInWithEmailCode(email)
                        showingVerification = true
                    }
                }
                .foregroundColor(.blue)
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(email.isEmpty || authManager.isLoading)
            }
        }
    }
    
    // MARK: - Verification Form
    
    @ViewBuilder
    private var verificationForm: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Image(systemName: "envelope.badge")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text("Check your email")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("We sent a verification code to \(email)")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            TextField("Enter verification code", text: $verificationCode)
                .textFieldStyle(CustomTextFieldStyle())
            
            Button(action: {
                Task {
                    if authMode == .signUp {
                        await authManager.verifySignUpEmailCode(verificationCode)
                    } else {
                        await authManager.verifyEmailCode(verificationCode)
                    }
                }
            }) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Verify Code")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(authManager.isLoading || verificationCode.isEmpty)
            
            Button("Back to sign in") {
                showingVerification = false
                clearForm()
            }
            .foregroundColor(.blue)
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Password Reset Form
    
    @ViewBuilder
    private var passwordResetForm: some View {
        VStack(spacing: 24) {
            if verificationCode.isEmpty {
                // Step 1: Enter email
                VStack(spacing: 16) {
                    TextField("Email address", text: $email)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    Button(action: {
                        Task {
                            await authManager.resetPassword(email)
                            // Move to verification step
                            verificationCode = " " // Trigger next step
                        }
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("Send Reset Code")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(authManager.isLoading || email.isEmpty)
                }
            } else {
                // Step 2: Enter code and new password
                VStack(spacing: 16) {
                    TextField("Verification code", text: $verificationCode)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    SecureField("New password", text: $newPassword)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    SecureField("Confirm new password", text: $confirmNewPassword)
                        .textFieldStyle(CustomTextFieldStyle())
                    
                    Button(action: {
                        Task {
                            await authManager.verifyPasswordResetCode(verificationCode, newPassword: newPassword)
                        }
                    }) {
                        HStack {
                            if authManager.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("Reset Password")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(authManager.isLoading || !isPasswordResetValid)
                }
            }
            
            Button("Back to sign in") {
                authMode = .signIn
                showingPasswordReset = false
                clearForm()
            }
            .foregroundColor(.blue)
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helper Methods
    
    private func performMainAction() async {
        switch authMode {
        case .signIn:
            await authManager.signInWithEmail(email, password: password)
        case .signUp:
            await authManager.signUpWithEmail(email, password: password, firstName: firstName.isEmpty ? nil : firstName, lastName: lastName.isEmpty ? nil : lastName)
            showingVerification = true
        case .passwordReset:
            await authManager.resetPassword(email)
            showingPasswordReset = true
        }
    }
    
    private var isFormValid: Bool {
        switch authMode {
        case .signIn:
            return !email.isEmpty && !password.isEmpty
        case .signUp:
            return !email.isEmpty && !password.isEmpty && password == confirmPassword && password.count >= 8
        case .passwordReset:
            return !email.isEmpty
        }
    }
    
    private var isPasswordResetValid: Bool {
        return !verificationCode.isEmpty && !newPassword.isEmpty && newPassword == confirmNewPassword && newPassword.count >= 8
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        firstName = ""
        lastName = ""
        verificationCode = ""
        newPassword = ""
        confirmNewPassword = ""
        showingVerification = false
        showingPasswordReset = false
        authManager.errorMessage = nil
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 20, height: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview {
    AuthenticationView()
}

// MARK: - Authentication Unavailable View

struct AuthenticationUnavailableView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            // Title
            Text("Authentication Service Unavailable")
                .font(.title)
                .fontWeight(.semibold)
            
            // Description
            Text("We're having trouble connecting to our authentication service. You can continue using the app without signing in, or try again later.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Error message if available
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
                    .multilineTextAlignment(.center)
            }
            
            // Action buttons
            VStack(spacing: 12) {
                Button("Continue Without Signing In") {
                    authManager.continueWithoutAuthentication()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button("Try Again") {
                    Task {
                        await authManager.retryAuthentication()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(authManager.isLoading)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
} 