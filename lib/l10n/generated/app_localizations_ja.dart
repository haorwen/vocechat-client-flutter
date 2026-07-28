import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppL10nJa extends AppL10n {
  AppL10nJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'VoceChat';

  @override
  String get actionCancel => 'キャンセル';

  @override
  String get actionOpen => '開く';

  @override
  String get actionChange => '変更';

  @override
  String get actionContact => '連絡先';

  @override
  String get actionEdit => '編集';

  @override
  String get actionSend => '送信';

  @override
  String get actionSearch => '検索';

  @override
  String get actionMore => 'その他';

  @override
  String get actionRetry => '再試行';

  @override
  String get chatToolPin => 'ピン留め';

  @override
  String get chatActionReact => 'リアクションを追加';

  @override
  String get chatActionReply => '返信';

  @override
  String get chatActionEdit => '編集';

  @override
  String get chatActionDelete => '削除';

  @override
  String get chatEditMarker => '（編集済み）';

  @override
  String chatReplyingTo(String name) {
    return '$name に返信中';
  }

  @override
  String get chatDeleteConfirmTitle => 'メッセージを削除しますか？';

  @override
  String get chatDeleteConfirmBody => 'この操作は取り消せません。';

  @override
  String get chatEditCancel => 'キャンセル';

  @override
  String get chatEditSave => '保存';

  @override
  String get chatFileDetailsTitle => 'ファイル詳細';

  @override
  String get chatFileNameLabel => '名前';

  @override
  String chatEditFailed(String error) {
    return '編集に失敗しました：$error';
  }

  @override
  String chatDeleteFailed(String error) {
    return '削除に失敗しました：$error';
  }

  @override
  String chatReplyFailed(String error) {
    return '返信に失敗しました：$error';
  }

  @override
  String get chatReplyDeleted => 'このメッセージは削除されました。';

  @override
  String get chatReplyVoiceMessage => '[音声メッセージ]';

  @override
  String get chatToolSaved => 'お気に入り';

  @override
  String get chatToolMembers => 'メンバー';

  @override
  String get chatToolEmpty => 'まだ内容がありません。';

  @override
  String get chatToolPinEmpty => 'ピン留めされたメッセージはありません。';

  @override
  String get chatToolSavedEmpty => 'お気に入りのメッセージはありません。';

  @override
  String get chatToolMembersEmpty => 'メンバーがいません。';

  @override
  String get chatToolUnpin => 'ピン留め解除';

  @override
  String get chatToolRemoveFav => '削除';

  @override
  String get chatToolPinFail => 'ピン留めに失敗しました';

  @override
  String get chatToolUnpinFail => 'ピン留め解除に失敗しました';

  @override
  String get chatToolSaveFail => 'お気に入り登録に失敗しました';

  @override
  String get chatToolRemoveFavFail => '削除に失敗しました';

  @override
  String get chatToolSavedAdded => 'お気に入りに追加しました';

  @override
  String get chatToolPinAdded => 'ピン留めしました';

  @override
  String get chatToolUnpinned => 'ピン留めを解除しました';

  @override
  String get chatSearchHint => 'メッセージを検索';

  @override
  String get chatSearchEmpty => '一致するメッセージがありません。';

  @override
  String get navChats => 'チャット';

  @override
  String get navContacts => '連絡先';

  @override
  String get navSettings => '設定';

  @override
  String get navSaved => 'お気に入り';

  @override
  String get comingSoon => '近日公開';

  @override
  String get actionBack => '戻る';

  @override
  String get actionClose => '閉じる';

  @override
  String get memberRoleOwner => 'オーナー';

  @override
  String get tooltipDownload => 'ダウンロード';

  @override
  String get tooltipZoomIn => '拡大';

  @override
  String get tooltipZoomOut => '縮小';

  @override
  String get tooltipFullscreen => '全画面表示';

  @override
  String get tooltipExitFullscreen => '全画面表示を終了';

  @override
  String get tooltipShowPassword => 'パスワードを表示';

  @override
  String get tooltipHidePassword => 'パスワードを隠す';

  @override
  String get reactionDeletedUser => '削除されたユーザー';

  @override
  String reactionTooltipMany(String names, int count, String emoji) {
    return '$names と他 $count 人が $emoji でリアクションしました';
  }

  @override
  String reactionTooltipFew(String names, String emoji) {
    return '$names が $emoji でリアクションしました';
  }

  @override
  String get expiredImageTitle => '画像が見つかりません';

  @override
  String get expiredImageBody => '画像の有効期限が切れたか削除されました';

  @override
  String get expiredVideoTitle => '動画が見つかりません';

  @override
  String get expiredVideoBody => '動画の有効期限が切れたか削除されました';

  @override
  String get expiredAudioTitle => '音声が見つかりません';

  @override
  String get expiredAudioBody => '音声の有効期限が切れたか削除されました';

  @override
  String get expiredFileTitle => 'ファイルが見つかりません';

  @override
  String get expiredFileBody => 'ファイルの有効期限が切れたか削除されました';

  @override
  String get featureUnavailable => 'この機能はまだご利用いただけません';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsGroupGeneral => '一般';

  @override
  String get settingsGroupAbout => 'このアプリについて';

  @override
  String get settingsMyAccount => 'マイアカウント';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsStorage => 'ストレージとデータ';

  @override
  String get settingsAbout => 'このアプリについて';

  @override
  String get settingsLogout => 'ログアウト';

  @override
  String get settingsLogoutConfirmTitle => 'ログアウトしますか？';

  @override
  String get settingsLogoutConfirmContent => 'このサーバーに再度アクセスするには、もう一度ログインする必要があります。';

  @override
  String get accountEmail => 'メールアドレス';

  @override
  String get accountUsername => 'ユーザー名';

  @override
  String get accountPassword => 'パスワード';

  @override
  String get accountPasswordMasked => '*********';

  @override
  String get notificationsPush => 'プッシュ通知';

  @override
  String get notificationsPushSubtitle => '新しいメッセージやメンションの通知を受け取ります。';

  @override
  String get notificationsSound => '通知音';

  @override
  String get notificationsSoundSubtitle => 'メッセージ受信時に着信音を鳴らします。';

  @override
  String get notificationsMentionsOnly => 'メンションのみ';

  @override
  String get notificationsMentionsOnlySubtitle => '@メンションのみ通知します。';

  @override
  String get appearanceTheme => 'テーマ';

  @override
  String get appearanceLight => 'ライト';

  @override
  String get appearanceSystem => 'システムに従う';

  @override
  String get appearanceDark => 'ダーク';

  @override
  String get appearanceLanguage => '言語';

  @override
  String get languageSystem => 'システムに従う';

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
  String get storageUsage => 'ストレージ使用量';

  @override
  String get storageAutoDownload => 'メディアを自動ダウンロード';

  @override
  String get storageWifiOnly => 'Wi-Fi のみ';

  @override
  String get storageClearCache => 'キャッシュを削除';

  @override
  String get storageClearCacheConfirmTitle => 'キャッシュを削除しますか？';

  @override
  String get storageClearCacheConfirmBody => 'ローカルに保存されたメッセージと画像のキャッシュが削除されます。必要に応じて再ダウンロードされます。';

  @override
  String get storageClearCacheConfirm => '削除';

  @override
  String get storageCacheCleared => 'キャッシュを削除しました';

  @override
  String get aboutAppVersion => 'アプリのバージョン';

  @override
  String get aboutWebsite => 'ウェブサイト';

  @override
  String get aboutReportBug => '不具合を報告';

  @override
  String get aboutReportBugSubtitle => 'VoceChat の改善にご協力ください。';

  @override
  String get loginWelcomeBack => 'ようこそ';

  @override
  String get loginEmail => 'メールアドレス';

  @override
  String get loginEmailRequired => 'メールアドレスを入力してください';

  @override
  String get loginEmailInvalid => '有効なメールアドレスを入力してください';

  @override
  String get loginPassword => 'パスワード';

  @override
  String get loginPasswordRequired => 'パスワードを入力してください';

  @override
  String get loginPasswordTooShort => 'パスワードは6文字以上で入力してください';

  @override
  String get loginForgotPassword => 'パスワードをお忘れですか？';

  @override
  String get loginSignIn => 'ログイン';

  @override
  String get loginMagicLink => 'マジックリンクを使用';

  @override
  String get loginPasskey => 'パスキーでログイン';

  @override
  String get loginSwitchServer => 'サーバーを切り替える';

  @override
  String get loginNoAccount => 'アカウントをお持ちでない方は ';

  @override
  String get loginSignUp => '新規登録';

  @override
  String get loginErrorInvalidCredentials => 'メールアドレスまたはパスワードが正しくありません';

  @override
  String get loginErrorAccountFrozen => 'このアカウントは凍結されています。管理者にお問い合わせください。';

  @override
  String get loginErrorNotInvited => '関連するアカウントが見つかりません。管理者に招待リンクを依頼してください。';

  @override
  String get loginErrorMethodNotSupported => 'このログイン方法はサーバーでサポートされていません。';

  @override
  String get loginErrorCannotReachServer => 'サーバーに接続できません。ネットワークまたはサーバーの URL を確認してください。';

  @override
  String get registerTitle => 'アカウントを作成';

  @override
  String get registerHeader => '会話に参加する';

  @override
  String get registerSubtitle => '情報を入力して始めましょう。';

  @override
  String get registerName => '氏名';

  @override
  String get registerNameRequired => '名前を入力してください';

  @override
  String get registerNameTooShort => '名前は2文字以上で入力してください';

  @override
  String get registerEmailRequired => 'メールアドレスを入力してください';

  @override
  String get registerEmailInvalid => '有効なメールアドレスを入力してください';

  @override
  String get registerPasswordRequired => 'パスワードを入力してください';

  @override
  String get registerPasswordTooShort => '6文字以上で入力してください';

  @override
  String get registerConfirmPassword => 'パスワードの確認';

  @override
  String get registerConfirmRequired => 'パスワードを再入力してください';

  @override
  String get registerConfirmMismatch => 'パスワードが一致しません';

  @override
  String get registerCreate => 'アカウントを作成';

  @override
  String get registerMagicLink => '招待リンクを送信する';

  @override
  String get registerEmailFirst => '先にメールアドレスを入力してください';

  @override
  String get registerInvitationSent => '招待リンクを送信しました';

  @override
  String get registerHaveAccount => 'すでにアカウントをお持ちですか？ ';

  @override
  String get serverPickerTitle => 'サーバーを選択';

  @override
  String get serverPickerEmptyTitle => 'VoceChat サーバーに接続';

  @override
  String get serverPickerEmptySubtitle => 'サーバーを追加して、チームとのチャットを始めましょう。';

  @override
  String get serverPickerAddFirst => '最初のサーバーを追加';

  @override
  String get serverPickerAdd => 'サーバーを追加';

  @override
  String get serverPickerContinue => '続ける';

  @override
  String get serverAddTitle => 'サーバーを追加';

  @override
  String get serverUrl => 'サーバー URL';

  @override
  String get serverUrlHint => 'https://chat.example.com';

  @override
  String get serverUrlRequired => 'URL を入力してください';

  @override
  String get serverUrlMustHttps => 'https:// で始まる必要があります';

  @override
  String get serverUrlHttpNotAllowed => 'https:// のみ使用できます（リモートサーバーでは http は使用できません）';

  @override
  String get serverAlias => 'エイリアス（任意）';

  @override
  String get serverAliasHint => '会社のサーバー';

  @override
  String get serverTesting => 'テスト中…';

  @override
  String get serverTestConnection => '接続をテスト';

  @override
  String get serverTestSuccess => '接続に成功しました';

  @override
  String get serverTestFailed => 'サーバーに接続できませんでした';

  @override
  String get serverSave => '保存して続ける';

  @override
  String get chatListSearch => '検索...';

  @override
  String get chatListNewChat => '新規チャット';

  @override
  String get chatListLoading => 'チャットを読み込み中…';

  @override
  String get chatListUpdating => '更新中…';

  @override
  String get chatListEmpty => 'まだ会話がありません';

  @override
  String chatListNoResults(String query) {
    return '「$query」に一致する結果はありません';
  }

  @override
  String get chatListSelectTitle => '会話を選択してください';

  @override
  String get chatListSelectSubtitle => '左のパネルからチャットを選んでメッセージを始めましょう';

  @override
  String get chatListPin => '上部にピン留め';

  @override
  String get chatListUnpin => 'ピン留め解除';

  @override
  String chatListPinFailed(String error) {
    return 'ピン留めに失敗しました：$error';
  }

  @override
  String chatListUnpinFailed(String error) {
    return 'ピン留め解除に失敗しました：$error';
  }

  @override
  String get timeJustNow => 'たった今';

  @override
  String timeMinutesAgo(int count) {
    return '$count 分前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count 時間前';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count 日前';
  }

  @override
  String get contactsSearch => '検索...';

  @override
  String get contactsAdd => '連絡先を追加';

  @override
  String get contactsLoading => '連絡先を読み込み中…';

  @override
  String get contactsEmpty => '連絡先が見つかりません';

  @override
  String contactsSectionBot(int count) {
    return 'ボット - $count';
  }

  @override
  String contactsSectionContact(int count) {
    return '連絡先 - $count';
  }

  @override
  String get contactsSelectTitle => '連絡先を選択してください';

  @override
  String get contactsSelectSubtitle => 'リストから選択してプロフィールを確認できます';

  @override
  String get contactsMessage => 'メッセージ';

  @override
  String get contactsCall => '通話';

  @override
  String get chatLoadingMessages => 'メッセージを読み込み中…';

  @override
  String get chatStatusOnline => 'オンライン';

  @override
  String get chatStatusOffline => 'オフライン';

  @override
  String get chatGroupIntro => 'コミュニティに自己紹介しましょう！';

  @override
  String get chatEmpty => 'まだメッセージがありません';

  @override
  String chatSendFailed(String error) {
    return '送信に失敗しました：$error';
  }

  @override
  String chatMessagePlaceholderChannel(String name) {
    return '#$name にメッセージを送信';
  }

  @override
  String chatMessagePlaceholderUser(String name) {
    return '$name にメッセージを送信';
  }

  @override
  String get chatPinned => 'ピン留め済み';

  @override
  String get chatUnsupported => '[サポートされていないメッセージ]';

  @override
  String get chatMarkdown => 'Markdown';

  @override
  String get chatAttach => '添付';

  @override
  String get chatVoiceMessage => '音声メッセージ';

  @override
  String get chatVideoMessage => '動画メッセージ';

  @override
  String get chatVoiceRecording => '音声メッセージを録音中';

  @override
  String get chatVoiceRecordingCancel => 'キャンセル';

  @override
  String get chatVoiceRecordingSend => '送信';

  @override
  String get chatRecordingPermissionDenied => '権限が拒否されました — システム設定でマイク／カメラのアクセスを許可してください';

  @override
  String chatDropOverlayTitle(String name) {
    return '$name に送信';
  }

  @override
  String get chatDropOverlayHint => 'ここにファイルをドロップして送信';

  @override
  String get chatEmoji => '絵文字';

  @override
  String chatUserFallback(int uid) {
    return 'ユーザー $uid';
  }

  @override
  String chatGroupFallback(int gid) {
    return 'グループ $gid';
  }

  @override
  String get previewFile => '[ファイル]';

  @override
  String get previewVoice => '[音声]';

  @override
  String get previewArchive => '[アーカイブ]';

  @override
  String get previewImage => '[画像]';

  @override
  String get previewReaction => '[リアクション]';

  @override
  String errorPrefix(String message) {
    return 'エラー：$message';
  }

  @override
  String get errorRequestFailed => 'リクエストに失敗しました';

  @override
  String get authKickedFromOtherDevice => 'ログアウトしました：あなたのアカウントが別のデバイスでログインしました。';

  @override
  String get authAccountDeleted => 'あなたのアカウントは削除されました。';

  @override
  String get authSessionEnded => 'セッションが終了しました。再度ログインしてください。';

  @override
  String get chatListMarkRead => '既読にする';

  @override
  String get chatListMute => 'ミュート';

  @override
  String get chatListUnmute => 'ミュート解除';

  @override
  String get chatListHide => '非表示';

  @override
  String get chatListLeave => 'チャンネルを退出';

  @override
  String get chatListMarkReadDone => '既読にしました';

  @override
  String get chatListMuteDone => 'ミュートしました';

  @override
  String get chatListUnmuteDone => 'ミュートを解除しました';

  @override
  String get chatListHideDone => '非表示にしました';

  @override
  String get chatListLeaveDone => 'チャンネルを退出しました';

  @override
  String chatListLeaveFailed(String error) {
    return '退出に失敗しました：$error';
  }

  @override
  String chatListMuteFailed(String error) {
    return 'ミュートに失敗しました：$error';
  }

  @override
  String get chatListMarkReadFailed => '既読処理に失敗しました';

  @override
  String get createChannelTitle => '新規チャンネル';

  @override
  String get createChannelNameLabel => 'チャンネル名';

  @override
  String get channelPublicLabel => '公開チャンネル';

  @override
  String get createChannelPublicAdminOnly => '公開チャンネルを作成できるのは管理者のみです';

  @override
  String get createChannelSubmit => '作成';

  @override
  String get createChannelNameRequired => 'チャンネル名を入力してください';

  @override
  String get createChannelFailed => 'チャンネルの作成に失敗しました';

  @override
  String get channelSettingsTitle => 'チャンネル設定';

  @override
  String get channelUpdated => 'チャンネルを更新しました';

  @override
  String get avatarUpdated => 'アバターを更新しました';

  @override
  String get channelVisibilityChanged => '公開範囲を変更しました';

  @override
  String get inviteLinkCopied => 'リンクをコピーしました';

  @override
  String get channelOverview => '概要';

  @override
  String get channelNameLabel => '名前';

  @override
  String get channelDescriptionLabel => '説明';

  @override
  String get channelSaveChanges => '変更を保存';

  @override
  String get channelAddMember => 'メンバーを追加';

  @override
  String get channelInviteLinkSection => '招待リンク';

  @override
  String get channelGenerateInviteLink => '招待リンクを生成';

  @override
  String get channelMuteLabel => 'チャンネルをミュート';

  @override
  String get channelLeaveConfirmBody => '本当にこのチャンネルを退出しますか？';

  @override
  String get channelDeleteTitle => 'チャンネルを削除';

  @override
  String get channelDeleteConfirmBody => 'この操作を行うと、全メンバーに対してチャンネルが永久に削除されます。この操作は取り消せません。';

  @override
  String get actionLeave => '退出';

  @override
  String get accountEditNameTitle => '名前を編集';

  @override
  String get accountNameLabel => '名前';

  @override
  String get accountNameUpdated => '名前を更新しました';

  @override
  String get accountChangePasswordTitle => 'パスワードを変更';

  @override
  String get accountCurrentPasswordLabel => '現在のパスワード';

  @override
  String get accountNewPasswordLabel => '新しいパスワード';

  @override
  String get accountPasswordChanged => 'パスワードを変更しました';

  @override
  String get chatActionCopy => 'コピー';

  @override
  String get chatActionForward => '転送';

  @override
  String get chatActionSelect => '選択';

  @override
  String get chatCopiedToClipboard => 'クリップボードにコピーしました';

  @override
  String get chatForwardedMessagePreview => '[転送されたメッセージ]';

  @override
  String get chatAutoDeleteTitle => 'メッセージの自動削除';

  @override
  String chatExpiresTooltip(String duration) {
    return '送信後 $duration で消えます';
  }

  @override
  String get chatAutoDeleteOff => 'オフ';

  @override
  String get chatAutoDelete5Min => '5分';

  @override
  String get chatAutoDelete10Min => '10分';

  @override
  String get chatAutoDelete1Hour => '1時間';

  @override
  String get chatAutoDelete1Day => '1日';

  @override
  String get chatAutoDelete1Week => '1週間';

  @override
  String get chatAutoDeleteSaved => '保存しました';

  @override
  String get chatAutoDeleteSaveFailed => '保存に失敗しました';

  @override
  String get forwardSheetTitle => '転送先...';

  @override
  String get forwardMessageSent => 'メッセージを転送しました';

  @override
  String forwardFailed(String error) {
    return '転送に失敗しました：$error';
  }

  @override
  String get forwardNoConversations => '会話がありません';

  @override
  String forwardSelectedCount(int count) {
    return '$count 件選択中';
  }

  @override
  String get archiveForwardedLabel => '転送されたメッセージ';

  @override
  String get archiveLoadFailed => '転送メッセージの読み込みに失敗しました';

  @override
  String get archiveTapToView => 'タップして詳細を表示';

  @override
  String archiveViewAll(int count) {
    return '$count 件のメッセージをすべて表示';
  }
}
