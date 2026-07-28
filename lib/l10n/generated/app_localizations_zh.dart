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
  String get navSaved => '收藏';

  @override
  String get comingSoon => '敬请期待';

  @override
  String get actionBack => '返回';

  @override
  String get actionClose => '关闭';

  @override
  String get memberRoleOwner => '群主';

  @override
  String get tooltipDownload => '下载';

  @override
  String get tooltipZoomIn => '放大';

  @override
  String get tooltipZoomOut => '缩小';

  @override
  String get tooltipFullscreen => '全屏';

  @override
  String get tooltipExitFullscreen => '退出全屏';

  @override
  String get tooltipShowPassword => '显示密码';

  @override
  String get tooltipHidePassword => '隐藏密码';

  @override
  String get reactionDeletedUser => '已注销用户';

  @override
  String reactionTooltipMany(String names, int count, String emoji) {
    return '$names 和其他 $count 人回应了 $emoji';
  }

  @override
  String reactionTooltipFew(String names, String emoji) {
    return '$names 回应了 $emoji';
  }

  @override
  String get expiredImageTitle => '图片不存在';

  @override
  String get expiredImageBody => '图片已过期或被删除';

  @override
  String get expiredVideoTitle => '视频不存在';

  @override
  String get expiredVideoBody => '视频已过期或被删除';

  @override
  String get expiredAudioTitle => '音频不存在';

  @override
  String get expiredAudioBody => '音频已过期或被删除';

  @override
  String get expiredFileTitle => '文件不存在';

  @override
  String get expiredFileBody => '文件已过期或被删除';

  @override
  String get featureUnavailable => '该功能暂未开放';

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
  String get chatVoiceMessage => '语音消息';

  @override
  String get chatVideoMessage => '视频消息';

  @override
  String get chatVoiceRecording => '正在录制语音消息';

  @override
  String get chatVoiceRecordingCancel => '取消';

  @override
  String get chatVoiceRecordingSend => '发送';

  @override
  String get chatRecordingPermissionDenied => '权限被拒绝，请在系统设置中开启麦克风/摄像头权限';

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
  String get errorRequestFailed => '请求失败';

  @override
  String get authKickedFromOtherDevice => '已退出登录：你的账号刚在另一台设备上登录。';

  @override
  String get authAccountDeleted => '你的账号已被删除。';

  @override
  String get authSessionEnded => '登录已失效，请重新登录。';

  @override
  String get chatListMarkRead => '标记为已读';

  @override
  String get chatListMute => '免打扰';

  @override
  String get chatListUnmute => '取消免打扰';

  @override
  String get chatListHide => '隐藏会话';

  @override
  String get chatListLeave => '退出频道';

  @override
  String get chatListMarkReadDone => '已标记为已读';

  @override
  String get chatListMuteDone => '已开启免打扰';

  @override
  String get chatListUnmuteDone => '已取消免打扰';

  @override
  String get chatListHideDone => '已隐藏';

  @override
  String get chatListLeaveDone => '已退出频道';

  @override
  String chatListLeaveFailed(String error) {
    return '退出失败：$error';
  }

  @override
  String chatListMuteFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get chatListMarkReadFailed => '标记已读失败';

  @override
  String get createChannelTitle => '新建频道';

  @override
  String get createChannelNameLabel => '频道名称';

  @override
  String get channelPublicLabel => '公开频道';

  @override
  String get createChannelPublicAdminOnly => '只有管理员可以创建公开频道';

  @override
  String get createChannelSubmit => '创建';

  @override
  String get createChannelNameRequired => '请输入频道名称';

  @override
  String get createChannelFailed => '创建频道失败';

  @override
  String get channelSettingsTitle => '频道设置';

  @override
  String get channelUpdated => '频道已更新';

  @override
  String get avatarUpdated => '头像已更新';

  @override
  String get channelVisibilityChanged => '可见性已更改';

  @override
  String get inviteLinkCopied => '链接已复制';

  @override
  String get channelOverview => '概览';

  @override
  String get channelNameLabel => '名称';

  @override
  String get channelDescriptionLabel => '描述';

  @override
  String get channelSaveChanges => '保存更改';

  @override
  String get channelAddMember => '添加成员';

  @override
  String get channelInviteLinkSection => '邀请链接';

  @override
  String get channelGenerateInviteLink => '生成邀请链接';

  @override
  String get channelMuteLabel => '静音频道';

  @override
  String get channelLeaveConfirmBody => '确定要退出该频道吗？';

  @override
  String get channelDeleteTitle => '删除频道';

  @override
  String get channelDeleteConfirmBody => '此操作将为所有成员永久删除该频道，且无法撤销。';

  @override
  String get actionLeave => '退出';

  @override
  String get accountEditNameTitle => '编辑姓名';

  @override
  String get accountNameLabel => '姓名';

  @override
  String get accountNameUpdated => '姓名已更新';

  @override
  String get accountChangePasswordTitle => '修改密码';

  @override
  String get accountCurrentPasswordLabel => '当前密码';

  @override
  String get accountNewPasswordLabel => '新密码';

  @override
  String get accountPasswordChanged => '密码已修改';

  @override
  String get chatActionCopy => '复制';

  @override
  String get chatActionForward => '转发';

  @override
  String get chatActionSelect => '选择';

  @override
  String get chatCopiedToClipboard => '已复制到剪贴板';

  @override
  String get chatForwardedMessagePreview => '[转发的消息]';

  @override
  String get chatAutoDeleteTitle => '阅后即焚';

  @override
  String chatExpiresTooltip(String duration) {
    return '发送后 $duration 消失';
  }

  @override
  String get chatAutoDeleteOff => '关闭';

  @override
  String get chatAutoDelete5Min => '5 分钟';

  @override
  String get chatAutoDelete10Min => '10 分钟';

  @override
  String get chatAutoDelete1Hour => '1 小时';

  @override
  String get chatAutoDelete1Day => '1 天';

  @override
  String get chatAutoDelete1Week => '1 周';

  @override
  String get chatAutoDeleteSaved => '已保存';

  @override
  String get chatAutoDeleteSaveFailed => '保存失败';

  @override
  String get forwardSheetTitle => '转发给...';

  @override
  String get forwardMessageSent => '消息已转发';

  @override
  String forwardFailed(String error) {
    return '转发失败：$error';
  }

  @override
  String get forwardNoConversations => '暂无会话';

  @override
  String forwardSelectedCount(int count) {
    return '已选择 $count 个';
  }

  @override
  String get archiveForwardedLabel => '转发的消息';

  @override
  String get archiveLoadFailed => '加载转发消息失败';

  @override
  String get archiveTapToView => '点击查看详情';

  @override
  String archiveViewAll(int count) {
    return '查看全部 $count 条消息';
  }
}
