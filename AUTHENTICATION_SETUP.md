# Authentication Setup with Clerk

Motion Storyline now includes user authentication powered by Clerk. This document explains how to set up and configure the authentication system.

## Overview

The app includes the following authentication components:

- **AuthenticationManager**: Handles all Clerk API interactions
- **AuthenticationView**: Provides sign-in and sign-up UI
- **UserProfileView**: Displays user profile information and settings
- **Integration**: Authentication state is integrated throughout the app

## Setup Instructions

### 1. Get Your Clerk Publishable Key

1. Sign up for a Clerk account at [clerk.com](https://clerk.com)
2. Create a new application in your Clerk dashboard
3. Navigate to the "API Keys" section
4. Copy your Publishable Key

### 2. Configure the App

1. Open `Motion Storyline/Motion Storyline/Services/AuthenticationManager.swift`
2. Find the line with `let publishableKey = "pk_test_your_publishable_key_here"`
3. Replace `"pk_test_your_publishable_key_here"` with your actual Clerk Publishable Key

### 3. Configure Clerk Dashboard

In your Clerk dashboard, make sure to:

1. **Enable Native Applications**: Go to "Native Applications" and ensure it's enabled
2. **Configure Sign-in Options**: Set up the authentication methods you want to support:
   - Email + Password
   - Email Magic Links
   - OAuth providers (Google, Apple, etc.)
   - Phone number authentication

## Features

### Authentication Methods

The app supports multiple authentication strategies:

- **Email + Password**: Traditional email/password authentication
- **Magic Links**: Passwordless authentication via email links
- **OAuth**: Sign in with Google, Apple, and other providers
- **Phone Authentication**: SMS-based authentication
- **Multi-Factor Authentication**: Optional 2FA support

### User Management

- **Profile Management**: Users can update their name and profile information
- **Account Settings**: Access to account preferences and security settings
- **Session Management**: Secure session handling with automatic token refresh

### UI Components

- **AuthenticationView**: Full-featured sign-in/sign-up interface
- **UserProfileView**: Profile management interface
- **User Menu**: Integrated user menu in TopBar and HomeView
- **Profile Images**: Support for user profile pictures

## App Flow

1. **Unauthenticated State**: Users see the AuthenticationView
2. **Authentication**: Users can sign in or sign up using various methods
3. **Authenticated State**: Users access the main app (HomeView or DesignCanvas)
4. **Profile Access**: Users can access their profile from the user menu
5. **Sign Out**: Users can sign out from the profile or user menu

## Code Structure

```
Motion Storyline/
├── Services/
│   └── AuthenticationManager.swift    # Core authentication logic
├── UI Components/
│   ├── AuthenticationView.swift       # Sign-in/sign-up interface
│   └── UserProfileView.swift          # Profile management
├── Home/
│   └── HomeView.swift                 # Updated with user menu
├── UI Components/
│   └── TopBar.swift                   # Updated with user menu
└── Motion_StorylineApp.swift          # App entry point with auth integration
```

## Environment Objects

The app uses SwiftUI's environment object system to share authentication state:

- `AuthenticationManager` is injected at the app level
- All views can access the current user and authentication state
- Reactive updates when authentication state changes

## Security Features

- **Secure Token Storage**: Clerk handles secure token storage
- **Automatic Token Refresh**: Sessions are automatically refreshed
- **Multi-Factor Authentication**: Optional 2FA support
- **Session Management**: Secure session lifecycle management

## Customization

### Styling

The authentication UI uses the app's design system and can be customized by modifying:

- `CustomTextFieldStyle` in AuthenticationView.swift
- Color schemes and fonts throughout the authentication components
- Layout and spacing in the authentication flows

### Authentication Methods

To enable/disable authentication methods:

1. Configure them in your Clerk dashboard
2. Update the AuthenticationView to show/hide relevant UI elements
3. Modify AuthenticationManager methods as needed

## Troubleshooting

### Common Issues

1. **"Failed to initialize authentication"**: Check your Publishable Key
2. **OAuth not working**: Ensure OAuth providers are configured in Clerk dashboard
3. **Build errors**: Make sure Clerk iOS SDK is properly installed

### Debug Mode

The AuthenticationManager includes error handling and logging. Check the console for detailed error messages during development.

## Next Steps

1. Replace the placeholder Publishable Key with your actual key
2. Configure your preferred authentication methods in Clerk dashboard
3. Test the authentication flow
4. Customize the UI to match your app's design
5. Set up webhooks for advanced user management (optional)

For more information, visit the [Clerk iOS Documentation](https://clerk.com/docs/quickstarts/ios). 