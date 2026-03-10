# Development conventions

Patterns and decisions established for this project. Follow these when adding or changing anything.

## Architecture: what goes where

**`MessagesLib`** — pure Swift, no framework dependencies
- Phone number normalization (`normalizePhone`, `phoneMatches`, `formatPhone`)
- Contact name resolution (`resolveIdentifier`, `resolveSendTarget`)
- `MessageContact` struct — name, phones, emails
- Anything that can be expressed as `String → String` or `String → MessageContact?`

**`MessagesCLI/main.swift`** — system and data access only
- Argument parsing and command dispatch
- CNContactStore for contact loading (converts to `[MessageContact]` for MessagesLib)
- SQLite reads from `~/Library/Messages/chat.db`
- AppleScript via `osascript` for sending
- Date formatting helpers

The rule: if you find yourself wanting to test something that lives in `main.swift`, that's a sign it should be moved to `MessagesLib`.

## Interface design: positional arguments

```
sms send <contact> <message...>   # contact is args[1], message is args[2...]
sms show <contact>                # contact is args[1] (joined with spaces)
sms list [n]                      # n is optional, default 10
sms open [contact]                # contact is optional
```

Multi-word contact names need quoting for `send` (since message consumes all remaining tokens).
For `show` and `open`, the entire args[1...] are joined as the contact query.

## AppleScript injection safety

`appleScriptLiteral()` handles string embedding safely by splitting on double quotes and rejoining with AppleScript's `quote` constant:
```
"Hello "world""  →  "Hello " & quote & "world" & quote & ""
```
Scripts are written to a temp file (not passed as `-e` args) to avoid shell escaping issues and length limits.

## SQLite date conversion

chat.db stores dates as nanoseconds since Apple epoch (2001-01-01) on macOS 10.15+.
`appleDate(_ raw: Int64) -> Date` handles both ns (>1e12) and s (<1e12) for compatibility.

Apple epoch offset from Unix: 978307200 seconds.

## Phone number normalization

`normalizePhone()` targets E.164 format for US numbers:
- 10 digits → `+1XXXXXXXXXX`
- 11 digits starting with 1 → `+1XXXXXXXXXX`
- Already has `+` → strip formatting, keep `+`
- Email addresses → pass through unchanged

`phoneMatches()` compares the last 10 digits, tolerating format differences (+1 vs no prefix).

## chat.db schema (relevant tables)

| Table | Key fields |
|-------|-----------|
| `message` | ROWID, text, date (ns), is_from_me, handle_id |
| `handle` | ROWID, id (phone/email), service |
| `chat` | ROWID, chat_identifier, display_name |
| `chat_message_join` | chat_id, message_id |
| `chat_handle_join` | chat_id, handle_id |

`chat_identifier` for 1:1 chats = phone in E.164 or email address.
For group chats = a GUID-like string.

## Testing

- All test-worthy logic lives in `MessagesLib`
- Tests in `Tests/MessagesLibTests/main.swift` — custom runner, no XCTest or Xcode
- Run with `sms test`
- Cover: normalization edge cases, format variants, email pass-through, match/no-match

## Output conventions

| Command | Format |
|---------|--------|
| `send` | `Sent to Name (address)` |
| `list` | Index, date (8), name (22), preview (50) — one per line |
| `show` | `--- Name ---` header, then `date  Who: message` per line |
