// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'VoceChat';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionChange => 'Change';

  @override
  String get actionContact => 'Contact';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionSend => 'Send';

  @override
  String get actionSearch => 'Search';

  @override
  String get actionMore => 'More';

  @override
  String get actionRetry => 'Retry';

  @override
  String get chatToolPin => 'Pinned';

  @override
  String get chatActionReact => 'Add reaction';

  @override
  String get chatActionReply => 'Reply';

  @override
  String get chatActionEdit => 'Edit';

  @override
  String get chatActionDelete => 'Delete';

  @override
  String get chatEditMarker => '(edited)';

  @override
  String chatReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String get chatDeleteConfirmTitle => 'Delete message?';

  @override
  String get chatDeleteConfirmBody => 'This cannot be undone.';

  @override
  String get chatEditCancel => 'Cancel';

  @override
  String get chatEditSave => 'Save';

  @override
  String get chatFileDetailsTitle => 'File details';

  @override
  String get chatFileNameLabel => 'Name';

  @override
  String chatEditFailed(String error) {
    return 'Edit failed: $error';
  }

  @override
  String chatDeleteFailed(String error) {
    return 'Delete failed: $error';
  }

  @override
  String chatReplyFailed(String error) {
    return 'Reply failed: $error';
  }

  @override
  String get chatReplyDeleted => 'This message has been deleted.';

  @override
  String get chatReplyVoiceMessage => '[Voice Message]';

  @override
  String get chatToolSaved => 'Saved';

  @override
  String get chatToolMembers => 'Members';

  @override
  String get chatToolEmpty => 'No content yet.';

  @override
  String get chatToolPinEmpty => 'No pinned messages.';

  @override
  String get chatToolSavedEmpty => 'No saved messages.';

  @override
  String get chatToolMembersEmpty => 'No members.';

  @override
  String get chatToolUnpin => 'Unpin';

  @override
  String get chatToolRemoveFav => 'Remove';

  @override
  String get chatToolPinFail => 'Pin failed';

  @override
  String get chatToolUnpinFail => 'Unpin failed';

  @override
  String get chatToolSaveFail => 'Save failed';

  @override
  String get chatToolRemoveFavFail => 'Remove failed';

  @override
  String get chatToolSavedAdded => 'Saved';

  @override
  String get chatToolPinAdded => 'Pinned';

  @override
  String get chatToolUnpinned => 'Unpinned';

  @override
  String get chatSearchHint => 'Search messages';

  @override
  String get chatSearchEmpty => 'No matching messages.';

  @override
  String get navChats => 'Chats';

  @override
  String get navContacts => 'Contacts';

  @override
  String get navSettings => 'Settings';

  @override
  String get navSaved => 'Saved';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get actionBack => 'Back';

  @override
  String get actionClose => 'Close';

  @override
  String get memberRoleOwner => 'Owner';

  @override
  String get tooltipDownload => 'Download';

  @override
  String get tooltipZoomIn => 'Zoom in';

  @override
  String get tooltipZoomOut => 'Zoom out';

  @override
  String get tooltipFullscreen => 'Fullscreen';

  @override
  String get tooltipExitFullscreen => 'Exit fullscreen';

  @override
  String get tooltipShowPassword => 'Show password';

  @override
  String get tooltipHidePassword => 'Hide password';

  @override
  String get reactionDeletedUser => 'Deleted User';

  @override
  String reactionTooltipMany(String names, int count, String emoji) {
    return '$names and $count others reacted with $emoji';
  }

  @override
  String reactionTooltipFew(String names, String emoji) {
    return '$names reacted with $emoji';
  }

  @override
  String get expiredImageTitle => 'Image not found';

  @override
  String get expiredImageBody => 'Image expired or deleted';

  @override
  String get expiredVideoTitle => 'Video not found';

  @override
  String get expiredVideoBody => 'Video expired or deleted';

  @override
  String get expiredAudioTitle => 'Audio not found';

  @override
  String get expiredAudioBody => 'Audio expired or deleted';

  @override
  String get expiredFileTitle => 'File not found';

  @override
  String get expiredFileBody => 'File expired or deleted';

  @override
  String get featureUnavailable => 'This feature is not available yet';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGroupGeneral => 'general';

  @override
  String get settingsGroupAbout => 'about';

  @override
  String get settingsMyAccount => 'My Account';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsStorage => 'Storage & Data';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsLogout => 'Log out';

  @override
  String get settingsLogoutConfirmTitle => 'Log out?';

  @override
  String get settingsLogoutConfirmContent =>
      'You will need to sign in again to access this server.';

  @override
  String get settingsSwitchAccount => 'Switch account';

  @override
  String get accountSwitcherTitle => 'Accounts';

  @override
  String get accountSwitcherAddAccount => 'Add account';

  @override
  String get accountSwitcherLogoutAll => 'Log out';

  @override
  String get accountSwitcherRemoveConfirmTitle => 'Remove this account?';

  @override
  String get accountSwitcherRemoveConfirmBody =>
      'This removes the saved sign-in and cached messages for this account on this device.';

  @override
  String get accountSwitcherRemove => 'Remove';

  @override
  String get accountSwitcherSignedOut => 'Signed out';

  @override
  String get accountSwitcherSwitchFailed =>
      'Couldn\'t sign in to that account — please log in again.';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountUsername => 'Username';

  @override
  String get accountPassword => 'Password';

  @override
  String get accountPasswordMasked => '*********';

  @override
  String get notificationsPush => 'Push notifications';

  @override
  String get notificationsPushSubtitle =>
      'Get notified about new messages and mentions.';

  @override
  String get notificationsSound => 'Notification sounds';

  @override
  String get notificationsSoundSubtitle => 'Play a chime on incoming messages.';

  @override
  String get notificationsMentionsOnly => 'Mentions only';

  @override
  String get notificationsMentionsOnlySubtitle => 'Only notify for @mentions.';

  @override
  String get appearanceTheme => 'THEME';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceSystem => 'System default';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceLanguage => 'LANGUAGE';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languagePortuguese => 'Português';

  @override
  String get storageUsage => 'Storage usage';

  @override
  String get storageAutoDownload => 'Auto-download media';

  @override
  String get storageWifiOnly => 'Wi-Fi only';

  @override
  String get storageClearCache => 'Clear cache';

  @override
  String get storageClearCacheConfirmTitle => 'Clear cache?';

  @override
  String get storageClearCacheConfirmBody =>
      'This removes locally cached messages and images. They will be re-downloaded as needed.';

  @override
  String get storageClearCacheConfirm => 'Clear';

  @override
  String get storageCacheCleared => 'Cache cleared';

  @override
  String get aboutAppVersion => 'App version';

  @override
  String get aboutWebsite => 'Website';

  @override
  String get aboutReportBug => 'Report a bug';

  @override
  String get aboutReportBugSubtitle => 'Help us improve VoceChat.';

  @override
  String get loginWelcomeBack => 'Welcome back';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailRequired => 'Email is required';

  @override
  String get loginEmailInvalid => 'Enter a valid email address';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginPasswordRequired => 'Password is required';

  @override
  String get loginPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get loginForgotPassword => 'Forgot password?';

  @override
  String get loginRememberMe => 'Remember password';

  @override
  String get loginSignIn => 'Sign in';

  @override
  String get loginMagicLink => 'Use magic link';

  @override
  String get loginPasskey => 'Sign in with passkey';

  @override
  String get loginSwitchServer => 'Switch server';

  @override
  String get loginNoAccount => 'Don\'t have an account? ';

  @override
  String get loginSignUp => 'Sign up';

  @override
  String get loginErrorInvalidCredentials => 'Incorrect email or password';

  @override
  String get loginErrorAccountFrozen =>
      'This account has been frozen. Contact your admin.';

  @override
  String get loginErrorNotInvited =>
      'No associated account found. Ask an admin for an invitation link.';

  @override
  String get loginErrorMethodNotSupported =>
      'This login method isn\'t supported by the server.';

  @override
  String get loginErrorCannotReachServer =>
      'Can\'t reach the server. Check your network or the server URL.';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerHeader => 'Join the conversation';

  @override
  String get registerSubtitle => 'Fill in your details to get started.';

  @override
  String get registerName => 'Full name';

  @override
  String get registerNameRequired => 'Name is required';

  @override
  String get registerNameTooShort => 'Name must be at least 2 characters';

  @override
  String get registerEmailRequired => 'Email is required';

  @override
  String get registerEmailInvalid => 'Enter a valid email';

  @override
  String get registerPasswordRequired => 'Password is required';

  @override
  String get registerPasswordTooShort => 'At least 6 characters required';

  @override
  String get registerConfirmPassword => 'Confirm password';

  @override
  String get registerConfirmRequired => 'Please confirm your password';

  @override
  String get registerConfirmMismatch => 'Passwords do not match';

  @override
  String get registerCreate => 'Create account';

  @override
  String get registerMagicLink => 'Send invitation link instead';

  @override
  String get registerEmailFirst => 'Please enter your email first';

  @override
  String get registerInvitationSent => 'Invitation link sent';

  @override
  String get registerHaveAccount => 'Already have an account? ';

  @override
  String get registerInviteRequiresEmailConfirmation =>
      'This server requires email confirmation for invited signups, which isn\'t supported yet. Please ask your admin for help.';

  @override
  String get serverPickerTitle => 'Select Server';

  @override
  String get serverPickerEmptyTitle => 'Connect to a VoceChat server';

  @override
  String get serverPickerEmptySubtitle =>
      'Add a server to get started chatting with your team.';

  @override
  String get serverPickerAddFirst => 'Add your first server';

  @override
  String get serverPickerAdd => 'Add server';

  @override
  String get serverPickerContinue => 'Continue';

  @override
  String get serverPickerUseInviteLink => 'Use invitation link';

  @override
  String get serverAddTitle => 'Add Server';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get serverUrlHint => 'https://chat.example.com';

  @override
  String get serverUrlRequired => 'URL is required';

  @override
  String get serverUrlMustHttps => 'Must start with https://';

  @override
  String get serverUrlHttpNotAllowed =>
      'Only https:// is allowed (http not permitted for remote servers)';

  @override
  String get serverTesting => 'Testing…';

  @override
  String get serverTestConnection => 'Test connection';

  @override
  String get serverTestSuccess => 'Connection successful';

  @override
  String get serverTestFailed => 'Could not connect to server';

  @override
  String get serverSave => 'Save & Continue';

  @override
  String get inviteLinkSheetTitle => 'Join with invitation link';

  @override
  String get inviteLinkHint => 'Paste your invitation link here';

  @override
  String get inviteLinkRequired => 'Please paste an invitation link';

  @override
  String get inviteLinkPasteFromClipboard => 'Paste from clipboard';

  @override
  String get inviteLinkInvalid =>
      'This doesn\'t look like a valid invitation link';

  @override
  String get inviteLinkExpired =>
      'This invitation link has expired or already been used';

  @override
  String get inviteLinkCheckFailed =>
      'Couldn\'t verify the invitation link. Check your network and try again.';

  @override
  String get inviteLinkContinue => 'Continue';

  @override
  String get chatListSearch => 'Search...';

  @override
  String get chatListNewChat => 'New chat';

  @override
  String get chatListLoading => 'Loading chats…';

  @override
  String get chatListUpdating => 'Updating…';

  @override
  String get chatListEmpty => 'No conversations yet';

  @override
  String chatListNoResults(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get chatListSelectTitle => 'Select a conversation';

  @override
  String get chatListSelectSubtitle =>
      'Pick a chat from the left panel to start messaging';

  @override
  String get chatListPin => 'Pin to top';

  @override
  String get chatListUnpin => 'Unpin';

  @override
  String chatListPinFailed(String error) {
    return 'Pin failed: $error';
  }

  @override
  String chatListUnpinFailed(String error) {
    return 'Unpin failed: $error';
  }

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    return '$count mins ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get contactsSearch => 'Search...';

  @override
  String get contactsAdd => 'Add contact';

  @override
  String get contactsLoading => 'Loading contacts…';

  @override
  String get contactsEmpty => 'No contacts found';

  @override
  String contactsSectionBot(int count) {
    return 'BOT - $count';
  }

  @override
  String contactsSectionContact(int count) {
    return 'CONTACT - $count';
  }

  @override
  String get contactsSelectTitle => 'Select a contact';

  @override
  String get contactsSelectSubtitle =>
      'Pick someone from the list to see their profile';

  @override
  String get contactsMessage => 'Message';

  @override
  String get contactsCall => 'Call';

  @override
  String get chatLoadingMessages => 'Loading messages…';

  @override
  String get chatStatusOnline => 'Online';

  @override
  String get chatStatusOffline => 'Offline';

  @override
  String get chatGroupIntro => 'Introduce yourself to the community!';

  @override
  String get chatEmpty => 'No messages yet';

  @override
  String chatSendFailed(String error) {
    return 'Send failed: $error';
  }

  @override
  String chatMessagePlaceholderChannel(String name) {
    return 'Message #$name';
  }

  @override
  String chatMessagePlaceholderUser(String name) {
    return 'Message $name';
  }

  @override
  String get chatPinned => 'pinned';

  @override
  String get chatUnsupported => '[unsupported message]';

  @override
  String get chatMarkdown => 'Markdown';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatVoiceMessage => 'Voice Message';

  @override
  String get chatVideoMessage => 'Video Message';

  @override
  String get chatVoiceRecording => 'Recording voice message';

  @override
  String get chatVoiceRecordingCancel => 'Cancel';

  @override
  String get chatVoiceRecordingSend => 'Send';

  @override
  String get chatRecordingPermissionDenied =>
      'Permission denied — enable microphone/camera access in system settings';

  @override
  String get chatPhotoPermissionDenied =>
      'Permission denied — enable photo library access in system settings';

  @override
  String get chatAttachOpenFiles => 'Files';

  @override
  String get chatAttachCamera => 'Camera';

  @override
  String chatAttachSend(int count) {
    return 'Send ($count)';
  }

  @override
  String chatDropOverlayTitle(String name) {
    return 'Send to $name';
  }

  @override
  String get chatDropOverlayHint => 'Drop files here to send them';

  @override
  String get chatEmoji => 'Emoji';

  @override
  String chatUserFallback(int uid) {
    return 'User $uid';
  }

  @override
  String chatGroupFallback(int gid) {
    return 'Group $gid';
  }

  @override
  String get previewFile => '[File]';

  @override
  String get previewVoice => '[Voice]';

  @override
  String get previewArchive => '[Archive]';

  @override
  String get previewImage => '[Image]';

  @override
  String get previewReaction => '[Reaction]';

  @override
  String errorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String get errorRequestFailed => 'Request failed';

  @override
  String get authKickedFromOtherDevice =>
      'Signed out: your account just signed in on another device.';

  @override
  String get authAccountDeleted => 'Your account has been deleted.';

  @override
  String get authSessionEnded => 'Your session ended. Please sign in again.';

  @override
  String get chatListMarkRead => 'Mark as read';

  @override
  String get chatListMute => 'Mute';

  @override
  String get chatListUnmute => 'Unmute';

  @override
  String get chatListHide => 'Hide';

  @override
  String get chatListLeave => 'Leave channel';

  @override
  String get chatListMarkReadDone => 'Marked as read';

  @override
  String get chatListMuteDone => 'Muted';

  @override
  String get chatListUnmuteDone => 'Unmuted';

  @override
  String get chatListHideDone => 'Hidden';

  @override
  String get chatListLeaveDone => 'Left channel';

  @override
  String chatListLeaveFailed(String error) {
    return 'Leave failed: $error';
  }

  @override
  String chatListMuteFailed(String error) {
    return 'Mute failed: $error';
  }

  @override
  String get chatListMarkReadFailed => 'Mark read failed';

  @override
  String get createChannelTitle => 'New Channel';

  @override
  String get createChannelNameLabel => 'Channel name';

  @override
  String get channelPublicLabel => 'Public channel';

  @override
  String get createChannelPublicAdminOnly =>
      'Only admins can create public channels';

  @override
  String get createChannelSubmit => 'Create';

  @override
  String get createChannelNameRequired => 'Please input a channel name';

  @override
  String get createChannelFailed => 'Failed to create channel';

  @override
  String get channelSettingsTitle => 'Channel settings';

  @override
  String get channelUpdated => 'Channel updated';

  @override
  String get avatarUpdated => 'Avatar updated';

  @override
  String get channelVisibilityChanged => 'Visibility changed';

  @override
  String get inviteLinkCopied => 'Link copied';

  @override
  String get channelOverview => 'Overview';

  @override
  String get channelNameLabel => 'Name';

  @override
  String get channelDescriptionLabel => 'Description';

  @override
  String get channelSaveChanges => 'Save changes';

  @override
  String get channelAddMember => 'Add member';

  @override
  String get channelInviteLinkSection => 'Invite link';

  @override
  String get channelGenerateInviteLink => 'Generate invite link';

  @override
  String get channelMuteLabel => 'Mute channel';

  @override
  String get channelLeaveConfirmBody =>
      'Are you sure you want to leave this channel?';

  @override
  String get channelDeleteTitle => 'Delete channel';

  @override
  String get channelDeleteConfirmBody =>
      'This will permanently delete the channel for all members. This cannot be undone.';

  @override
  String get actionLeave => 'Leave';

  @override
  String get accountEditNameTitle => 'Edit name';

  @override
  String get accountNameLabel => 'Name';

  @override
  String get accountNameUpdated => 'Name updated';

  @override
  String get accountChangePasswordTitle => 'Change password';

  @override
  String get accountCurrentPasswordLabel => 'Current password';

  @override
  String get accountNewPasswordLabel => 'New password';

  @override
  String get accountPasswordChanged => 'Password changed';

  @override
  String get chatActionCopy => 'Copy';

  @override
  String get chatActionForward => 'Forward';

  @override
  String get chatActionSelect => 'Select';

  @override
  String get chatCopiedToClipboard => 'Copied to clipboard';

  @override
  String get chatForwardedMessagePreview => '[Forwarded message]';

  @override
  String get chatAutoDeleteTitle => 'Auto-delete messages';

  @override
  String chatExpiresTooltip(String duration) {
    return 'Disappears $duration after being sent';
  }

  @override
  String get chatAutoDeleteOff => 'Off';

  @override
  String get chatAutoDelete5Min => '5 minutes';

  @override
  String get chatAutoDelete10Min => '10 minutes';

  @override
  String get chatAutoDelete1Hour => '1 hour';

  @override
  String get chatAutoDelete1Day => '1 day';

  @override
  String get chatAutoDelete1Week => '1 week';

  @override
  String get chatAutoDeleteSaved => 'Saved';

  @override
  String get chatAutoDeleteSaveFailed => 'Save failed';

  @override
  String get forwardSheetTitle => 'Forward to...';

  @override
  String get forwardMessageSent => 'Message forwarded';

  @override
  String forwardFailed(String error) {
    return 'Forward failed: $error';
  }

  @override
  String get forwardNoConversations => 'No conversations';

  @override
  String forwardSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get archiveForwardedLabel => 'Forwarded message(s)';

  @override
  String get archiveLoadFailed => 'Failed to load forwarded message';

  @override
  String get archiveTapToView => 'Tap to view details';

  @override
  String archiveViewAll(int count) {
    return 'View all $count messages';
  }
}
