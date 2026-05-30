// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppL10nZh extends AppL10n {
  AppL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'VoceChat';

  @override
  String get actionCancel => '取消';

  @override
  String get actionOpen => '打开';

  @override
  String get actionChange => '更改';

  @override
  String get actionContact => '联系';

  @override
  String get actionEdit => '编辑';

  @override
  String get actionSend => '发送';

  @override
  String get actionSearch => '搜索';

  @override
  String get actionMore => '更多';

  @override
  String get actionRetry => '重试';

  @override
  String get chatToolPin => '置顶';

  @override
  String get chatActionReact => '添加表情';

  @override
  String get chatActionReply => '回复';

  @override
  String get chatActionEdit => '编辑';

  @override
  String get chatActionDelete => '删除';

  @override
  String get chatEditMarker => '（已编辑）';

  @override
  String chatReplyingTo(String name) {
    return '正在回复 $name';
  }

  @override
  String get chatDeleteConfirmTitle => '删除消息？';

  @override
  String get chatDeleteConfirmBody => '此操作无法撤销。';

  @override
  String get chatEditCancel => '取消';

  @override
  String get chatEditSave => '保存';

  @override
  String get chatFileDetailsTitle => '文件详情';

  @override
  String get chatFileNameLabel => '文件名';

  @override
  String chatEditFailed(String error) {
    return '编辑失败：$error';
  }

  @override
  String chatDeleteFailed(String error) {
    return '删除失败：$error';
  }

  @override
  String chatReplyFailed(String error) {
    return '回复失败：$error';
  }

  @override
  String get chatReplyDeleted => '被回复的消息已删除！';

  @override
  String get chatReplyVoiceMessage => '[语音消息]';

  @override
  String get chatToolSaved => '收藏';

  @override
  String get chatToolMembers => '成员';

  @override
  String get chatToolEmpty => '暂无内容';

  @override
  String get chatToolPinEmpty => '暂无置顶消息';

  @override
  String get chatToolSavedEmpty => '暂无收藏';

  @override
  String get chatToolMembersEmpty => '暂无成员';

  @override
  String get chatToolUnpin => '取消置顶';

  @override
  String get chatToolRemoveFav => '移除';

  @override
  String get chatToolPinFail => '置顶失败';

  @override
  String get chatToolUnpinFail => '取消置顶失败';

  @override
  String get chatToolSaveFail => '收藏失败';

  @override
  String get chatToolRemoveFavFail => '移除失败';

  @override
  String get chatToolSavedAdded => '已收藏';

  @override
  String get chatToolPinAdded => '已置顶';

  @override
  String get chatToolUnpinned => '已取消置顶';

  @override
  String get chatSearchHint => '搜索消息';

  @override
  String get chatSearchEmpty => '未找到匹配消息';

  @override
  String get navChats => '聊天';

  @override
  String get navContacts => '联系人';

  @override
  String get navSettings => '设置';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsGroupGeneral => '通用';

  @override
  String get settingsGroupAbout => '关于';

  @override
  String get settingsMyAccount => '我的账户';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsStorage => '存储与数据';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsLogout => '退出登录';

  @override
  String get settingsLogoutConfirmTitle => '退出登录？';

  @override
  String get settingsLogoutConfirmContent => '再次访问该服务器需要重新登录。';

  @override
  String get accountEmail => '邮箱';

  @override
  String get accountUsername => '用户名';

  @override
  String get accountPassword => '密码';

  @override
  String get accountPasswordMasked => '*********';

  @override
  String get notificationsPush => '推送通知';

  @override
  String get notificationsPushSubtitle => '接收新消息和提及的通知。';

  @override
  String get notificationsSound => '提示音';

  @override
  String get notificationsSoundSubtitle => '新消息到达时播放提示音。';

  @override
  String get notificationsMentionsOnly => '仅提及';

  @override
  String get notificationsMentionsOnlySubtitle => '仅对 @我 的消息进行通知。';

  @override
  String get appearanceTheme => '主题';

  @override
  String get appearanceLight => '浅色';

  @override
  String get appearanceSystem => '跟随系统';

  @override
  String get appearanceDark => '深色';

  @override
  String get appearanceLanguage => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '简体中文';

  @override
  String get storageUsage => '存储用量';

  @override
  String get storageAutoDownload => '自动下载媒体';

  @override
  String get storageWifiOnly => '仅 Wi-Fi';

  @override
  String get storageClearCache => '清除缓存';

  @override
  String get storageClearCacheConfirmTitle => '清除缓存？';

  @override
  String get storageClearCacheConfirmBody => '将删除本地缓存的消息和图片，需要时会重新下载。';

  @override
  String get storageClearCacheConfirm => '清除';

  @override
  String get storageCacheCleared => '缓存已清除';

  @override
  String get aboutAppVersion => '应用版本';

  @override
  String get aboutWebsite => '官网';

  @override
  String get aboutReportBug => '反馈问题';

  @override
  String get aboutReportBugSubtitle => '帮助我们改进 VoceChat。';

  @override
  String get loginWelcomeBack => '欢迎回来';

  @override
  String get loginEmail => '邮箱';

  @override
  String get loginEmailRequired => '请输入邮箱';

  @override
  String get loginEmailInvalid => '请输入有效的邮箱地址';

  @override
  String get loginPassword => '密码';

  @override
  String get loginPasswordRequired => '请输入密码';

  @override
  String get loginPasswordTooShort => '密码至少需要 6 个字符';

  @override
  String get loginForgotPassword => '忘记密码？';

  @override
  String get loginSignIn => '登录';

  @override
  String get loginMagicLink => '使用魔法链接';

  @override
  String get loginPasskey => '使用通行密钥登录';

  @override
  String get loginSwitchServer => '切换服务器';

  @override
  String get loginNoAccount => '还没有账户？ ';

  @override
  String get loginSignUp => '注册';

  @override
  String get registerTitle => '创建账户';

  @override
  String get registerHeader => '加入对话';

  @override
  String get registerSubtitle => '填写你的信息以开始使用。';

  @override
  String get registerName => '姓名';

  @override
  String get registerNameRequired => '请输入姓名';

  @override
  String get registerNameTooShort => '姓名至少需要 2 个字符';

  @override
  String get registerEmailRequired => '请输入邮箱';

  @override
  String get registerEmailInvalid => '请输入有效的邮箱';

  @override
  String get registerPasswordRequired => '请输入密码';

  @override
  String get registerPasswordTooShort => '密码至少需要 6 个字符';

  @override
  String get registerConfirmPassword => '确认密码';

  @override
  String get registerConfirmRequired => '请确认你的密码';

  @override
  String get registerConfirmMismatch => '两次输入的密码不一致';

  @override
  String get registerCreate => '创建账户';

  @override
  String get registerMagicLink => '改为发送邀请链接';

  @override
  String get registerEmailFirst => '请先输入你的邮箱';

  @override
  String get registerInvitationSent => '邀请链接已发送';

  @override
  String get registerHaveAccount => '已有账户？ ';

  @override
  String get serverPickerTitle => '选择服务器';

  @override
  String get serverPickerEmptyTitle => '连接到 VoceChat 服务器';

  @override
  String get serverPickerEmptySubtitle => '添加一台服务器，开始和你的团队聊天。';

  @override
  String get serverPickerAddFirst => '添加第一台服务器';

  @override
  String get serverPickerAdd => '添加服务器';

  @override
  String get serverPickerContinue => '下一步';

  @override
  String get serverAddTitle => '添加服务器';

  @override
  String get serverUrl => '服务器地址';

  @override
  String get serverUrlHint => 'https://chat.example.com';

  @override
  String get serverUrlRequired => '请输入服务器地址';

  @override
  String get serverUrlMustHttps => '地址必须以 https:// 开头';

  @override
  String get serverUrlHttpNotAllowed => '仅允许 https://（远程服务器不允许使用 http）';

  @override
  String get serverAlias => '别名（可选）';

  @override
  String get serverAliasHint => '我的工作服务器';

  @override
  String get serverTesting => '测试中…';

  @override
  String get serverTestConnection => '测试连接';

  @override
  String get serverTestSuccess => '连接成功';

  @override
  String get serverTestFailed => '无法连接到服务器';

  @override
  String get serverSave => '保存并继续';

  @override
  String get chatListSearch => '搜索...';

  @override
  String get chatListNewChat => '新建聊天';

  @override
  String get chatListLoading => '正在加载会话…';

  @override
  String get chatListUpdating => '更新中…';

  @override
  String get chatListEmpty => '暂无会话';

  @override
  String chatListNoResults(String query) {
    return '没有找到与“$query”相关的结果';
  }

  @override
  String get chatListSelectTitle => '选择一个会话';

  @override
  String get chatListSelectSubtitle => '从左侧面板选择一个会话开始聊天';

  @override
  String get chatListPin => '置顶聊天';

  @override
  String get chatListUnpin => '取消置顶';

  @override
  String chatListPinFailed(String error) {
    return '置顶失败：$error';
  }

  @override
  String chatListUnpinFailed(String error) {
    return '取消置顶失败：$error';
  }

  @override
  String get timeJustNow => '刚刚';

  @override
  String timeMinutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count 天前';
  }

  @override
  String get contactsSearch => '搜索...';

  @override
  String get contactsAdd => '添加联系人';

  @override
  String get contactsLoading => '正在加载联系人…';

  @override
  String get contactsEmpty => '没有联系人';

  @override
  String contactsSectionBot(int count) {
    return '机器人 - $count';
  }

  @override
  String contactsSectionContact(int count) {
    return '联系人 - $count';
  }

  @override
  String get contactsSelectTitle => '选择一位联系人';

  @override
  String get contactsSelectSubtitle => '从列表中选择以查看其个人资料';

  @override
  String get contactsMessage => '消息';

  @override
  String get contactsCall => '通话';

  @override
  String get chatLoadingMessages => '正在加载消息…';

  @override
  String get chatStatusOnline => '在线';

  @override
  String get chatStatusOffline => '离线';

  @override
  String get chatGroupIntro => '向社区成员介绍一下你自己吧！';

  @override
  String get chatEmpty => '暂无消息';

  @override
  String chatSendFailed(String error) {
    return '发送失败：$error';
  }

  @override
  String chatMessagePlaceholderChannel(String name) {
    return '发送到 #$name';
  }

  @override
  String chatMessagePlaceholderUser(String name) {
    return '发送给 $name';
  }

  @override
  String get chatPinned => '已置顶';

  @override
  String get chatUnsupported => '[不支持的消息]';

  @override
  String get chatMarkdown => 'Markdown';

  @override
  String get chatAttach => '附件';

  @override
  String chatDropOverlayTitle(String name) {
    return '发送到 $name';
  }

  @override
  String get chatDropOverlayHint => '拖放文件到此处以发送';

  @override
  String get chatEmoji => '表情';

  @override
  String chatUserFallback(int uid) {
    return '用户 $uid';
  }

  @override
  String chatGroupFallback(int gid) {
    return '群组 $gid';
  }

  @override
  String get previewFile => '[文件]';

  @override
  String get previewVoice => '[语音]';

  @override
  String get previewArchive => '[压缩包]';

  @override
  String get previewImage => '[图片]';

  @override
  String get previewReaction => '[表情回应]';

  @override
  String errorPrefix(String message) {
    return '错误：$message';
  }

  @override
  String get authKickedFromOtherDevice => '已退出登录：你的账号刚在另一台设备上登录。';

  @override
  String get authAccountDeleted => '你的账号已被删除。';

  @override
  String get authSessionEnded => '登录已失效，请重新登录。';
}
