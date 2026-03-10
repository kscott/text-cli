# sms-cli

Fast CLI for iMessage and SMS. Send messages and view conversation history directly from the terminal.

## Installation

```bash
git clone https://github.com/kscott/sms-cli ~/dev/sms-cli
~/dev/sms-cli/sms setup
```

**Permissions required:**
- **Contacts** — for resolving names to phone numbers (prompted on first run)
- **Full Disk Access** — for `sms list` and `sms show` to read message history from `~/Library/Messages/chat.db`
  Grant in: System Settings → Privacy & Security → Full Disk Access → Terminal (or iTerm2)

Requires macOS 14+.

## Commands

```
sms send <contact> <message...>     # Send an iMessage or SMS
sms list [n]                        # Recent conversations (default 10)
sms show <contact>                  # Message history with a contact
sms open [contact]                  # Open Messages.app
```

## Examples

```bash
# Send by contact name (no quoting needed for first names)
sms send Alice Hey, are you free tonight?

# Send to a phone number directly
sms send 555-867-5309 On my way

# Send to an email address (iMessage)
sms send alice@example.com Can you call me?

# Recent conversations
sms list
sms list 20

# Full history with someone
sms show Alice
sms show "Alice Smith"

# Open Messages.app to a specific conversation
sms open Alice
```

## Contact resolution

1. Direct phone number (10 or 11 digits) → normalized to E.164 (+1XXXXXXXXXX)
2. Direct email address → used as-is
3. Fuzzy name match in Contacts → primary phone number, or email if no phone

## How it works

- **Send** — AppleScript via `osascript` to Messages.app (handles both iMessage and SMS fallback)
- **List / Show** — direct SQLite read from `~/Library/Messages/chat.db` (fast; requires Full Disk Access)
- **Contact lookup** — CNContactStore for name → phone/email resolution and display name enrichment

## Build & test

```bash
sms setup   # build release binary and install to ~/bin
sms test    # build and run test suite (45 tests)
```

## Project structure

- `Sources/MessagesLib/PhoneNormalizer.swift` — phone normalization, matching, contact resolution
- `Sources/MessagesCLI/main.swift` — SQLite reads, AppleScript send, CNContactStore, dispatch
- `Tests/MessagesLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `sms` — bash wrapper script, symlinked into `~/bin`

## Known limitations

- Group chats show by thread ID rather than participant names (improvement: Issue #1)
- Reactions and tapbacks appear as empty messages in history
- Sending requires Messages.app to be configured with an active iMessage account
- Full Disk Access required for read operations (macOS security restriction)
