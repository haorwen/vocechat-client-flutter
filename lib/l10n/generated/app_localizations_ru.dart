import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppL10nRu extends AppL10n {
  AppL10nRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'VoceChat';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionOpen => 'Открыть';

  @override
  String get actionChange => 'Изменить';

  @override
  String get actionContact => 'Контакт';

  @override
  String get actionEdit => 'Редактировать';

  @override
  String get actionSend => 'Отправить';

  @override
  String get actionSearch => 'Поиск';

  @override
  String get actionMore => 'Ещё';

  @override
  String get actionRetry => 'Повторить';

  @override
  String get chatToolPin => 'Закреплённые';

  @override
  String get chatActionReact => 'Добавить реакцию';

  @override
  String get chatActionReply => 'Ответить';

  @override
  String get chatActionEdit => 'Редактировать';

  @override
  String get chatActionDelete => 'Удалить';

  @override
  String get chatEditMarker => '(изменено)';

  @override
  String chatReplyingTo(String name) {
    return 'Ответ пользователю $name';
  }

  @override
  String get chatDeleteConfirmTitle => 'Удалить сообщение?';

  @override
  String get chatDeleteConfirmBody => 'Это действие невозможно отменить.';

  @override
  String get chatEditCancel => 'Отмена';

  @override
  String get chatEditSave => 'Сохранить';

  @override
  String get chatFileDetailsTitle => 'Информация о файле';

  @override
  String get chatFileNameLabel => 'Имя';

  @override
  String chatEditFailed(String error) {
    return 'Не удалось изменить: $error';
  }

  @override
  String chatDeleteFailed(String error) {
    return 'Не удалось удалить: $error';
  }

  @override
  String chatReplyFailed(String error) {
    return 'Не удалось ответить: $error';
  }

  @override
  String get chatReplyDeleted => 'Это сообщение было удалено.';

  @override
  String get chatReplyVoiceMessage => '[Голосовое сообщение]';

  @override
  String get chatToolSaved => 'Сохранённые';

  @override
  String get chatToolMembers => 'Участники';

  @override
  String get chatToolEmpty => 'Пока нет содержимого.';

  @override
  String get chatToolPinEmpty => 'Нет закреплённых сообщений.';

  @override
  String get chatToolSavedEmpty => 'Нет сохранённых сообщений.';

  @override
  String get chatToolMembersEmpty => 'Нет участников.';

  @override
  String get chatToolUnpin => 'Открепить';

  @override
  String get chatToolRemoveFav => 'Удалить';

  @override
  String get chatToolPinFail => 'Не удалось закрепить';

  @override
  String get chatToolUnpinFail => 'Не удалось открепить';

  @override
  String get chatToolSaveFail => 'Не удалось сохранить';

  @override
  String get chatToolRemoveFavFail => 'Не удалось удалить';

  @override
  String get chatToolSavedAdded => 'Сохранено';

  @override
  String get chatToolPinAdded => 'Закреплено';

  @override
  String get chatToolUnpinned => 'Откреплено';

  @override
  String get chatSearchHint => 'Поиск сообщений';

  @override
  String get chatSearchEmpty => 'Совпадений не найдено.';

  @override
  String get navChats => 'Чаты';

  @override
  String get navContacts => 'Контакты';

  @override
  String get navSettings => 'Настройки';

  @override
  String get navSaved => 'Сохранённые';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get actionBack => 'Назад';

  @override
  String get actionClose => 'Закрыть';

  @override
  String get memberRoleOwner => 'Владелец';

  @override
  String get tooltipDownload => 'Скачать';

  @override
  String get tooltipZoomIn => 'Увеличить';

  @override
  String get tooltipZoomOut => 'Уменьшить';

  @override
  String get tooltipFullscreen => 'Полный экран';

  @override
  String get tooltipExitFullscreen => 'Выйти из полного экрана';

  @override
  String get tooltipShowPassword => 'Показать пароль';

  @override
  String get tooltipHidePassword => 'Скрыть пароль';

  @override
  String get reactionDeletedUser => 'Удалённый пользователь';

  @override
  String reactionTooltipMany(String names, int count, String emoji) {
    return '$names и ещё $count человек отреагировали $emoji';
  }

  @override
  String reactionTooltipFew(String names, String emoji) {
    return '$names отреагировали $emoji';
  }

  @override
  String get expiredImageTitle => 'Изображение не найдено';

  @override
  String get expiredImageBody => 'Изображение истекло или было удалено';

  @override
  String get expiredVideoTitle => 'Видео не найдено';

  @override
  String get expiredVideoBody => 'Видео истекло или было удалено';

  @override
  String get expiredAudioTitle => 'Аудио не найдено';

  @override
  String get expiredAudioBody => 'Аудио истекло или было удалено';

  @override
  String get expiredFileTitle => 'Файл не найден';

  @override
  String get expiredFileBody => 'Файл истёк или был удалён';

  @override
  String get featureUnavailable => 'Эта функция пока недоступна';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsGroupGeneral => 'общие';

  @override
  String get settingsGroupAbout => 'о приложении';

  @override
  String get settingsMyAccount => 'Мой аккаунт';

  @override
  String get settingsNotifications => 'Уведомления';

  @override
  String get settingsAppearance => 'Внешний вид';

  @override
  String get settingsStorage => 'Хранилище и данные';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsLogout => 'Выйти';

  @override
  String get settingsLogoutConfirmTitle => 'Выйти из аккаунта?';

  @override
  String get settingsLogoutConfirmContent => 'Для доступа к этому серверу потребуется войти снова.';

  @override
  String get accountEmail => 'Электронная почта';

  @override
  String get accountUsername => 'Имя пользователя';

  @override
  String get accountPassword => 'Пароль';

  @override
  String get accountPasswordMasked => '*********';

  @override
  String get notificationsPush => 'Push-уведомления';

  @override
  String get notificationsPushSubtitle => 'Получать уведомления о новых сообщениях и упоминаниях.';

  @override
  String get notificationsSound => 'Звук уведомлений';

  @override
  String get notificationsSoundSubtitle => 'Воспроизводить звук при новых сообщениях.';

  @override
  String get notificationsMentionsOnly => 'Только упоминания';

  @override
  String get notificationsMentionsOnlySubtitle => 'Уведомлять только при упоминаниях (@).';

  @override
  String get appearanceTheme => 'ТЕМА';

  @override
  String get appearanceLight => 'Светлая';

  @override
  String get appearanceSystem => 'Как в системе';

  @override
  String get appearanceDark => 'Тёмная';

  @override
  String get appearanceLanguage => 'ЯЗЫК';

  @override
  String get languageSystem => 'Как в системе';

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
  String get storageUsage => 'Использование хранилища';

  @override
  String get storageAutoDownload => 'Автозагрузка медиафайлов';

  @override
  String get storageWifiOnly => 'Только через Wi-Fi';

  @override
  String get storageClearCache => 'Очистить кэш';

  @override
  String get storageClearCacheConfirmTitle => 'Очистить кэш?';

  @override
  String get storageClearCacheConfirmBody => 'Локально кэшированные сообщения и изображения будут удалены. При необходимости они будут загружены заново.';

  @override
  String get storageClearCacheConfirm => 'Очистить';

  @override
  String get storageCacheCleared => 'Кэш очищен';

  @override
  String get aboutAppVersion => 'Версия приложения';

  @override
  String get aboutWebsite => 'Веб-сайт';

  @override
  String get aboutReportBug => 'Сообщить об ошибке';

  @override
  String get aboutReportBugSubtitle => 'Помогите нам сделать VoceChat лучше.';

  @override
  String get loginWelcomeBack => 'С возвращением';

  @override
  String get loginEmail => 'Электронная почта';

  @override
  String get loginEmailRequired => 'Введите адрес электронной почты';

  @override
  String get loginEmailInvalid => 'Введите действительный адрес электронной почты';

  @override
  String get loginPassword => 'Пароль';

  @override
  String get loginPasswordRequired => 'Введите пароль';

  @override
  String get loginPasswordTooShort => 'Пароль должен содержать не менее 6 символов';

  @override
  String get loginForgotPassword => 'Забыли пароль?';

  @override
  String get loginRememberMe => 'Запомнить пароль';

  @override
  String get loginSignIn => 'Войти';

  @override
  String get loginMagicLink => 'Использовать magic-ссылку';

  @override
  String get loginPasskey => 'Войти с помощью passkey';

  @override
  String get loginSwitchServer => 'Сменить сервер';

  @override
  String get loginNoAccount => 'Нет аккаунта? ';

  @override
  String get loginSignUp => 'Зарегистрироваться';

  @override
  String get loginErrorInvalidCredentials => 'Неверный адрес электронной почты или пароль';

  @override
  String get loginErrorAccountFrozen => 'Этот аккаунт заморожен. Обратитесь к администратору.';

  @override
  String get loginErrorNotInvited => 'Связанный аккаунт не найден. Попросите администратора отправить ссылку-приглашение.';

  @override
  String get loginErrorMethodNotSupported => 'Этот способ входа не поддерживается сервером.';

  @override
  String get loginErrorCannotReachServer => 'Не удаётся подключиться к серверу. Проверьте сеть или адрес сервера.';

  @override
  String get registerTitle => 'Создать аккаунт';

  @override
  String get registerHeader => 'Присоединиться к общению';

  @override
  String get registerSubtitle => 'Заполните данные, чтобы начать.';

  @override
  String get registerName => 'Полное имя';

  @override
  String get registerNameRequired => 'Введите имя';

  @override
  String get registerNameTooShort => 'Имя должно содержать не менее 2 символов';

  @override
  String get registerEmailRequired => 'Введите адрес электронной почты';

  @override
  String get registerEmailInvalid => 'Введите действительный адрес электронной почты';

  @override
  String get registerPasswordRequired => 'Введите пароль';

  @override
  String get registerPasswordTooShort => 'Требуется не менее 6 символов';

  @override
  String get registerConfirmPassword => 'Подтвердите пароль';

  @override
  String get registerConfirmRequired => 'Пожалуйста, подтвердите пароль';

  @override
  String get registerConfirmMismatch => 'Пароли не совпадают';

  @override
  String get registerCreate => 'Создать аккаунт';

  @override
  String get registerMagicLink => 'Отправить ссылку-приглашение вместо этого';

  @override
  String get registerEmailFirst => 'Сначала введите адрес электронной почты';

  @override
  String get registerInvitationSent => 'Ссылка-приглашение отправлена';

  @override
  String get registerHaveAccount => 'Уже есть аккаунт? ';

  @override
  String get serverPickerTitle => 'Выбор сервера';

  @override
  String get serverPickerEmptyTitle => 'Подключение к серверу VoceChat';

  @override
  String get serverPickerEmptySubtitle => 'Добавьте сервер, чтобы начать общение с командой.';

  @override
  String get serverPickerAddFirst => 'Добавить первый сервер';

  @override
  String get serverPickerAdd => 'Добавить сервер';

  @override
  String get serverPickerContinue => 'Продолжить';

  @override
  String get serverAddTitle => 'Добавить сервер';

  @override
  String get serverUrl => 'Адрес сервера';

  @override
  String get serverUrlHint => 'https://chat.example.com';

  @override
  String get serverUrlRequired => 'Введите адрес';

  @override
  String get serverUrlMustHttps => 'Адрес должен начинаться с https://';

  @override
  String get serverUrlHttpNotAllowed => 'Разрешён только https:// (http не поддерживается для удалённых серверов)';

  @override
  String get serverTesting => 'Проверка…';

  @override
  String get serverTestConnection => 'Проверить подключение';

  @override
  String get serverTestSuccess => 'Подключение успешно';

  @override
  String get serverTestFailed => 'Не удалось подключиться к серверу';

  @override
  String get serverSave => 'Сохранить и продолжить';

  @override
  String get chatListSearch => 'Поиск...';

  @override
  String get chatListNewChat => 'Новый чат';

  @override
  String get chatListLoading => 'Загрузка чатов…';

  @override
  String get chatListUpdating => 'Обновление…';

  @override
  String get chatListEmpty => 'Пока нет ни одного чата';

  @override
  String chatListNoResults(String query) {
    return 'Нет результатов по запросу «$query»';
  }

  @override
  String get chatListSelectTitle => 'Выберите чат';

  @override
  String get chatListSelectSubtitle => 'Выберите чат в левой панели, чтобы начать общение';

  @override
  String get chatListPin => 'Закрепить сверху';

  @override
  String get chatListUnpin => 'Открепить';

  @override
  String chatListPinFailed(String error) {
    return 'Не удалось закрепить: $error';
  }

  @override
  String chatListUnpinFailed(String error) {
    return 'Не удалось открепить: $error';
  }

  @override
  String get timeJustNow => 'только что';

  @override
  String timeMinutesAgo(int count) {
    return '$count мин назад';
  }

  @override
  String timeHoursAgo(int count) {
    return '$count ч назад';
  }

  @override
  String timeDaysAgo(int count) {
    return '$count дн назад';
  }

  @override
  String get contactsSearch => 'Поиск...';

  @override
  String get contactsAdd => 'Добавить контакт';

  @override
  String get contactsLoading => 'Загрузка контактов…';

  @override
  String get contactsEmpty => 'Контакты не найдены';

  @override
  String contactsSectionBot(int count) {
    return 'БОТЫ — $count';
  }

  @override
  String contactsSectionContact(int count) {
    return 'КОНТАКТЫ — $count';
  }

  @override
  String get contactsSelectTitle => 'Выберите контакт';

  @override
  String get contactsSelectSubtitle => 'Выберите пользователя из списка, чтобы увидеть его профиль';

  @override
  String get contactsMessage => 'Сообщение';

  @override
  String get contactsCall => 'Вызов';

  @override
  String get chatLoadingMessages => 'Загрузка сообщений…';

  @override
  String get chatStatusOnline => 'В сети';

  @override
  String get chatStatusOffline => 'Не в сети';

  @override
  String get chatGroupIntro => 'Расскажите сообществу о себе!';

  @override
  String get chatEmpty => 'Пока нет сообщений';

  @override
  String chatSendFailed(String error) {
    return 'Не удалось отправить: $error';
  }

  @override
  String chatMessagePlaceholderChannel(String name) {
    return 'Сообщение в #$name';
  }

  @override
  String chatMessagePlaceholderUser(String name) {
    return 'Сообщение $name';
  }

  @override
  String get chatPinned => 'закреплено';

  @override
  String get chatUnsupported => '[неподдерживаемое сообщение]';

  @override
  String get chatMarkdown => 'Markdown';

  @override
  String get chatAttach => 'Прикрепить';

  @override
  String get chatVoiceMessage => 'Голосовое сообщение';

  @override
  String get chatVideoMessage => 'Видеосообщение';

  @override
  String get chatVoiceRecording => 'Запись голосового сообщения';

  @override
  String get chatVoiceRecordingCancel => 'Отмена';

  @override
  String get chatVoiceRecordingSend => 'Отправить';

  @override
  String get chatRecordingPermissionDenied => 'Доступ запрещён — включите доступ к микрофону/камере в настройках системы';

  @override
  String chatDropOverlayTitle(String name) {
    return 'Отправить $name';
  }

  @override
  String get chatDropOverlayHint => 'Перетащите файлы сюда, чтобы отправить их';

  @override
  String get chatEmoji => 'Эмодзи';

  @override
  String chatUserFallback(int uid) {
    return 'Пользователь $uid';
  }

  @override
  String chatGroupFallback(int gid) {
    return 'Группа $gid';
  }

  @override
  String get previewFile => '[Файл]';

  @override
  String get previewVoice => '[Голосовое]';

  @override
  String get previewArchive => '[Архив]';

  @override
  String get previewImage => '[Изображение]';

  @override
  String get previewReaction => '[Реакция]';

  @override
  String errorPrefix(String message) {
    return 'Ошибка: $message';
  }

  @override
  String get errorRequestFailed => 'Запрос не выполнен';

  @override
  String get authKickedFromOtherDevice => 'Вы вышли из системы: ваш аккаунт только что вошёл на другом устройстве.';

  @override
  String get authAccountDeleted => 'Ваш аккаунт был удалён.';

  @override
  String get authSessionEnded => 'Сессия завершена. Пожалуйста, войдите снова.';

  @override
  String get chatListMarkRead => 'Отметить как прочитанное';

  @override
  String get chatListMute => 'Отключить уведомления';

  @override
  String get chatListUnmute => 'Включить уведомления';

  @override
  String get chatListHide => 'Скрыть';

  @override
  String get chatListLeave => 'Покинуть канал';

  @override
  String get chatListMarkReadDone => 'Отмечено как прочитанное';

  @override
  String get chatListMuteDone => 'Уведомления отключены';

  @override
  String get chatListUnmuteDone => 'Уведомления включены';

  @override
  String get chatListHideDone => 'Скрыто';

  @override
  String get chatListLeaveDone => 'Вы покинули канал';

  @override
  String chatListLeaveFailed(String error) {
    return 'Не удалось покинуть канал: $error';
  }

  @override
  String chatListMuteFailed(String error) {
    return 'Не удалось выполнить действие: $error';
  }

  @override
  String get chatListMarkReadFailed => 'Не удалось отметить как прочитанное';

  @override
  String get createChannelTitle => 'Новый канал';

  @override
  String get createChannelNameLabel => 'Название канала';

  @override
  String get channelPublicLabel => 'Публичный канал';

  @override
  String get createChannelPublicAdminOnly => 'Только администраторы могут создавать публичные каналы';

  @override
  String get createChannelSubmit => 'Создать';

  @override
  String get createChannelNameRequired => 'Введите название канала';

  @override
  String get createChannelFailed => 'Не удалось создать канал';

  @override
  String get channelSettingsTitle => 'Настройки канала';

  @override
  String get channelUpdated => 'Канал обновлён';

  @override
  String get avatarUpdated => 'Аватар обновлён';

  @override
  String get channelVisibilityChanged => 'Видимость изменена';

  @override
  String get inviteLinkCopied => 'Ссылка скопирована';

  @override
  String get channelOverview => 'Обзор';

  @override
  String get channelNameLabel => 'Название';

  @override
  String get channelDescriptionLabel => 'Описание';

  @override
  String get channelSaveChanges => 'Сохранить изменения';

  @override
  String get channelAddMember => 'Добавить участника';

  @override
  String get channelInviteLinkSection => 'Ссылка-приглашение';

  @override
  String get channelGenerateInviteLink => 'Создать ссылку-приглашение';

  @override
  String get channelMuteLabel => 'Отключить уведомления канала';

  @override
  String get channelLeaveConfirmBody => 'Вы уверены, что хотите покинуть этот канал?';

  @override
  String get channelDeleteTitle => 'Удалить канал';

  @override
  String get channelDeleteConfirmBody => 'Канал будет безвозвратно удалён для всех участников. Это действие невозможно отменить.';

  @override
  String get actionLeave => 'Покинуть';

  @override
  String get accountEditNameTitle => 'Изменить имя';

  @override
  String get accountNameLabel => 'Имя';

  @override
  String get accountNameUpdated => 'Имя обновлено';

  @override
  String get accountChangePasswordTitle => 'Изменить пароль';

  @override
  String get accountCurrentPasswordLabel => 'Текущий пароль';

  @override
  String get accountNewPasswordLabel => 'Новый пароль';

  @override
  String get accountPasswordChanged => 'Пароль изменён';

  @override
  String get chatActionCopy => 'Копировать';

  @override
  String get chatActionForward => 'Переслать';

  @override
  String get chatActionSelect => 'Выбрать';

  @override
  String get chatCopiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get chatForwardedMessagePreview => '[Пересланное сообщение]';

  @override
  String get chatAutoDeleteTitle => 'Автоудаление сообщений';

  @override
  String chatExpiresTooltip(String duration) {
    return 'Исчезнет через $duration после отправки';
  }

  @override
  String get chatAutoDeleteOff => 'Выключено';

  @override
  String get chatAutoDelete5Min => '5 минут';

  @override
  String get chatAutoDelete10Min => '10 минут';

  @override
  String get chatAutoDelete1Hour => '1 час';

  @override
  String get chatAutoDelete1Day => '1 день';

  @override
  String get chatAutoDelete1Week => '1 неделя';

  @override
  String get chatAutoDeleteSaved => 'Сохранено';

  @override
  String get chatAutoDeleteSaveFailed => 'Не удалось сохранить';

  @override
  String get forwardSheetTitle => 'Переслать...';

  @override
  String get forwardMessageSent => 'Сообщение переслано';

  @override
  String forwardFailed(String error) {
    return 'Не удалось переслать: $error';
  }

  @override
  String get forwardNoConversations => 'Нет чатов';

  @override
  String forwardSelectedCount(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get archiveForwardedLabel => 'Пересланное(ые) сообщение(я)';

  @override
  String get archiveLoadFailed => 'Не удалось загрузить пересланное сообщение';

  @override
  String get archiveTapToView => 'Нажмите, чтобы посмотреть подробности';

  @override
  String archiveViewAll(int count) {
    return 'Показать все $count сообщений';
  }
}
