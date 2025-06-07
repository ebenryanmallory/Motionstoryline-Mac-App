import SwiftUI
import Clerk
import Combine

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var user: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var clerk: Clerk
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.clerk = Clerk.shared
        
        // Initialize authentication state
        self.user = clerk.user
        self.isAuthenticated = clerk.user != nil
        
        // Observe authentication state changes
        setupObservers()
    }
    
    private func setupObservers() {
        // Monitor user changes
        // Note: We'll manually check authentication state since Clerk's publisher may not be available
        // This will be updated when the user signs in/out
    }
    
    func refreshAuthenticationState() {
        // Update authentication state from the shared Clerk instance
        self.user = clerk.user
        self.isAuthenticated = clerk.user != nil
    }
    
    // MARK: - Sign In Methods
    
    func signInWithEmail(_ email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let signIn = try await SignIn.create(
                strategy: .identifier(email, password: password)
            )
            
            if signIn.status == .complete {
                // Sign in successful - update state
                await MainActor.run {
                    self.refreshAuthenticationState()
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Sign in incomplete. Please check your credentials."
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signInWithEmailCode(_ email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await SignIn.create(
                strategy: .identifier(email, strategy: .emailCode())
            )
            
            await MainActor.run {
                self.isLoading = false
                // The user will need to enter the code they receive via email
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func verifyEmailCode(_ code: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // This assumes we have a pending sign in
            if let signIn = clerk.client?.signIn {
                let completedSignIn = try await signIn.attemptFirstFactor(strategy: .emailCode(code: code))
                
                if completedSignIn.status == .complete {
                    await MainActor.run {
                        self.refreshAuthenticationState()
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Verification incomplete"
                        self.isLoading = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Up Methods
    
    func signUpWithEmail(_ email: String, password: String, firstName: String? = nil, lastName: String? = nil) async {
        isLoading = true
        errorMessage = nil
        
        do {
            var signUp = try await SignUp.create(
                strategy: .standard(emailAddress: email, password: password)
            )
            
            // Add name if provided
            if let firstName = firstName, let lastName = lastName {
                signUp = try await signUp.update(params: .init(firstName: firstName, lastName: lastName))
            }
            
            // Check if email verification is required
            if signUp.unverifiedFields.contains("email_address") {
                signUp = try await signUp.prepareVerification(strategy: .emailCode)
                await MainActor.run {
                    self.isLoading = false
                    // User needs to verify email
                }
            } else if signUp.status == .complete {
                await MainActor.run {
                    self.refreshAuthenticationState()
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func verifySignUpEmailCode(_ code: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let signUp = clerk.client?.signUp {
                let completedSignUp = try await signUp.attemptVerification(strategy: .emailCode(code: code))
                
                if completedSignUp.status == .complete {
                    await MainActor.run {
                        self.refreshAuthenticationState()
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Verification incomplete"
                        self.isLoading = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - OAuth Sign In
    
    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SignIn.authenticateWithRedirect(strategy: .oauth(provider: .google))
            await MainActor.run {
                self.refreshAuthenticationState()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Use the Clerk SignInWithAppleHelper class to get your Apple credential
            let credential = try await SignInWithAppleHelper.getAppleIdCredential()
            
            // Convert the identityToken data to String format
            guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                await MainActor.run {
                    self.errorMessage = "Failed to process Apple ID token"
                    self.isLoading = false
                }
                return
            }
            
            // Authenticate with Clerk
            try await SignIn.authenticateWithIdToken(provider: .apple, idToken: idToken)
            
            await MainActor.run {
                self.refreshAuthenticationState()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await clerk.signOut()
            await MainActor.run {
                self.refreshAuthenticationState()
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Password Reset
    
    func resetPassword(_ email: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await SignIn.create(
                strategy: .identifier(email, strategy: .resetPasswordEmailCode())
            )
            
            await MainActor.run {
                self.isLoading = false
                // User will receive an email with reset code
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func verifyPasswordResetCode(_ code: String, newPassword: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            if let signIn = clerk.client?.signIn {
                var updatedSignIn = try await signIn.attemptFirstFactor(strategy: .resetPasswordEmailCode(code: code))
                updatedSignIn = try await updatedSignIn.resetPassword(.init(password: newPassword, signOutOfOtherSessions: true))
                
                if updatedSignIn.status == .complete {
                    await MainActor.run {
                        self.refreshAuthenticationState()
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run {
                        self.errorMessage = "Password reset incomplete"
                        self.isLoading = false
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - User Profile Management
    
    func updateProfile(firstName: String?, lastName: String?) async {
        guard let user = user else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await user.update(.init(firstName: firstName, lastName: lastName))
            await MainActor.run {
                self.user = clerk.user // Refresh user data
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func updateProfileImage(imageData: Data) async {
        guard let user = user else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await user.setProfileImage(imageData: imageData)
            await MainActor.run {
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Session Management
    
    func getSessionToken() async -> String? {
        do {
            return try await clerk.session?.getToken()?.jwt
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to get session token: \(error.localizedDescription)"
            }
            return nil
        }
    }
} 