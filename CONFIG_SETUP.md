# Configuration Setup

## Secure API Key Management

This project uses a secure configuration system to manage API keys and sensitive data.

### Initial Setup

1. **Copy the template configuration file:**
   ```bash
   cp "Motion Storyline/Config/Config.plist.template" "Motion Storyline/Config/Config.plist"
   ```

2. **Edit the Config.plist file:**
   - Open `Motion Storyline/Config/Config.plist`
   - Replace `YOUR_CLERK_PUBLISHABLE_KEY_HERE` with your actual Clerk publishable key
   - You can find your key in the [Clerk Dashboard](https://dashboard.clerk.dev) under API Keys

3. **The Config.plist file is automatically ignored by git** to keep your keys secure.

### Configuration Values

- **ClerkPublishableKey**: Your Clerk publishable key (starts with `pk_`)
- **Environment**: Current environment (`development`, `staging`, `production`)
- **APIBaseURL**: Base URL for Clerk API (usually `https://api.clerk.dev`)

### Security Notes

- ✅ **Config.plist** is in `.gitignore` - your keys won't be committed
- ✅ **Config.plist.template** is committed - provides structure for other developers
- ✅ **Runtime validation** - app will crash with helpful error if keys are missing
- ✅ **No hardcoded keys** in source code

### For Team Development

When setting up the project:
1. Clone the repository
2. Follow the "Initial Setup" steps above
3. Get the Clerk publishable key from your team lead or Clerk dashboard
4. Never commit your actual `Config.plist` file

### Alternative Approaches

For even more security in production apps, consider:
- **Keychain Services** for storing sensitive data
- **Environment variables** in CI/CD pipelines
- **Remote configuration** services
- **Code obfuscation** for additional protection 