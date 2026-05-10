/// UI-only send status for outbound messages.
/// Not persisted; lives only in ChatController._statuses.
enum MessageSendStatus { sending, sent, failed }
