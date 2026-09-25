# clipboardpass

Password manager for the cases when built-in mac passwords app does not fit. For example, ssh or rdp.

## Install

```sh
brew install --cask timurgaitov/tap/clipboardpass
```

Launch it once (adds a menu-bar icon), add a password, then press `⌘\` to search and copy behind Touch ID.

## Shortcuts

- `⌘\` — open the search panel; `⏎` copies the **password** (asks for Touch ID)
- `⇧⌘\` — open the search panel; `⏎` copies the **username** (no Touch ID)
- Pressing the other shortcut while the panel is open switches mode and keeps your query
- `↑` / `↓` — move the selection
- `⌘E` — edit the selected entry (label, username; leave password blank to keep it)
- `⌘⌫` — delete the selected entry
- *Edit Password* / *Delete Password* in the menu open the same panel; `⏎` then edits or deletes the selected entry
- `Esc` or click elsewhere — close the panel

Both global shortcuts are configurable in Settings.

## Getting passwords in from the Passwords app

macOS gives third-party apps no way to read the Passwords app / iCloud Keychain, so clipboardpass can't sync with it. To copy an item over: in *Add Password*, click the Username field and pick it from the AutoFill suggestion. Username and password fill in; give it a label and save.
