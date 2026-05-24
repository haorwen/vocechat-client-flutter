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
  String get settingsLogoutConfirmContent => 'You will need to sign in again to access this server.';

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
  String get notificationsPushSubtitle => 'Get notified about new messages and mentions.';

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
  String get storageUsage => 'Storage usage';

  @override
  String get storageAutoDownload => 'Auto-download media';

  @override
  String get storageWifiOnly => 'Wi-Fi only';

  @override
  String get storageClearCache => 'Clear cache';

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
  String get serverPickerTitle => 'Select Server';

  @override
  String get serverPickerEmptyTitle => 'Connect to a VoceChat server';

  @override
  String get serverPickerEmptySubtitle => 'Add a server to get started chatting with your team.';

  @override
  String get serverPickerAddFirst => 'Add your first server';

  @override
  String get serverPickerAdd => 'Add server';

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
  String get serverUrlHttpNotAllowed => 'Only https:// is allowed (http not permitted for remote servers)';

  @override
  String get serverAlias => 'Alias (optional)';

  @override
  String get serverAliasHint => 'My Work Server';

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
  String get chatListSelectSubtitle => 'Pick a chat from the left panel to start messaging';

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
  String get contactsSelectSubtitle => 'Pick someone from the list to see their profile';

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
}
