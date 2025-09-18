import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    @State private var authMode: AuthMode = .signIn
    @FocusState private var focusedField: FocusField?
    @State private var touchedFields: Set<FocusField> = []
    @State private var attemptedSubmit: Bool = false
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

    enum FocusField: Hashable {
        case firstName
        case lastName
        case email
        case password
        case confirmPassword
        case verificationCode
        case newPassword
        case confirmNewPassword
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    // Logo/Brand section
                    HStack(spacing: 12) {
                        Image("logo")
                            .resizable()
                            .interpolation(.high)
                            .antialiased(true)
                            .scaledToFit()
                            .frame(width: 40, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Motion Storyline")
                                .font(.title2)
                                .fontWeight(.bold)
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
                    FeatureRow(icon: "square.grid.2x2", text: "Templates")
                    FeatureRow(icon: "play.rectangle", text: "Create Walkthroughs")
                    FeatureRow(icon: "record.circle", text: "Record Screen")
                    FeatureRow(icon: "square.and.arrow.up", text: "Export MP4/GIF")
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
        .onChange(of: authManager.isAuthenticated) { _, isAuthed in
            // When authentication completes successfully, dismiss and reset form
            if isAuthed {
                dismiss()
                clearForm()
            }
        }
    }
    
    // MARK: - Main Authentication Form
    
    @ViewBuilder
    private var mainAuthForm: some View {
        VStack(spacing: 24) {
            // Email/Password only (OAuth disabled)

            // Email/Password form with labels, focus/hover states, inline errors
            VStack(spacing: 16) {
                if authMode == .signUp {
                    HStack(spacing: 12) {
                        FormFieldContainer(
                            label: "First name",
                            helper: nil,
                            error: firstNameError,
                            isFocused: focusedField == .firstName
                        ) {
                            TextField("First name", text: $firstName)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .firstName)
                                .onChange(of: focusedField) { _, new in
                                    updateTouched(previous: .firstName, new: new)
                                }
                        }
                        FormFieldContainer(
                            label: "Last name",
                            helper: nil,
                            error: lastNameError,
                            isFocused: focusedField == .lastName
                        ) {
                            TextField("Last name", text: $lastName)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .lastName)
                                .onChange(of: focusedField) { _, new in
                                    updateTouched(previous: .lastName, new: new)
                                }
                        }
                    }
                }

                FormFieldContainer(
                    label: "Email address",
                    helper: emailHelper,
                    error: emailError,
                    isFocused: focusedField == .email
                ) {
                    TextField("you@example.com", text: $email)
                        .textFieldStyle(.plain)
                        .focused($focusedField, equals: .email)
                        .onChange(of: focusedField) { _, new in
                            updateTouched(previous: .email, new: new)
                        }
                        .onSubmit(handleSubmitNavigation)
                }

                if authMode != .passwordReset {
                    // Password with visibility toggle and strength meter
                    FormFieldContainer(
                        label: authMode == .signUp ? "Create password" : "Password",
                        helper: passwordHelper,
                        error: passwordError,
                        isFocused: focusedField == .password
                    ) {
                        PasswordField(text: $password)
                            .focused($focusedField, equals: .password)
                            .onChange(of: focusedField) { _, new in
                                updateTouched(previous: .password, new: new)
                            }
                            .onSubmit(handleSubmitNavigation)
                    }

                    if authMode == .signUp {
                        FormFieldContainer(
                            label: "Confirm password",
                            helper: confirmPasswordHelper,
                            error: confirmPasswordError,
                            isFocused: focusedField == .confirmPassword
                        ) {
                            PasswordField(text: $confirmPassword)
                                .focused($focusedField, equals: .confirmPassword)
                                .onChange(of: focusedField) { _, new in
                                    updateTouched(previous: .confirmPassword, new: new)
                                }
                                .onSubmit(handleSubmitNavigation)
                        }
                    }
                }
            }
            
            // Action button
            Button(action: {
                attemptedSubmit = true
                Task { await performMainAction() }
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
                        withAnimation(.easeInOut(duration: 0.25)) {
                            authMode = authMode == .signIn ? .signUp : .signIn
                            clearForm()
                            focusedField = authMode == .signIn ? .email : .firstName
                        }
                    }
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
                .font(.caption)
            }
            
            // Passwordless sign in option
            if authMode == .signIn {
                Button("Email me a sign-in code") {
                    Task {
                        await authManager.signInWithEmailCode(email.trimmed())
                        showingVerification = true
                    }
                }
                .foregroundColor(.blue)
                .buttonStyle(.plain)
                .font(.caption)
                .disabled(email.isEmpty || authManager.isLoading)
            }
        }
        .onAppear {
            focusedField = authMode == .signIn ? .email : .firstName
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
            
            FormFieldContainer(
                label: "Verification code",
                helper: "Check your inbox for a 6-digit code",
                error: verificationError,
                isFocused: focusedField == .verificationCode
            ) {
                TextField("123456", text: $verificationCode)
                    .textFieldStyle(.plain)
                    .focused($focusedField, equals: .verificationCode)
                    .onChange(of: focusedField) { _, new in
                        updateTouched(previous: .verificationCode, new: new)
                    }
                    .monospaced()
            }
            
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
                    FormFieldContainer(
                        label: "Email address",
                        helper: emailHelper,
                        error: emailError,
                        isFocused: focusedField == .email
                    ) {
                        TextField("you@example.com", text: $email)
                            .focused($focusedField, equals: .email)
                            .onChange(of: focusedField) { _, new in
                                updateTouched(previous: .email, new: new)
                            }
                    }
                    
                    Button(action: {
                        Task {
                            await authManager.resetPassword(email.trimmed())
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
                    FormFieldContainer(
                        label: "Verification code",
                        helper: "Enter the code you received",
                        error: verificationError,
                        isFocused: focusedField == .verificationCode
                    ) {
                        TextField("123456", text: $verificationCode)
                            .textFieldStyle(.plain)
                            .focused($focusedField, equals: .verificationCode)
                            .onChange(of: focusedField) { _, new in
                                updateTouched(previous: .verificationCode, new: new)
                            }
                            .monospaced()
                    }
                    
                    FormFieldContainer(
                        label: "New password",
                        helper: passwordHelper,
                        error: newPasswordError,
                        isFocused: focusedField == .newPassword
                    ) {
                        PasswordField(text: $newPassword)
                            .focused($focusedField, equals: .newPassword)
                            .onChange(of: focusedField) { _, new in
                                updateTouched(previous: .newPassword, new: new)
                            }
                    }
                    
                    FormFieldContainer(
                        label: "Confirm new password",
                        helper: confirmPasswordHelper,
                        error: confirmNewPasswordError,
                        isFocused: focusedField == .confirmNewPassword
                    ) {
                        PasswordField(text: $confirmNewPassword)
                            .focused($focusedField, equals: .confirmNewPassword)
                            .onChange(of: focusedField) { _, new in
                                updateTouched(previous: .confirmNewPassword, new: new)
                            }
                    }
                    
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
        attemptedSubmit = true
        switch authMode {
        case .signIn:
            await authManager.signInWithEmail(email.trimmed(), password: password)
        case .signUp:
            await authManager.signUpWithEmail(email.trimmed(), password: password, firstName: firstName.isEmpty ? nil : firstName, lastName: lastName.isEmpty ? nil : lastName)
            showingVerification = true
        case .passwordReset:
            await authManager.resetPassword(email.trimmed())
            showingPasswordReset = true
        }
    }
    
    private var isFormValid: Bool {
        switch authMode {
        case .signIn:
            return emailError == nil && !password.isEmpty
        case .signUp:
            return emailError == nil && passwordError == nil && confirmPasswordError == nil
        case .passwordReset:
            return emailError == nil
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
        attemptedSubmit = false
        touchedFields.removeAll()
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
                .foregroundColor(Color(NSColor.darkGray))
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
        .environmentObject(AuthenticationManager())
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

// MARK: - Form Helpers & Components

fileprivate extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension AuthenticationView {
    // MARK: Validation helpers
    private var emailHelper: String? { "Use the email you registered with" }
    private var emailError: String? {
        let value = email.trimmed()
        let show = attemptedSubmit || touchedFields.contains(.email)
        guard show else { return nil }
        if value.isEmpty { return "Email is required" }
        if !value.contains("@") || !value.contains(".") { return "Enter a valid email address" }
        return nil
    }

    private var firstNameError: String? { nil }
    private var lastNameError: String? { nil }

    private var passwordHelper: String? { authMode == .signUp ? "At least 8 characters recommended" : nil }
    private var passwordError: String? {
        guard authMode != .passwordReset else { return nil }
        let show = attemptedSubmit || touchedFields.contains(.password)
        guard show else { return nil }
        if password.isEmpty { return "Password is required" }
        if authMode == .signUp && password.count < 8 { return "Password must be at least 8 characters" }
        return nil
    }

    private var confirmPasswordHelper: String? { authMode == .signUp ? "Re-enter your password" : nil }
    private var confirmPasswordError: String? {
        guard authMode == .signUp else { return nil }
        let show = attemptedSubmit || touchedFields.contains(.confirmPassword)
        guard show else { return nil }
        if confirmPassword.isEmpty { return "Please confirm your password" }
        if confirmPassword != password { return "Passwords do not match" }
        return nil
    }

    private var newPasswordError: String? {
        let show = attemptedSubmit || touchedFields.contains(.newPassword)
        guard show else { return nil }
        if newPassword.isEmpty { return "New password is required" }
        if newPassword.count < 8 { return "Password must be at least 8 characters" }
        return nil
    }
    private var confirmNewPasswordError: String? {
        let show = attemptedSubmit || touchedFields.contains(.confirmNewPassword)
        guard show else { return nil }
        if confirmNewPassword.isEmpty { return "Please confirm your new password" }
        if confirmNewPassword != newPassword { return "Passwords do not match" }
        return nil
    }
    private var verificationError: String? {
        let show = attemptedSubmit || touchedFields.contains(.verificationCode)
        guard show else { return nil }
        if verificationCode.trimmed().isEmpty { return "Code is required" }
        return nil
    }

    // MARK: Focus helpers
    private func updateTouched(previous field: FocusField, new: FocusField?) {
        // Mark a field as touched when it becomes focused once
        if new == field { touchedFields.insert(field) }
    }

    private func handleSubmitNavigation() {
        switch authMode {
        case .signIn:
            if focusedField == .email { focusedField = .password; return }
            if focusedField == .password { attemptedSubmit = true; Task { await performMainAction() } }
        case .signUp:
            switch focusedField {
            case .firstName: focusedField = .lastName
            case .lastName: focusedField = .email
            case .email: focusedField = .password
            case .password: focusedField = .confirmPassword
            case .confirmPassword:
                attemptedSubmit = true
                Task { await performMainAction() }
            default: break
            }
        case .passwordReset:
            attemptedSubmit = true
            Task { await performMainAction() }
        }
    }
}

fileprivate func passwordStrength(_ password: String) -> Int {
    var score = 0
    if password.count >= 8 { score += 1 }
    if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
    if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
    if password.range(of: "[0-9\\W]", options: .regularExpression) != nil { score += 1 }
    return min(score, 4)
}

struct FormFieldContainer<Content: View>: View {
    let label: String?
    let helper: String?
    let error: String?
    var isFocused: Bool
    @State private var isHovered = false
    let content: () -> Content

    init(label: String?, helper: String?, error: String?, isFocused: Bool, @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.helper = helper
        self.error = error
        self.isFocused = isFocused
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = label { Text(label).font(.caption).foregroundColor(.secondary) }
            HStack(spacing: 8) { content() }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .cornerRadius(8)
                .onHover { hovering in isHovered = hovering }

            if let error = error, !error.isEmpty {
                Text(error).font(.caption2).foregroundColor(.red)
            } else if let helper = helper, !helper.isEmpty {
                Text(helper).font(.caption2).foregroundColor(.secondary)
            }
        }
    }

    private var borderColor: Color {
        if (error?.isEmpty == false) { return .red }
        if isFocused { return .blue }
        return isHovered ? Color.gray.opacity(0.6) : Color.gray.opacity(0.3)
    }
}

struct PasswordField: View {
    @Binding var text: String
    @State private var isSecure: Bool = true

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isSecure {
                    SecureField("", text: $text)
                        .textFieldStyle(.plain)
                } else {
                    TextField("", text: $text)
                        .textFieldStyle(.plain)
                }
            }
            Button(action: { isSecure.toggle() }) {
                Image(systemName: isSecure ? "eye" : "eye.slash")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .overlay(alignment: .bottomLeading) {
            if !text.isEmpty {
                PasswordStrengthView(score: passwordStrength(text))
                    .offset(y: 26)
            }
        }
    }
}

struct PasswordStrengthView: View {
    let score: Int // 0..4
    var label: String {
        switch score { case 0: return "Very weak"; case 1: return "Weak"; case 2: return "Fair"; case 3: return "Good"; default: return "Strong" }
    }
    var color: Color {
        switch score { case 0,1: return .red; case 2: return .orange; case 3: return .yellow; default: return .green }
    }
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(i < min(score, 4) ? color : Color.gray.opacity(0.2))
                    .frame(width: 30, height: 4)
                    .cornerRadius(2)
            }
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
    }
}
