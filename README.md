# text-cli

Send iMessages and SMS from the terminal. Fire and forget.

## Installation

```bash
git clone https://github.com/kscott/text-cli ~/dev/text-cli
~/dev/text-cli/text setup
```

**Permissions required:**
- **Contacts** — for resolving names to phone numbers (prompted on first run)

Requires macOS 14+.

## Commands

```
text send <contact> <message...>     # Send an iMessage or SMS
text open [contact]                  # Open Messages.app
```

## Examples

```bash
# Send by contact name
text send Alice Hey, are you free tonight?
text send "Alice Smith" Dinner at 7?

# Send to a phone number directly
text send 555-867-5309 On my way

# Send to an email address (iMessage)
text send alice@example.com Can you call me?

# Open Messages.app
text open
text open Alice     # opens directly to that conversation
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
text setup   # build release binary and install to ~/bin
text test    # build and run test suite (45 tests)
```

## Project structure

- `Sources/MessagesLib/PhoneNormalizer.swift` — phone normalization, matching, contact resolution
- `Sources/MessagesCLI/main.swift` — AppleScript send, CNContactStore, dispatch
- `Tests/MessagesLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `text` — bash wrapper script, symlinked into `~/bin`

## Key decisions

- **Send only** — iMessage has no public read API; AppleScript for send is the standard approach and fast for a single message
- **No database reads** — reading `~/Library/Messages/chat.db` requires Full Disk Access and relies on an undocumented schema; not worth it for a fire-and-forget tool
- **MessagesLib separated from MessagesCLI** — phone normalization and matching are testable without permissions
