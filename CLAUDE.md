# sms-cli

Swift CLI for iMessage/SMS via Messages.app and chat.db.

## Build & run

```bash
sms setup   # build release binary and install to ~/bin
sms test    # build and run test suite
```

## Project structure

- `Sources/MessagesLib/PhoneNormalizer.swift` — pure phone normalization and contact resolution
- `Sources/MessagesCLI/main.swift` — CLI entry point: SQLite, AppleScript, CNContactStore
- `Tests/MessagesLibTests/main.swift` — custom test runner (no Xcode/XCTest required)
- `sms` — bash wrapper script, symlinked into `~/bin`

See [DEVELOPMENT.md](DEVELOPMENT.md) for coding conventions and patterns.

## Commands

```
sms send <contact> <message...>     # Send an iMessage or SMS
sms list [n]                        # Recent conversations (default 10)
sms show <contact>                  # Message history with a contact
sms open [contact]                  # Open Messages.app
```

## Key decisions

- **AppleScript for send** — no public Swift framework for sending iMessages; osascript via Messages.app is the standard approach
- **SQLite for read** — direct read from chat.db is fast; avoids slow AppleScript enumeration
- **MessagesLib separated from MessagesCLI** — phone normalization and matching are testable without permissions
- **Custom test runner** — works with CLT only, no full Xcode needed

## Permissions

- Contacts access — prompted at first run (CNContactStore)
- Full Disk Access — required for chat.db reads (grant to Terminal/iTerm2 in System Settings)

## Adding a new command

1. Add the case to the `switch cmd` block in `main.swift`
2. Add it to `usage()`
3. Add it to the command table in `README.md` and `CLAUDE.md`
4. If the command introduces new matching logic, add it to `MessagesLib` with tests
