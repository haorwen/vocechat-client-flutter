import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// Application title
  ///
  /// In en, this message translates to:
  /// **'VoceChat'**
  String get appTitle;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get actionOpen;

  /// No description provided for @actionChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get actionChange;

  /// No description provided for @actionContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get actionContact;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @actionSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get actionSearch;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get actionMore;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get actionRetry;

  /// No description provided for @chatToolPin.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get chatToolPin;

  /// No description provided for @chatToolSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get chatToolSaved;

  /// No description provided for @chatToolMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get chatToolMembers;

  /// No description provided for @chatToolEmpty.
  ///
  /// In en, this message translates to:
  /// **'No content yet.'**
  String get chatToolEmpty;

  /// No description provided for @chatToolPinEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pinned messages.'**
  String get chatToolPinEmpty;

  /// No description provided for @chatToolSavedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved messages.'**
  String get chatToolSavedEmpty;

  /// No description provided for @chatToolMembersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No members.'**
  String get chatToolMembersEmpty;

  /// No description provided for @chatToolUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatToolUnpin;

  /// No description provided for @chatToolRemoveFav.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get chatToolRemoveFav;

  /// No description provided for @chatToolPinFail.
  ///
  /// In en, this message translates to:
  /// **'Pin failed'**
  String get chatToolPinFail;

  /// No description provided for @chatToolUnpinFail.
  ///
  /// In en, this message translates to:
  /// **'Unpin failed'**
  String get chatToolUnpinFail;

  /// No description provided for @chatToolSaveFail.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get chatToolSaveFail;

  /// No description provided for @chatToolRemoveFavFail.
  ///
  /// In en, this message translates to:
  /// **'Remove failed'**
  String get chatToolRemoveFavFail;

  /// No description provided for @chatToolSavedAdded.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get chatToolSavedAdded;

  /// No description provided for @chatToolPinAdded.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get chatToolPinAdded;

  /// No description provided for @chatToolUnpinned.
  ///
  /// In en, this message translates to:
  /// **'Unpinned'**
  String get chatToolUnpinned;

  /// No description provided for @chatSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search messages'**
  String get chatSearchHint;

  /// No description provided for @chatSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching messages.'**
  String get chatSearchEmpty;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsGroupGeneral.
  ///
  /// In en, this message translates to:
  /// **'general'**
  String get settingsGroupGeneral;

  /// No description provided for @settingsGroupAbout.
  ///
  /// In en, this message translates to:
  /// **'about'**
  String get settingsGroupAbout;

  /// No description provided for @settingsMyAccount.
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get settingsMyAccount;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage & Data'**
  String get settingsStorage;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get settingsLogoutConfirmTitle;

  /// No description provided for @settingsLogoutConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to access this server.'**
  String get settingsLogoutConfirmContent;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// No description provided for @accountUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get accountUsername;

  /// No description provided for @accountPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accountPassword;

  /// No description provided for @accountPasswordMasked.
  ///
  /// In en, this message translates to:
  /// **'*********'**
  String get accountPasswordMasked;

  /// No description provided for @notificationsPush.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notificationsPush;

  /// No description provided for @notificationsPushSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get notified about new messages and mentions.'**
  String get notificationsPushSubtitle;

  /// No description provided for @notificationsSound.
  ///
  /// In en, this message translates to:
  /// **'Notification sounds'**
  String get notificationsSound;

  /// No description provided for @notificationsSoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play a chime on incoming messages.'**
  String get notificationsSoundSubtitle;

  /// No description provided for @notificationsMentionsOnly.
  ///
  /// In en, this message translates to:
  /// **'Mentions only'**
  String get notificationsMentionsOnly;

  /// No description provided for @notificationsMentionsOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only notify for @mentions.'**
  String get notificationsMentionsOnlySubtitle;

  /// No description provided for @appearanceTheme.
  ///
  /// In en, this message translates to:
  /// **'THEME'**
  String get appearanceTheme;

  /// No description provided for @appearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get appearanceLight;

  /// No description provided for @appearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get appearanceSystem;

  /// No description provided for @appearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get appearanceDark;

  /// No description provided for @appearanceLanguage.
  ///
  /// In en, this message translates to:
  /// **'LANGUAGE'**
  String get appearanceLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// No description provided for @storageUsage.
  ///
  /// In en, this message translates to:
  /// **'Storage usage'**
  String get storageUsage;

  /// No description provided for @storageAutoDownload.
  ///
  /// In en, this message translates to:
  /// **'Auto-download media'**
  String get storageAutoDownload;

  /// No description provided for @storageWifiOnly.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi only'**
  String get storageWifiOnly;

  /// No description provided for @storageClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get storageClearCache;

  /// No description provided for @aboutAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get aboutAppVersion;

  /// No description provided for @aboutWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get aboutWebsite;

  /// No description provided for @aboutReportBug.
  ///
  /// In en, this message translates to:
  /// **'Report a bug'**
  String get aboutReportBug;

  /// No description provided for @aboutReportBugSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us improve VoceChat.'**
  String get aboutReportBugSubtitle;

  /// No description provided for @loginWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginWelcomeBack;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get loginEmailRequired;

  /// No description provided for @loginEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get loginEmailInvalid;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get loginPasswordRequired;

  /// No description provided for @loginPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get loginPasswordTooShort;

  /// No description provided for @loginForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get loginForgotPassword;

  /// No description provided for @loginSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginSignIn;

  /// No description provided for @loginMagicLink.
  ///
  /// In en, this message translates to:
  /// **'Use magic link'**
  String get loginMagicLink;

  /// No description provided for @loginPasskey.
  ///
  /// In en, this message translates to:
  /// **'Sign in with passkey'**
  String get loginPasskey;

  /// No description provided for @loginSwitchServer.
  ///
  /// In en, this message translates to:
  /// **'Switch server'**
  String get loginSwitchServer;

  /// No description provided for @loginNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get loginNoAccount;

  /// No description provided for @loginSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get loginSignUp;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitle;

  /// No description provided for @registerHeader.
  ///
  /// In en, this message translates to:
  /// **'Join the conversation'**
  String get registerHeader;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill in your details to get started.'**
  String get registerSubtitle;

  /// No description provided for @registerName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get registerName;

  /// No description provided for @registerNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get registerNameRequired;

  /// No description provided for @registerNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get registerNameTooShort;

  /// No description provided for @registerEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get registerEmailRequired;

  /// No description provided for @registerEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get registerEmailInvalid;

  /// No description provided for @registerPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get registerPasswordRequired;

  /// No description provided for @registerPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters required'**
  String get registerPasswordTooShort;

  /// No description provided for @registerConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get registerConfirmPassword;

  /// No description provided for @registerConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get registerConfirmRequired;

  /// No description provided for @registerConfirmMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get registerConfirmMismatch;

  /// No description provided for @registerCreate.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerCreate;

  /// No description provided for @registerMagicLink.
  ///
  /// In en, this message translates to:
  /// **'Send invitation link instead'**
  String get registerMagicLink;

  /// No description provided for @registerEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email first'**
  String get registerEmailFirst;

  /// No description provided for @registerInvitationSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation link sent'**
  String get registerInvitationSent;

  /// No description provided for @registerHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get registerHaveAccount;

  /// No description provided for @serverPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Server'**
  String get serverPickerTitle;

  /// No description provided for @serverPickerEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect to a VoceChat server'**
  String get serverPickerEmptyTitle;

  /// No description provided for @serverPickerEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a server to get started chatting with your team.'**
  String get serverPickerEmptySubtitle;

  /// No description provided for @serverPickerAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your first server'**
  String get serverPickerAddFirst;

  /// No description provided for @serverPickerAdd.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get serverPickerAdd;

  /// No description provided for @serverAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Server'**
  String get serverAddTitle;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @serverUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://chat.example.com'**
  String get serverUrlHint;

  /// No description provided for @serverUrlRequired.
  ///
  /// In en, this message translates to:
  /// **'URL is required'**
  String get serverUrlRequired;

  /// No description provided for @serverUrlMustHttps.
  ///
  /// In en, this message translates to:
  /// **'Must start with https://'**
  String get serverUrlMustHttps;

  /// No description provided for @serverUrlHttpNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Only https:// is allowed (http not permitted for remote servers)'**
  String get serverUrlHttpNotAllowed;

  /// No description provided for @serverAlias.
  ///
  /// In en, this message translates to:
  /// **'Alias (optional)'**
  String get serverAlias;

  /// No description provided for @serverAliasHint.
  ///
  /// In en, this message translates to:
  /// **'My Work Server'**
  String get serverAliasHint;

  /// No description provided for @serverTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing…'**
  String get serverTesting;

  /// No description provided for @serverTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get serverTestConnection;

  /// No description provided for @serverTestSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get serverTestSuccess;

  /// No description provided for @serverTestFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not connect to server'**
  String get serverTestFailed;

  /// No description provided for @serverSave.
  ///
  /// In en, this message translates to:
  /// **'Save & Continue'**
  String get serverSave;

  /// No description provided for @chatListSearch.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get chatListSearch;

  /// No description provided for @chatListNewChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatListNewChat;

  /// No description provided for @chatListLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading chats…'**
  String get chatListLoading;

  /// No description provided for @chatListUpdating.
  ///
  /// In en, this message translates to:
  /// **'Updating…'**
  String get chatListUpdating;

  /// No description provided for @chatListEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet'**
  String get chatListEmpty;

  /// No description provided for @chatListNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String chatListNoResults(String query);

  /// No description provided for @chatListSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a conversation'**
  String get chatListSelectTitle;

  /// No description provided for @chatListSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a chat from the left panel to start messaging'**
  String get chatListSelectSubtitle;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} mins ago'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String timeHoursAgo(int count);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String timeDaysAgo(int count);

  /// No description provided for @contactsSearch.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get contactsSearch;

  /// No description provided for @contactsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add contact'**
  String get contactsAdd;

  /// No description provided for @contactsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading contacts…'**
  String get contactsLoading;

  /// No description provided for @contactsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No contacts found'**
  String get contactsEmpty;

  /// No description provided for @contactsSectionBot.
  ///
  /// In en, this message translates to:
  /// **'BOT - {count}'**
  String contactsSectionBot(int count);

  /// No description provided for @contactsSectionContact.
  ///
  /// In en, this message translates to:
  /// **'CONTACT - {count}'**
  String contactsSectionContact(int count);

  /// No description provided for @contactsSelectTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a contact'**
  String get contactsSelectTitle;

  /// No description provided for @contactsSelectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick someone from the list to see their profile'**
  String get contactsSelectSubtitle;

  /// No description provided for @contactsMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get contactsMessage;

  /// No description provided for @contactsCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get contactsCall;

  /// No description provided for @chatLoadingMessages.
  ///
  /// In en, this message translates to:
  /// **'Loading messages…'**
  String get chatLoadingMessages;

  /// No description provided for @chatStatusOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get chatStatusOnline;

  /// No description provided for @chatStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chatStatusOffline;

  /// No description provided for @chatGroupIntro.
  ///
  /// In en, this message translates to:
  /// **'Introduce yourself to the community!'**
  String get chatGroupIntro;

  /// No description provided for @chatEmpty.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get chatEmpty;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed: {error}'**
  String chatSendFailed(String error);

  /// No description provided for @chatMessagePlaceholderChannel.
  ///
  /// In en, this message translates to:
  /// **'Message #{name}'**
  String chatMessagePlaceholderChannel(String name);

  /// No description provided for @chatMessagePlaceholderUser.
  ///
  /// In en, this message translates to:
  /// **'Message {name}'**
  String chatMessagePlaceholderUser(String name);

  /// No description provided for @chatPinned.
  ///
  /// In en, this message translates to:
  /// **'pinned'**
  String get chatPinned;

  /// No description provided for @chatUnsupported.
  ///
  /// In en, this message translates to:
  /// **'[unsupported message]'**
  String get chatUnsupported;

  /// No description provided for @chatMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get chatMarkdown;

  /// No description provided for @chatAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get chatAttach;

  /// No description provided for @chatUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User {uid}'**
  String chatUserFallback(int uid);

  /// No description provided for @chatGroupFallback.
  ///
  /// In en, this message translates to:
  /// **'Group {gid}'**
  String chatGroupFallback(int gid);

  /// No description provided for @previewFile.
  ///
  /// In en, this message translates to:
  /// **'[File]'**
  String get previewFile;

  /// No description provided for @previewVoice.
  ///
  /// In en, this message translates to:
  /// **'[Voice]'**
  String get previewVoice;

  /// No description provided for @previewArchive.
  ///
  /// In en, this message translates to:
  /// **'[Archive]'**
  String get previewArchive;

  /// No description provided for @previewImage.
  ///
  /// In en, this message translates to:
  /// **'[Image]'**
  String get previewImage;

  /// No description provided for @previewReaction.
  ///
  /// In en, this message translates to:
  /// **'[Reaction]'**
  String get previewReaction;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String errorPrefix(String message);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppL10nEn();
    case 'zh': return AppL10nZh();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
