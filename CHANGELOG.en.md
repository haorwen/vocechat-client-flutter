# VoceChat Changelog

Changes since 0.3.29+29, through 0.3.33+33. Dates reflect version commits (UTC+8).

## 0.3.33 (2026-10-20)

- **Fixed the unresponsive emoji button**: Open the emoji picker and insert an emoji at the cursor, or replace selected text.
- **Improved long group names**: Group names use a slightly smaller font and wrap to two lines. The description appears below the name to give both more room.
- **Added full group details**: Tap the header to read and copy the complete group name and description. Empty descriptions no longer show a row or placeholder text.
- **Prevented accidental loss of group descriptions**: Settings now load the existing description correctly, so renaming a group preserves it.
- **Added a pinned-message bar below the chat header**: Tap to jump to and highlight the original message. Older messages load automatically, and multiple pins can be cycled through.
- **Improved pinned-message controls and live updates**: View all pins, jump to a message, or unpin it. Group details and pinned-message changes from other devices update in real time, with feedback when a message cannot be loaded.

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
