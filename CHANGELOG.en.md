# VoceChat Changelog

Changes since 0.3.29+29, through 0.3.37+37. Dates reflect version commits (UTC+8).

## 0.3.37 (2026-10-28)

- Retry push registration after temporary failures and resync after notification permission is granted or the app returns to the foreground.
- Enable iOS notification banners and sounds while the app is open.
- Allow removing saved servers and their stored sign-ins from this device, including when the server is unreachable.

## 0.3.36 (2026-10-27)

- Fix missed incoming messages when sending during a connection gap, and recover recent conversation history after reconnecting.
- Improve reconnection after credential errors, app resume, and network changes, including Wi-Fi to cellular transitions.
- Restore the last server chat layout on startup while waiting for live settings.

## 0.3.35 (2026-10-24)

- Respect server email privacy settings and keep account and contact details in sync. Fix empty-email displays and bot grouping.
- Fix the desktop sidebar disappearing after creating a channel.

## 0.3.34 (2026-10-24)

- Add adjustable text size with a live preview in Settings → Appearance.
- Improve chat layout and text wrapping for easier reading at larger text sizes.

## 0.3.33 (2026-10-20)

- Fix the emoji button, improve long group names and group details, and preserve descriptions when renaming groups.
- Add a pinned-message bar with quick navigation to the original message and access to all pins.

## 0.3.32 (2026-10-08)

- **Fixed links failing to open on Android**: Improved browser launching and added a copy-link action when opening fails.
- **Improved link appearance and tap reliability**: Links use consistent blue styling and remain tappable during interface updates.
- **Improved Markdown link support**: Correctly handle Markdown links in normal, quoted, edited, and forwarded messages while preserving literal syntax in plain-text messages.

## 0.3.31 (2026-10-07)

- **Added in-call camera switching and selection**: Switch between front and rear cameras on Android and iOS, or select an available camera device on Windows and macOS.
- **Fixed picture-in-picture for iOS video calls**: When the other participant has video enabled in a one-to-one call, continue watching them in picture-in-picture after moving the app to the background. Improved video continuity when returning to the app or switching to fullscreen.
- **Synced chat layout with server settings**: Messages can appear entirely on the left, or with your own messages on the right. Server setting changes take effect immediately, with avatars, quoted replies, and message actions adjusting to the layout.
- **Fixed failed-message ordering and status**: Failed messages keep their original position and display the correct failure status after reopening a chat or restarting the app.
- **Fixed duplicate messages after cache restoration**: Prevented some delivered messages from reappearing as duplicates or being incorrectly marked as failed when reopening a chat.
- **Improved retries for failed messages**: Restored failed text messages can be retried. Failed attachments that cannot be retried after an app restart no longer show an unavailable retry action.
- **Improved Avo avatar saving compatibility**: Fixed errors that could appear after a successful save on some servers. Servers that do not support saving Avo now show a clear message, including the server version when available.

## 0.3.30 (2026-10-01)

- **Corrected voice-message and audio-attachment handling**: In-app recordings are sent as voice messages and played inline in chat. Manually selected audio files appear as downloadable attachments.
- **Improved voice-message compatibility and previews**: More accurately recognized voice messages sent by other clients and displayed the correct voice previews in replies, favorites, and message lists.
- **Fixed retries for voice messages**: Retrying a failed recording preserves its voice-message format, preventing it from being sent as an ordinary file attachment.
