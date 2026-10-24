# readwise-ai-watchapp v1.1

A standalone Apple Watch app that fetches and displays your latest AI-generated news briefing from [Readwise Reader](https://readwise.io/read).

Designed to work with [readwise-ai](https://github.com/samikki/readwise-ai), which generates short watch summaries and saves them to your Readwise library with a `WatchSummary` tag.

## Features

- Fetches the latest watch briefing from Readwise
- Renders formatted text with bold headings
- Scrollable with the Digital Crown
- Shows when the briefing was generated ("News at 08:00")
- Auto-refreshes when returning from background after 15+ minutes
- Manual refresh button in the toolbar

## Requirements

- Xcode 26.3 (the version the project was last saved with, per `LastUpgradeCheck = 2630` in `project.pbxproj`; older Xcode versions are untested)
- watchOS 10+
- A [Readwise](https://readwise.io) account with Reader
- The [readwise-ai](https://github.com/samikki/readwise-ai) backend running to generate watch summaries

## Setup

### 1. Configure your bundle ID

Open `ReadwiseWatch.xcodeproj` in Xcode and change the bundle identifier from `fi.pinseri.ReadwiseBriefing.watchkitapp` to your own reverse-domain format (e.g. `com.yourname.ReadwiseBriefing.watchkitapp`).

Also update `ReadwiseWatch/Info.plist` — change `WKCompanionAppBundleIdentifier` to match your prefix (e.g. `com.yourname.ReadwiseBriefing`).

And update `ReadwiseWatch/Services/TokenStorage.swift` — change the `service` constant to match your bundle ID.

### 2. Set up your Readwise token

Copy the example secrets file:

```bash
cp Secrets.example.swift ReadwiseWatch/Secrets.swift
```

Edit `ReadwiseWatch/Secrets.swift` and add your Readwise token:

```swift
enum Secrets {
    static let readwiseToken = "your_readwise_token_here"
}
```

`Secrets.swift` is gitignored and will never be committed.

> [!WARNING]
> **Never share or distribute a build of this app.** The token in `Secrets.swift` is compiled into the app binary, and anyone with a copy of the build can extract it. A Readwise token gives full read/write access to your entire Readwise library.

`TokenStorage.swift` contains a Keychain lookup, but that path is currently unused: `saveToken` has no caller, so nothing is ever written to the Keychain and the token always comes from `Secrets.swift`.

Your Readwise token is at [readwise.io/access_token](https://readwise.io/access_token).

### 3. Configure signing

Copy the example config and set your Apple Developer Team ID:

```bash
cp Local.example.xcconfig Local.xcconfig
```

Edit `Local.xcconfig`:

```
DEVELOPMENT_TEAM = YOUR_TEAM_ID_HERE
```

Find your Team ID in Xcode → Settings → Accounts → your account → Team ID column.

`Local.xcconfig` is gitignored and will never be committed.

### 4. Build and run

Select your Apple Watch as the destination and press **⌘R**.

**Note:** Deploying to a physical watch requires the watch to be paired with an iPhone connected to your Mac. The first deployment copies debug symbols (~5 minutes); subsequent deployments are faster.

## How it works

The app calls the Readwise Reader API (`/api/v3/list/`) and looks for the most recently created document tagged `WatchSummary`. The displayed text comes from the document's `html_content` field (requested with `withHtmlContent=true` and stripped to plain text), falling back to the `summary` field when `html_content` is empty (see `ReadwiseWatch/Models/ReadwiseDocument.swift`). The text is rendered with basic bold formatting.

The [readwise-ai](https://github.com/samikki/readwise-ai) backend generates these watch summaries and saves them with the correct tag. Run it with:

```bash
python build.py --watch
```

Or automate it with a cron job every few hours.

## Known limitations

- Only the first page of the list API response is read; `nextPageCursor` is ignored. If many documents were added or updated after the latest briefing, it may not be found.
- The newest briefing is assumed to be the first `WatchSummary`-tagged result; results are not sorted by date in the app.
- There are no tests.

## File layout

| File | Purpose |
|---|---|
| `ReadwiseWatch/ContentView.swift` | Main UI — scroll view, formatting, auto-refresh logic |
| `ReadwiseWatch/Models/ReadwiseDocument.swift` | Readwise API response model |
| `ReadwiseWatch/Services/ReadwiseAPIService.swift` | API client with retry logic |
| `ReadwiseWatch/Services/TokenStorage.swift` | Token lookup (Secrets.swift; Keychain lookup present but currently unused) |
| `ReadwiseWatch/Info.plist` | watchOS app configuration |
| `Secrets.example.swift` | Template for your token file |
| `Local.xcconfig` | Your team ID for signing (gitignored) |
| `Local.example.xcconfig` | Template for the signing config |
