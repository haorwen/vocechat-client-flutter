// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppL10nKo extends AppL10n {
  AppL10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'VoceChat';

  @override
  String get actionCancel => '취소';

  @override
  String get actionOpen => '열기';

  @override
  String get actionChange => '변경';

  @override
  String get actionContact => '연락하기';

  @override
  String get actionEdit => '수정';

  @override
  String get actionSend => '보내기';

  @override
  String get actionSearch => '검색';

  @override
  String get actionMore => '더보기';

  @override
  String get actionRetry => '재시도';

  @override
  String get chatToolPin => '고정됨';

  @override
  String get chatActionReact => '반응 추가';

  @override
  String get chatActionReply => '답장';

  @override
  String get chatActionEdit => '수정';

  @override
  String get chatActionDelete => '삭제';

  @override
  String get chatEditMarker => '(수정됨)';

  @override
  String chatReplyingTo(String name) {
    return '$name님에게 답장';
  }

  @override
  String get chatDeleteConfirmTitle => '메시지를 삭제할까요?';

  @override
  String get chatDeleteConfirmBody => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get chatEditCancel => '취소';

  @override
  String get chatEditSave => '저장';

  @override
  String get chatFileDetailsTitle => '파일 정보';

  @override
  String get chatFileNameLabel => '이름';

  @override
  String chatEditFailed(String error) {
    return '수정 실패: $error';
  }

  @override
  String chatDeleteFailed(String error) {
    return '삭제 실패: $error';
  }

  @override
  String chatReplyFailed(String error) {
    return '답장 실패: $error';
  }

  @override
  String get chatReplyDeleted => '삭제된 메시지입니다.';

  @override
  String get chatReplyVoiceMessage => '[음성 메시지]';

  @override
  String get chatToolSaved => '저장됨';

  @override
  String get chatToolMembers => '멤버';

  @override
  String get chatToolEmpty => '아직 내용이 없습니다.';

  @override
  String get chatToolPinEmpty => '고정된 메시지가 없습니다.';

  @override
  String get chatToolSavedEmpty => '저장된 메시지가 없습니다.';

  @override
  String get chatToolMembersEmpty => '멤버가 없습니다.';

  @override
  String get chatToolUnpin => '고정 해제';

  @override
  String get chatToolRemoveFav => '제거';

  @override
  String get chatToolPinFail => '고정 실패';

  @override
  String get chatToolUnpinFail => '고정 해제 실패';

  @override
  String get chatToolSaveFail => '저장 실패';

  @override
  String get chatToolRemoveFavFail => '제거 실패';

  @override
  String get chatToolSavedAdded => '저장됨';

  @override
  String get chatToolPinAdded => '고정됨';

  @override
  String get chatToolUnpinned => '고정 해제됨';

  @override
  String get chatSearchHint => '메시지 검색';

  @override
  String get chatSearchEmpty => '일치하는 메시지가 없습니다.';

  @override
  String get navChats => '채팅';

  @override
  String get navContacts => '연락처';

  @override
  String get navSettings => '설정';

  @override
  String get navSaved => '저장됨';

  @override
  String get comingSoon => '곧 제공될 예정입니다';

  @override
  String get actionBack => '뒤로';

  @override
  String get actionClose => '닫기';

  @override
  String get memberRoleOwner => '소유자';

  @override
  String get tooltipDownload => '다운로드';

  @override
  String get tooltipZoomIn => '확대';

  @override
  String get tooltipZoomOut => '축소';

  @override
  String get tooltipFullscreen => '전체 화면';

  @override
  String get tooltipExitFullscreen => '전체 화면 종료';

  @override
  String get tooltipShowPassword => '비밀번호 표시';

  @override
  String get tooltipHidePassword => '비밀번호 숨기기';

  @override
  String get reactionDeletedUser => '삭제된 사용자';

  @override
  String reactionTooltipMany(String names, int count, String emoji) {
    return '$names 외 $count명이 $emoji 반응을 남겼습니다';
  }

  @override
  String reactionTooltipFew(String names, String emoji) {
    return '$names님이 $emoji 반응을 남겼습니다';
  }

  @override
  String get expiredImageTitle => '이미지를 찾을 수 없습니다';

  @override
  String get expiredImageBody => '이미지가 만료되었거나 삭제되었습니다';

  @override
  String get expiredVideoTitle => '동영상을 찾을 수 없습니다';

  @override
  String get expiredVideoBody => '동영상이 만료되었거나 삭제되었습니다';

  @override
  String get expiredAudioTitle => '오디오를 찾을 수 없습니다';

  @override
  String get expiredAudioBody => '오디오가 만료되었거나 삭제되었습니다';

  @override
  String get expiredFileTitle => '파일을 찾을 수 없습니다';

  @override
  String get expiredFileBody => '파일이 만료되었거나 삭제되었습니다';

  @override
  String get featureUnavailable => '아직 사용할 수 없는 기능입니다';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsGroupGeneral => '일반';

  @override
  String get settingsGroupAbout => '정보';

  @override
  String get settingsMyAccount => '내 계정';

  @override
  String get settingsNotifications => '알림';

  @override
  String get settingsAppearance => '화면 설정';

  @override
  String get settingsStorage => '저장공간 및 데이터';

  @override
  String get settingsAbout => '정보';

  @override
  String get settingsLogout => '로그아웃';

  @override
  String get settingsLogoutConfirmTitle => '로그아웃할까요?';

  @override
  String get settingsLogoutConfirmContent => '이 서버에 다시 접속하려면 로그인이 필요합니다.';

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
  String get accountEmail => '이메일';

  @override
  String get accountUsername => '사용자 이름';

  @override
  String get accountPassword => '비밀번호';

  @override
  String get accountPasswordMasked => '*********';

  @override
  String get notificationsPush => '푸시 알림';

  @override
  String get notificationsPushSubtitle => '새 메시지와 멘션에 대한 알림을 받습니다.';

  @override
  String get notificationsSound => '알림 소리';

  @override
  String get notificationsSoundSubtitle => '새 메시지가 도착하면 알림음을 재생합니다.';

  @override
  String get notificationsMentionsOnly => '멘션만 알림';

  @override
  String get notificationsMentionsOnlySubtitle => '@멘션에 대해서만 알림을 받습니다.';

  @override
  String get appearanceTheme => '테마';

  @override
  String get appearanceLight => '라이트';

  @override
  String get appearanceSystem => '시스템 기본값';

  @override
  String get appearanceDark => '다크';

  @override
  String get appearanceLanguage => '언어';

  @override
  String get languageSystem => '시스템 기본값';

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
  String get storageUsage => '저장공간 사용량';

  @override
  String get storageAutoDownload => '미디어 자동 다운로드';

  @override
  String get storageWifiOnly => 'Wi-Fi에서만';

  @override
  String get storageClearCache => '캐시 지우기';

  @override
  String get storageClearCacheConfirmTitle => '캐시를 지울까요?';

  @override
  String get storageClearCacheConfirmBody =>
      '로컬에 캐시된 메시지와 이미지가 삭제됩니다. 필요할 때 다시 다운로드됩니다.';

  @override
  String get storageClearCacheConfirm => '지우기';

  @override
  String get storageCacheCleared => '캐시가 지워졌습니다';

  @override
  String get aboutAppVersion => '앱 버전';

  @override
  String get aboutWebsite => '웹사이트';

  @override
  String get aboutReportBug => '버그 신고';

  @override
  String get aboutReportBugSubtitle => 'VoceChat을 개선하는 데 도움을 주세요.';

  @override
  String get loginWelcomeBack => '다시 만나서 반가워요';

  @override
  String get loginEmail => '이메일';

  @override
  String get loginEmailRequired => '이메일을 입력해 주세요';

  @override
  String get loginEmailInvalid => '올바른 이메일 주소를 입력해 주세요';

  @override
  String get loginPassword => '비밀번호';

  @override
  String get loginPasswordRequired => '비밀번호를 입력해 주세요';

  @override
  String get loginPasswordTooShort => '비밀번호는 6자 이상이어야 합니다';

  @override
  String get loginForgotPassword => '비밀번호를 잊으셨나요?';

  @override
  String get loginRememberMe => '비밀번호 저장';

  @override
  String get loginSignIn => '로그인';

  @override
  String get loginMagicLink => '매직 링크 사용';

  @override
  String get loginPasskey => '패스키로 로그인';

  @override
  String get loginSwitchServer => '서버 전환';

  @override
  String get loginNoAccount => '계정이 없으신가요? ';

  @override
  String get loginSignUp => '가입하기';

  @override
  String get loginErrorInvalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다';

  @override
  String get loginErrorAccountFrozen => '이 계정은 정지되었습니다. 관리자에게 문의해 주세요.';

  @override
  String get loginErrorNotInvited => '연결된 계정을 찾을 수 없습니다. 관리자에게 초대 링크를 요청해 주세요.';

  @override
  String get loginErrorMethodNotSupported => '이 서버에서는 이 로그인 방식을 지원하지 않습니다.';

  @override
  String get loginErrorCannotReachServer =>
      '서버에 연결할 수 없습니다. 네트워크나 서버 주소를 확인해 주세요.';

  @override
  String get registerTitle => '계정 만들기';

  @override
  String get registerHeader => '대화에 참여하세요';

  @override
  String get registerSubtitle => '시작하려면 정보를 입력해 주세요.';

  @override
  String get registerName => '이름';

  @override
  String get registerNameRequired => '이름을 입력해 주세요';

  @override
  String get registerNameTooShort => '이름은 2자 이상이어야 합니다';

  @override
  String get registerEmailRequired => '이메일을 입력해 주세요';

  @override
  String get registerEmailInvalid => '올바른 이메일을 입력해 주세요';

  @override
  String get registerPasswordRequired => '비밀번호를 입력해 주세요';

  @override
  String get registerPasswordTooShort => '6자 이상 입력해야 합니다';

  @override
  String get registerConfirmPassword => '비밀번호 확인';

  @override
  String get registerConfirmRequired => '비밀번호를 다시 입력해 주세요';

  @override
  String get registerConfirmMismatch => '비밀번호가 일치하지 않습니다';

  @override
  String get registerCreate => '계정 만들기';

  @override
  String get registerMagicLink => '대신 초대 링크 보내기';

  @override
  String get registerEmailFirst => '먼저 이메일을 입력해 주세요';

  @override
  String get registerInvitationSent => '초대 링크가 전송되었습니다';

  @override
  String get registerHaveAccount => '이미 계정이 있으신가요? ';

  @override
  String get registerInviteRequiresEmailConfirmation =>
      'This server requires email confirmation for invited signups, which isn\'t supported yet. Please ask your admin for help.';

  @override
  String get serverPickerTitle => '서버 선택';

  @override
  String get serverPickerEmptyTitle => 'VoceChat 서버에 연결하기';

  @override
  String get serverPickerEmptySubtitle => '서버를 추가하고 팀과의 대화를 시작하세요.';

  @override
  String get serverPickerAddFirst => '첫 서버 추가하기';

  @override
  String get serverPickerAdd => '서버 추가';

  @override
  String get serverPickerContinue => '계속';

  @override
  String get serverPickerUseInviteLink => 'Use invitation link';

  @override
  String get serverAddTitle => '서버 추가';

  @override
  String get serverUrl => '서버 URL';

  @override
  String get serverUrlHint => 'https://chat.example.com';

  @override
  String get serverUrlRequired => 'URL을 입력해 주세요';

  @override
  String get serverUrlMustHttps => 'https://로 시작해야 합니다';

  @override
  String get serverUrlHttpNotAllowed =>
      'https://만 허용됩니다 (원격 서버에는 http를 사용할 수 없습니다)';

  @override
  String get serverTesting => '테스트 중…';

  @override
  String get serverTestConnection => '연결 테스트';

  @override
  String get serverTestSuccess => '연결 성공';

  @override
  String get serverTestFailed => '서버에 연결할 수 없습니다';

  @override
  String get serverSave => '저장하고 계속하기';

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
  String get chatListSearch => '검색...';

  @override
  String get chatListNewChat => '새 채팅';

  @override
  String get chatListLoading => '채팅 목록을 불러오는 중…';

  @override
  String get chatListUpdating => '업데이트 중…';

  @override
  String get chatListEmpty => '아직 대화가 없습니다';

  @override
  String chatListNoResults(String query) {
    return '\"$query\"에 대한 결과가 없습니다';
  }

  @override
  String get chatListSelectTitle => '대화를 선택하세요';

  @override
  String get chatListSelectSubtitle => '왼쪽 목록에서 채팅을 선택해 대화를 시작하세요';

  @override
  String get chatListPin => '상단에 고정';

  @override
  String get chatListUnpin => '고정 해제';

  @override
  String chatListPinFailed(String error) {
    return '고정 실패: $error';
  }

  @override
  String chatListUnpinFailed(String error) {
    return '고정 해제 실패: $error';
  }

  @override
  String get timeJustNow => '방금 전';

  @override
  String timeMinutesAgo(int count) {
    return '$count분 전';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count시간 전';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count일 전';
  }

  @override
  String get contactsSearch => '검색...';

  @override
  String get contactsAdd => '연락처 추가';

  @override
  String get contactsLoading => '연락처를 불러오는 중…';

  @override
  String get contactsEmpty => '연락처가 없습니다';

  @override
  String contactsSectionBot(int count) {
    return '봇 - $count';
  }

  @override
  String contactsSectionContact(int count) {
    return '연락처 - $count';
  }

  @override
  String get contactsSelectTitle => '연락처를 선택하세요';

  @override
  String get contactsSelectSubtitle => '목록에서 선택하면 프로필을 볼 수 있습니다';

  @override
  String get contactsMessage => '메시지';

  @override
  String get contactsCall => '통화';

  @override
  String get chatLoadingMessages => '메시지를 불러오는 중…';

  @override
  String get chatStatusOnline => '온라인';

  @override
  String get chatStatusOffline => '오프라인';

  @override
  String get chatGroupIntro => '커뮤니티에 자신을 소개해 보세요!';

  @override
  String get chatEmpty => '아직 메시지가 없습니다';

  @override
  String chatSendFailed(String error) {
    return '전송 실패: $error';
  }

  @override
  String chatMessagePlaceholderChannel(String name) {
    return '#$name에 메시지 보내기';
  }

  @override
  String chatMessagePlaceholderUser(String name) {
    return '$name님에게 메시지 보내기';
  }

  @override
  String get chatPinned => '고정됨';

  @override
  String get chatUnsupported => '[지원하지 않는 메시지]';

  @override
  String get chatMarkdown => '마크다운';

  @override
  String get chatAttach => '첨부';

  @override
  String get chatVoiceMessage => '음성 메시지';

  @override
  String get chatVideoMessage => '동영상 메시지';

  @override
  String get chatVoiceRecording => '음성 메시지 녹음 중';

  @override
  String get chatVoiceRecordingCancel => '취소';

  @override
  String get chatVoiceRecordingSend => '보내기';

  @override
  String get chatRecordingPermissionDenied =>
      '권한이 거부되었습니다 — 시스템 설정에서 마이크/카메라 접근을 허용해 주세요';

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
    return '$name에게 보내기';
  }

  @override
  String get chatDropOverlayHint => '파일을 여기에 놓아 전송하세요';

  @override
  String get chatEmoji => '이모지';

  @override
  String chatUserFallback(int uid) {
    return '사용자 $uid';
  }

  @override
  String chatGroupFallback(int gid) {
    return '그룹 $gid';
  }

  @override
  String get previewFile => '[파일]';

  @override
  String get previewVoice => '[음성]';

  @override
  String get previewArchive => '[압축 파일]';

  @override
  String get previewImage => '[이미지]';

  @override
  String get previewReaction => '[반응]';

  @override
  String errorPrefix(String message) {
    return '오류: $message';
  }

  @override
  String get errorRequestFailed => '요청이 실패했습니다';

  @override
  String get authKickedFromOtherDevice => '로그아웃되었습니다: 다른 기기에서 계정에 로그인했습니다.';

  @override
  String get authAccountDeleted => '계정이 삭제되었습니다.';

  @override
  String get authSessionEnded => '세션이 종료되었습니다. 다시 로그인해 주세요.';

  @override
  String get chatListMarkRead => '읽음으로 표시';

  @override
  String get chatListMute => '알림 끄기';

  @override
  String get chatListUnmute => '알림 켜기';

  @override
  String get chatListHide => '숨기기';

  @override
  String get chatListLeave => '채널 나가기';

  @override
  String get chatListMarkReadDone => '읽음으로 표시됨';

  @override
  String get chatListMuteDone => '알림이 꺼졌습니다';

  @override
  String get chatListUnmuteDone => '알림이 켜졌습니다';

  @override
  String get chatListHideDone => '숨겨짐';

  @override
  String get chatListLeaveDone => '채널에서 나갔습니다';

  @override
  String chatListLeaveFailed(String error) {
    return '나가기 실패: $error';
  }

  @override
  String chatListMuteFailed(String error) {
    return '실패: $error';
  }

  @override
  String get chatListMarkReadFailed => '읽음 표시 실패';

  @override
  String get createChannelTitle => '새 채널';

  @override
  String get createChannelNameLabel => '채널 이름';

  @override
  String get channelPublicLabel => '공개 채널';

  @override
  String get createChannelPublicAdminOnly => '관리자만 공개 채널을 만들 수 있습니다';

  @override
  String get createChannelSubmit => '만들기';

  @override
  String get createChannelNameRequired => '채널 이름을 입력해 주세요';

  @override
  String get createChannelFailed => '채널 생성에 실패했습니다';

  @override
  String get channelSettingsTitle => '채널 설정';

  @override
  String get channelUpdated => '채널이 업데이트되었습니다';

  @override
  String get avatarUpdated => '프로필 사진이 업데이트되었습니다';

  @override
  String get channelVisibilityChanged => '공개 범위가 변경되었습니다';

  @override
  String get inviteLinkCopied => '링크가 복사되었습니다';

  @override
  String get channelOverview => '개요';

  @override
  String get channelNameLabel => '이름';

  @override
  String get channelDescriptionLabel => '설명';

  @override
  String get channelSaveChanges => '변경 사항 저장';

  @override
  String get channelAddMember => '멤버 추가';

  @override
  String get channelInviteLinkSection => '초대 링크';

  @override
  String get channelGenerateInviteLink => '초대 링크 생성';

  @override
  String get channelMuteLabel => '채널 알림 끄기';

  @override
  String get channelLeaveConfirmBody => '이 채널을 나가시겠습니까?';

  @override
  String get channelDeleteTitle => '채널 삭제';

  @override
  String get channelDeleteConfirmBody =>
      '모든 멤버에게서 채널이 영구적으로 삭제됩니다. 이 작업은 되돌릴 수 없습니다.';

  @override
  String get actionLeave => '나가기';

  @override
  String get accountEditNameTitle => '이름 수정';

  @override
  String get accountNameLabel => '이름';

  @override
  String get accountNameUpdated => '이름이 업데이트되었습니다';

  @override
  String get accountChangePasswordTitle => '비밀번호 변경';

  @override
  String get accountCurrentPasswordLabel => '현재 비밀번호';

  @override
  String get accountNewPasswordLabel => '새 비밀번호';

  @override
  String get accountPasswordChanged => '비밀번호가 변경되었습니다';

  @override
  String get chatActionCopy => '복사';

  @override
  String get chatActionForward => '전달';

  @override
  String get chatActionSelect => '선택';

  @override
  String get chatCopiedToClipboard => '클립보드에 복사되었습니다';

  @override
  String get chatForwardedMessagePreview => '[전달된 메시지]';

  @override
  String get chatAutoDeleteTitle => '메시지 자동 삭제';

  @override
  String chatExpiresTooltip(String duration) {
    return '전송 후 $duration 뒤에 사라집니다';
  }

  @override
  String get chatAutoDeleteOff => '끄기';

  @override
  String get chatAutoDelete5Min => '5분';

  @override
  String get chatAutoDelete10Min => '10분';

  @override
  String get chatAutoDelete1Hour => '1시간';

  @override
  String get chatAutoDelete1Day => '1일';

  @override
  String get chatAutoDelete1Week => '1주';

  @override
  String get chatAutoDeleteSaved => '저장됨';

  @override
  String get chatAutoDeleteSaveFailed => '저장 실패';

  @override
  String get forwardSheetTitle => '전달할 대상 선택...';

  @override
  String get forwardMessageSent => '메시지가 전달되었습니다';

  @override
  String forwardFailed(String error) {
    return '전달 실패: $error';
  }

  @override
  String get forwardNoConversations => '대화가 없습니다';

  @override
  String forwardSelectedCount(int count) {
    return '$count개 선택됨';
  }

  @override
  String get archiveForwardedLabel => '전달된 메시지';

  @override
  String get archiveLoadFailed => '전달된 메시지를 불러오지 못했습니다';

  @override
  String get archiveTapToView => '탭하여 자세히 보기';

  @override
  String archiveViewAll(int count) {
    return '전체 $count개 메시지 보기';
  }
}
