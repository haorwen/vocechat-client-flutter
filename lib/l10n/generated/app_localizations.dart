import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
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
  AppL10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('ru'),
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

  /// No description provided for @chatActionReact.
  ///
  /// In en, this message translates to:
  /// **'Add reaction'**
  String get chatActionReact;

  /// No description provided for @chatActionReply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get chatActionReply;

  /// No description provided for @chatActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get chatActionEdit;

  /// No description provided for @chatActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatActionDelete;

  /// No description provided for @chatEditMarker.
  ///
  /// In en, this message translates to:
  /// **'(edited)'**
  String get chatEditMarker;

  /// No description provided for @chatReplyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String chatReplyingTo(String name);

  /// No description provided for @chatDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete message?'**
  String get chatDeleteConfirmTitle;

  /// No description provided for @chatDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get chatDeleteConfirmBody;

  /// No description provided for @chatEditCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatEditCancel;

  /// No description provided for @chatEditSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get chatEditSave;

  /// No description provided for @chatFileDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'File details'**
  String get chatFileDetailsTitle;

  /// No description provided for @chatFileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get chatFileNameLabel;

  /// No description provided for @chatEditFailed.
  ///
  /// In en, this message translates to:
  /// **'Edit failed: {error}'**
  String chatEditFailed(String error);

  /// No description provided for @chatDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String chatDeleteFailed(String error);

  /// No description provided for @chatReplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Reply failed: {error}'**
  String chatReplyFailed(String error);

  /// No description provided for @chatReplyDeleted.
  ///
  /// In en, this message translates to:
  /// **'This message has been deleted.'**
  String get chatReplyDeleted;

  /// No description provided for @chatReplyVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'[Voice Message]'**
  String get chatReplyVoiceMessage;

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

  /// No description provided for @navChats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get navChats;

  /// No description provided for @navContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get navContacts;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get navSaved;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @memberRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get memberRoleOwner;

  /// No description provided for @tooltipDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get tooltipDownload;

  /// No description provided for @tooltipZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get tooltipZoomIn;

  /// No description provided for @tooltipZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get tooltipZoomOut;

  /// No description provided for @tooltipFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get tooltipFullscreen;

  /// No description provided for @tooltipExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit fullscreen'**
  String get tooltipExitFullscreen;

  /// No description provided for @tooltipShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get tooltipShowPassword;

  /// No description provided for @tooltipHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get tooltipHidePassword;

  /// No description provided for @reactionDeletedUser.
  ///
  /// In en, this message translates to:
  /// **'Deleted User'**
  String get reactionDeletedUser;

  /// No description provided for @reactionTooltipMany.
  ///
  /// In en, this message translates to:
  /// **'{names} and {count} others reacted with {emoji}'**
  String reactionTooltipMany(String names, int count, String emoji);

  /// No description provided for @reactionTooltipFew.
  ///
  /// In en, this message translates to:
  /// **'{names} reacted with {emoji}'**
  String reactionTooltipFew(String names, String emoji);

  /// No description provided for @expiredImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Image not found'**
  String get expiredImageTitle;

  /// No description provided for @expiredImageBody.
  ///
  /// In en, this message translates to:
  /// **'Image expired or deleted'**
  String get expiredImageBody;

  /// No description provided for @expiredVideoTitle.
  ///
  /// In en, this message translates to:
  /// **'Video not found'**
  String get expiredVideoTitle;

  /// No description provided for @expiredVideoBody.
  ///
  /// In en, this message translates to:
  /// **'Video expired or deleted'**
  String get expiredVideoBody;

  /// No description provided for @expiredAudioTitle.
  ///
  /// In en, this message translates to:
  /// **'Audio not found'**
  String get expiredAudioTitle;

  /// No description provided for @expiredAudioBody.
  ///
  /// In en, this message translates to:
  /// **'Audio expired or deleted'**
  String get expiredAudioBody;

  /// No description provided for @expiredFileTitle.
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get expiredFileTitle;

  /// No description provided for @expiredFileBody.
  ///
  /// In en, this message translates to:
  /// **'File expired or deleted'**
  String get expiredFileBody;

  /// No description provided for @featureUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This feature is not available yet'**
  String get featureUnavailable;

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

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Español'**
  String get languageSpanish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get languagePortuguese;

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

  /// No description provided for @storageClearCacheConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cache?'**
  String get storageClearCacheConfirmTitle;

  /// No description provided for @storageClearCacheConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes locally cached messages and images. They will be re-downloaded as needed.'**
  String get storageClearCacheConfirmBody;

  /// No description provided for @storageClearCacheConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get storageClearCacheConfirm;

  /// No description provided for @storageCacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get storageCacheCleared;

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

  /// No description provided for @loginRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember password'**
  String get loginRememberMe;

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

  /// No description provided for @loginErrorInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get loginErrorInvalidCredentials;

  /// No description provided for @loginErrorAccountFrozen.
  ///
  /// In en, this message translates to:
  /// **'This account has been frozen. Contact your admin.'**
  String get loginErrorAccountFrozen;

  /// No description provided for @loginErrorNotInvited.
  ///
  /// In en, this message translates to:
  /// **'No associated account found. Ask an admin for an invitation link.'**
  String get loginErrorNotInvited;

  /// No description provided for @loginErrorMethodNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This login method isn\'t supported by the server.'**
  String get loginErrorMethodNotSupported;

  /// No description provided for @loginErrorCannotReachServer.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your network or the server URL.'**
  String get loginErrorCannotReachServer;

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

  /// No description provided for @serverPickerContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get serverPickerContinue;

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

  /// No description provided for @chatListPin.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get chatListPin;

  /// No description provided for @chatListUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get chatListUnpin;

  /// No description provided for @chatListPinFailed.
  ///
  /// In en, this message translates to:
  /// **'Pin failed: {error}'**
  String chatListPinFailed(String error);

  /// No description provided for @chatListUnpinFailed.
  ///
  /// In en, this message translates to:
  /// **'Unpin failed: {error}'**
  String chatListUnpinFailed(String error);

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

  /// No description provided for @chatVoiceMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice Message'**
  String get chatVoiceMessage;

  /// No description provided for @chatVideoMessage.
  ///
  /// In en, this message translates to:
  /// **'Video Message'**
  String get chatVideoMessage;

  /// No description provided for @chatVoiceRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording voice message'**
  String get chatVoiceRecording;

  /// No description provided for @chatVoiceRecordingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatVoiceRecordingCancel;

  /// No description provided for @chatVoiceRecordingSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatVoiceRecordingSend;

  /// No description provided for @chatRecordingPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Permission denied — enable microphone/camera access in system settings'**
  String get chatRecordingPermissionDenied;

  /// No description provided for @chatDropOverlayTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to {name}'**
  String chatDropOverlayTitle(String name);

  /// No description provided for @chatDropOverlayHint.
  ///
  /// In en, this message translates to:
  /// **'Drop files here to send them'**
  String get chatDropOverlayHint;

  /// No description provided for @chatEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get chatEmoji;

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

  /// No description provided for @errorRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Request failed'**
  String get errorRequestFailed;

  /// No description provided for @authKickedFromOtherDevice.
  ///
  /// In en, this message translates to:
  /// **'Signed out: your account just signed in on another device.'**
  String get authKickedFromOtherDevice;

  /// No description provided for @authAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get authAccountDeleted;

  /// No description provided for @authSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'Your session ended. Please sign in again.'**
  String get authSessionEnded;

  /// No description provided for @chatListMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get chatListMarkRead;

  /// No description provided for @chatListMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get chatListMute;

  /// No description provided for @chatListUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get chatListUnmute;

  /// No description provided for @chatListHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get chatListHide;

  /// No description provided for @chatListLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave channel'**
  String get chatListLeave;

  /// No description provided for @chatListMarkReadDone.
  ///
  /// In en, this message translates to:
  /// **'Marked as read'**
  String get chatListMarkReadDone;

  /// No description provided for @chatListMuteDone.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get chatListMuteDone;

  /// No description provided for @chatListUnmuteDone.
  ///
  /// In en, this message translates to:
  /// **'Unmuted'**
  String get chatListUnmuteDone;

  /// No description provided for @chatListHideDone.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get chatListHideDone;

  /// No description provided for @chatListLeaveDone.
  ///
  /// In en, this message translates to:
  /// **'Left channel'**
  String get chatListLeaveDone;

  /// No description provided for @chatListLeaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Leave failed: {error}'**
  String chatListLeaveFailed(String error);

  /// No description provided for @chatListMuteFailed.
  ///
  /// In en, this message translates to:
  /// **'Mute failed: {error}'**
  String chatListMuteFailed(String error);

  /// No description provided for @chatListMarkReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Mark read failed'**
  String get chatListMarkReadFailed;

  /// No description provided for @createChannelTitle.
  ///
  /// In en, this message translates to:
  /// **'New Channel'**
  String get createChannelTitle;

  /// No description provided for @createChannelNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Channel name'**
  String get createChannelNameLabel;

  /// No description provided for @channelPublicLabel.
  ///
  /// In en, this message translates to:
  /// **'Public channel'**
  String get channelPublicLabel;

  /// No description provided for @createChannelPublicAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only admins can create public channels'**
  String get createChannelPublicAdminOnly;

  /// No description provided for @createChannelSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createChannelSubmit;

  /// No description provided for @createChannelNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please input a channel name'**
  String get createChannelNameRequired;

  /// No description provided for @createChannelFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create channel'**
  String get createChannelFailed;

  /// No description provided for @channelSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel settings'**
  String get channelSettingsTitle;

  /// No description provided for @channelUpdated.
  ///
  /// In en, this message translates to:
  /// **'Channel updated'**
  String get channelUpdated;

  /// No description provided for @avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get avatarUpdated;

  /// No description provided for @channelVisibilityChanged.
  ///
  /// In en, this message translates to:
  /// **'Visibility changed'**
  String get channelVisibilityChanged;

  /// No description provided for @inviteLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get inviteLinkCopied;

  /// No description provided for @channelOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get channelOverview;

  /// No description provided for @channelNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get channelNameLabel;

  /// No description provided for @channelDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get channelDescriptionLabel;

  /// No description provided for @channelSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get channelSaveChanges;

  /// No description provided for @channelAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get channelAddMember;

  /// No description provided for @channelInviteLinkSection.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get channelInviteLinkSection;

  /// No description provided for @channelGenerateInviteLink.
  ///
  /// In en, this message translates to:
  /// **'Generate invite link'**
  String get channelGenerateInviteLink;

  /// No description provided for @channelMuteLabel.
  ///
  /// In en, this message translates to:
  /// **'Mute channel'**
  String get channelMuteLabel;

  /// No description provided for @channelLeaveConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this channel?'**
  String get channelLeaveConfirmBody;

  /// No description provided for @channelDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete channel'**
  String get channelDeleteTitle;

  /// No description provided for @channelDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete the channel for all members. This cannot be undone.'**
  String get channelDeleteConfirmBody;

  /// No description provided for @actionLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get actionLeave;

  /// No description provided for @accountEditNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get accountEditNameTitle;

  /// No description provided for @accountNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountNameLabel;

  /// No description provided for @accountNameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get accountNameUpdated;

  /// No description provided for @accountChangePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountChangePasswordTitle;

  /// No description provided for @accountCurrentPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get accountCurrentPasswordLabel;

  /// No description provided for @accountNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get accountNewPasswordLabel;

  /// No description provided for @accountPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get accountPasswordChanged;

  /// No description provided for @chatActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get chatActionCopy;

  /// No description provided for @chatActionForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get chatActionForward;

  /// No description provided for @chatActionSelect.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get chatActionSelect;

  /// No description provided for @chatCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get chatCopiedToClipboard;

  /// No description provided for @chatForwardedMessagePreview.
  ///
  /// In en, this message translates to:
  /// **'[Forwarded message]'**
  String get chatForwardedMessagePreview;

  /// No description provided for @chatAutoDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-delete messages'**
  String get chatAutoDeleteTitle;

  /// No description provided for @chatExpiresTooltip.
  ///
  /// In en, this message translates to:
  /// **'Disappears {duration} after being sent'**
  String chatExpiresTooltip(String duration);

  /// No description provided for @chatAutoDeleteOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get chatAutoDeleteOff;

  /// No description provided for @chatAutoDelete5Min.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get chatAutoDelete5Min;

  /// No description provided for @chatAutoDelete10Min.
  ///
  /// In en, this message translates to:
  /// **'10 minutes'**
  String get chatAutoDelete10Min;

  /// No description provided for @chatAutoDelete1Hour.
  ///
  /// In en, this message translates to:
  /// **'1 hour'**
  String get chatAutoDelete1Hour;

  /// No description provided for @chatAutoDelete1Day.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get chatAutoDelete1Day;

  /// No description provided for @chatAutoDelete1Week.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get chatAutoDelete1Week;

  /// No description provided for @chatAutoDeleteSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get chatAutoDeleteSaved;

  /// No description provided for @chatAutoDeleteSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get chatAutoDeleteSaveFailed;

  /// No description provided for @forwardSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Forward to...'**
  String get forwardSheetTitle;

  /// No description provided for @forwardMessageSent.
  ///
  /// In en, this message translates to:
  /// **'Message forwarded'**
  String get forwardMessageSent;

  /// No description provided for @forwardFailed.
  ///
  /// In en, this message translates to:
  /// **'Forward failed: {error}'**
  String forwardFailed(String error);

  /// No description provided for @forwardNoConversations.
  ///
  /// In en, this message translates to:
  /// **'No conversations'**
  String get forwardNoConversations;

  /// No description provided for @forwardSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String forwardSelectedCount(int count);

  /// No description provided for @archiveForwardedLabel.
  ///
  /// In en, this message translates to:
  /// **'Forwarded message(s)'**
  String get archiveForwardedLabel;

  /// No description provided for @archiveLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load forwarded message'**
  String get archiveLoadFailed;

  /// No description provided for @archiveTapToView.
  ///
  /// In en, this message translates to:
  /// **'Tap to view details'**
  String get archiveTapToView;

  /// No description provided for @archiveViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all {count} messages'**
  String archiveViewAll(int count);
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'en',
        'es',
        'fr',
        'ja',
        'ko',
        'pt',
        'ru',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'es':
      return AppL10nEs();
    case 'fr':
      return AppL10nFr();
    case 'ja':
      return AppL10nJa();
    case 'ko':
      return AppL10nKo();
    case 'pt':
      return AppL10nPt();
    case 'ru':
      return AppL10nRu();
    case 'zh':
      return AppL10nZh();
  }

  throw FlutterError(
      'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
