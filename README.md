# sms-cli

Send iMessages and SMS from the terminal. Fire and forget.

## Installation

```bash
git clone https://github.com/kscott/sms-cli ~/dev/sms-cli
~/dev/sms-cli/sms setup
```

**Permissions required:**
- **Contacts** — for resolving names to phone numbers (prompted on first run)

Requires macOS 14+.

## Commands

```
sms send <contact> <message...>     # Send an iMessage or SMS
sms open [contact]                  # Open Messages.app
```

## Examples

```bash
# Send by contact name
sms send Alice Hey, are you free tonight?
sms send "Alice Smith" Dinner at 7?

# Send to a phone number directly
sms send 555-867-5309 On my way

# Send to an email address (iMessage)
sms send alice@example.com Can you call me?

# Open Messages.app
sms open
sms open Alice     # opens directly to that conversation
```

## Contact resolution

1. Direct phone number (10 or 11 digits) → normalized to E.164 (+1XXXXXXXXXX)
2. Direct email address → used as-is for iMessage
3. Fuzzy name match in Contacts → first phone number, or email if no phone

## How it works

- **Send** — AppleScript via `osascript` to Messages.app (handles iMessage with SMS fallback via iPhone)
- **Contact lookup** — CNContactStore for name → phone/email resolution

## Build & test

```bash
sms setup   # build release binary and install to ~/bin
sms test    # build and run test suite (45 tests)
```

## Project structure

- `Sources/MessagesLib/PhoneNormalizer.swift` — phone normalization, matching, contact resolution
- `Sources/MessagesCLI/main.swift` — AppleScript send, CNContactStore, dispatch
- `Tests/MessagesLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `sms` — bash wrapper script, symlinked into `~/bin`

## Key decisions

- **Send only** — iMessage has no public read API; AppleScript for send is the standard approach and fast for a single message
- **No database reads** — reading `~/Library/Messages/chat.db` requires Full Disk Access and relies on an undocumented schema; not worth it for a fire-and-forget tool
- **MessagesLib separated from MessagesCLI** — phone normalization and matching are testable without permissions
