import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppL10nEs extends AppL10n {
  AppL10nEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'VoceChat';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionOpen => 'Abrir';

  @override
  String get actionChange => 'Cambiar';

  @override
  String get actionContact => 'Contacto';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionSend => 'Enviar';

  @override
  String get actionSearch => 'Buscar';

  @override
  String get actionMore => 'Más';

  @override
  String get actionRetry => 'Reintentar';

  @override
  String get chatToolPin => 'Fijado';

  @override
  String get chatActionReact => 'Añadir reacción';

  @override
  String get chatActionReply => 'Responder';

  @override
  String get chatActionEdit => 'Editar';

  @override
  String get chatActionDelete => 'Eliminar';

  @override
  String get chatEditMarker => '(editado)';

  @override
  String chatReplyingTo(String name) {
    return 'Respondiendo a $name';
  }

  @override
  String get chatDeleteConfirmTitle => '¿Eliminar mensaje?';

  @override
  String get chatDeleteConfirmBody => 'Esta acción no se puede deshacer.';

  @override
  String get chatEditCancel => 'Cancelar';

  @override
  String get chatEditSave => 'Guardar';

  @override
  String get chatFileDetailsTitle => 'Detalles del archivo';

  @override
  String get chatFileNameLabel => 'Nombre';

  @override
  String chatEditFailed(String error) {
    return 'Error al editar: $error';
  }

  @override
  String chatDeleteFailed(String error) {
    return 'Error al eliminar: $error';
  }

  @override
  String chatReplyFailed(String error) {
    return 'Error al responder: $error';
  }

  @override
  String get chatReplyDeleted => 'Este mensaje ha sido eliminado.';

  @override
  String get chatReplyVoiceMessage => '[Mensaje de voz]';

  @override
  String get chatToolSaved => 'Guardado';

  @override
  String get chatToolMembers => 'Miembros';

  @override
  String get chatToolEmpty => 'Todavía no hay contenido.';

  @override
  String get chatToolPinEmpty => 'No hay mensajes fijados.';

  @override
  String get chatToolSavedEmpty => 'No hay mensajes guardados.';

  @override
  String get chatToolMembersEmpty => 'No hay miembros.';

  @override
  String get chatToolUnpin => 'Desfijar';

  @override
  String get chatToolRemoveFav => 'Quitar';

  @override
  String get chatToolPinFail => 'Error al fijar';

  @override
  String get chatToolUnpinFail => 'Error al desfijar';

  @override
  String get chatToolSaveFail => 'Error al guardar';

  @override
  String get chatToolRemoveFavFail => 'Error al quitar';

  @override
  String get chatToolSavedAdded => 'Guardado';

  @override
  String get chatToolPinAdded => 'Fijado';

  @override
  String get chatToolUnpinned => 'Desfijado';

  @override
  String get chatSearchHint => 'Buscar mensajes';

  @override
  String get chatSearchEmpty => 'No hay mensajes coincidentes.';

  @override
  String get navChats => 'Chats';

  @override
  String get navContacts => 'Contactos';

  @override
  String get navSettings => 'Configuración';

  @override
  String get navSaved => 'Guardados';

  @override
  String get comingSoon => 'Próximamente';

  @override
  String get actionBack => 'Atrás';

  @override
  String get actionClose => 'Cerrar';

  @override
  String get memberRoleOwner => 'Propietario';

  @override
  String get tooltipDownload => 'Descargar';

  @override
  String get downloadSaved => 'Saved';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get tooltipZoomIn => 'Acercar';

  @override
  String get tooltipZoomOut => 'Alejar';

  @override
  String get tooltipFullscreen => 'Pantalla completa';

  @override
  String get tooltipExitFullscreen => 'Salir de pantalla completa';

  @override
  String get tooltipShowPassword => 'Mostrar contraseña';

  @override
  String get tooltipHidePassword => 'Ocultar contraseña';

  @override
  String get reactionDeletedUser => 'Usuario eliminado';

  @override
  String reactionTooltipMany(String names, int count, String emoji) {
    return '$names y $count más reaccionaron con $emoji';
  }

  @override
  String reactionTooltipFew(String names, String emoji) {
    return '$names reaccionaron con $emoji';
  }

  @override
  String get expiredImageTitle => 'Imagen no encontrada';

  @override
  String get expiredImageBody => 'La imagen expiró o fue eliminada';

  @override
  String get expiredVideoTitle => 'Video no encontrado';

  @override
  String get expiredVideoBody => 'El video expiró o fue eliminado';

  @override
  String get expiredAudioTitle => 'Audio no encontrado';

  @override
  String get expiredAudioBody => 'El audio expiró o fue eliminado';

  @override
  String get expiredFileTitle => 'Archivo no encontrado';

  @override
  String get expiredFileBody => 'El archivo expiró o fue eliminado';

  @override
  String get mediaLoadFailedRetry => 'Failed to load — tap to retry';

  @override
  String get mediaLikelyIncompatible => 'This device can\'t play this video format. Try downloading it instead.';

  @override
  String get featureUnavailable => 'Esta función no está disponible todavía';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get settingsGroupGeneral => 'general';

  @override
  String get settingsGroupAbout => 'acerca de';

  @override
  String get settingsMyAccount => 'Mi cuenta';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsStorage => 'Almacenamiento y datos';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsLogout => 'Cerrar sesión';

  @override
  String get settingsLogoutConfirmTitle => '¿Cerrar sesión?';

  @override
  String get settingsLogoutConfirmContent => 'Deberás iniciar sesión de nuevo para acceder a este servidor.';

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
  String get accountSwitcherRemoveConfirmBody => 'This removes the saved sign-in and cached messages for this account on this device.';

  @override
  String get accountSwitcherRemove => 'Remove';

  @override
  String get accountSwitcherSignedOut => 'Signed out';

  @override
  String get accountSwitcherSwitchFailed => 'Couldn\'t sign in to that account — please log in again.';

  @override
  String get accountEmail => 'Correo electrónico';

  @override
  String get accountUsername => 'Nombre de usuario';

  @override
  String get accountPassword => 'Contraseña';

  @override
  String get accountPasswordMasked => '*********';

  @override
  String get notificationsPush => 'Notificaciones push';

  @override
  String get notificationsPushSubtitle => 'Recibe avisos de nuevos mensajes y menciones.';

  @override
  String get notificationsSound => 'Sonidos de notificación';

  @override
  String get notificationsSoundSubtitle => 'Reproduce un sonido al recibir mensajes.';

  @override
  String get notificationsMentionsOnly => 'Solo menciones';

  @override
  String get notificationsMentionsOnlySubtitle => 'Notificar solo para @menciones.';

  @override
  String get appearanceTheme => 'TEMA';

  @override
  String get appearanceLight => 'Claro';

  @override
  String get appearanceSystem => 'Predeterminado del sistema';

  @override
  String get appearanceDark => 'Oscuro';

  @override
  String get appearanceLanguage => 'IDIOMA';

  @override
  String get languageSystem => 'Predeterminado del sistema';

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
  String get storageUsage => 'Uso de almacenamiento';

  @override
  String get storageAutoDownload => 'Descargar multimedia automáticamente';

  @override
  String get storageWifiOnly => 'Solo Wi-Fi';

  @override
  String get storageClearCache => 'Borrar caché';

  @override
  String get storageClearCacheConfirmTitle => '¿Borrar caché?';

  @override
  String get storageClearCacheConfirmBody => 'Esto elimina los mensajes e imágenes almacenados localmente. Se volverán a descargar cuando sea necesario.';

  @override
  String get storageClearCacheConfirm => 'Borrar';

  @override
  String get storageCacheCleared => 'Caché borrada';

  @override
  String get aboutAppVersion => 'Versión de la app';

  @override
  String get aboutWebsite => 'Sitio web';

  @override
  String get aboutReportBug => 'Reportar un error';

  @override
  String get aboutReportBugSubtitle => 'Ayúdanos a mejorar VoceChat.';

  @override
  String get loginWelcomeBack => 'Bienvenido de nuevo';

  @override
  String get loginEmail => 'Correo electrónico';

  @override
  String get loginEmailRequired => 'El correo electrónico es obligatorio';

  @override
  String get loginEmailInvalid => 'Introduce una dirección de correo válida';

  @override
  String get loginPassword => 'Contraseña';

  @override
  String get loginPasswordRequired => 'La contraseña es obligatoria';

  @override
  String get loginPasswordTooShort => 'La contraseña debe tener al menos 6 caracteres';

  @override
  String get loginForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get loginRememberMe => 'Recordar contraseña';

  @override
  String get loginSignIn => 'Iniciar sesión';

  @override
  String get loginMagicLink => 'Usar enlace mágico';

  @override
  String get loginPasskey => 'Iniciar sesión con clave de acceso';

  @override
  String get loginSwitchServer => 'Cambiar de servidor';

  @override
  String get loginNoAccount => '¿No tienes una cuenta? ';

  @override
  String get loginSignUp => 'Registrarse';

  @override
  String get loginErrorInvalidCredentials => 'Correo electrónico o contraseña incorrectos';

  @override
  String get loginErrorAccountFrozen => 'Esta cuenta ha sido congelada. Contacta con tu administrador.';

  @override
  String get loginErrorNotInvited => 'No se encontró ninguna cuenta asociada. Pide a un administrador un enlace de invitación.';

  @override
  String get loginErrorMethodNotSupported => 'El servidor no admite este método de inicio de sesión.';

  @override
  String get loginErrorCannotReachServer => 'No se puede contactar con el servidor. Comprueba tu red o la URL del servidor.';

  @override
  String get registerTitle => 'Crear cuenta';

  @override
  String get registerHeader => 'Únete a la conversación';

  @override
  String get registerSubtitle => 'Completa tus datos para empezar.';

  @override
  String get registerName => 'Nombre completo';

  @override
  String get registerNameRequired => 'El nombre es obligatorio';

  @override
  String get registerNameTooShort => 'El nombre debe tener al menos 2 caracteres';

  @override
  String get registerEmailRequired => 'El correo electrónico es obligatorio';

  @override
  String get registerEmailInvalid => 'Introduce un correo electrónico válido';

  @override
  String get registerPasswordRequired => 'La contraseña es obligatoria';

  @override
  String get registerPasswordTooShort => 'Se requieren al menos 6 caracteres';

  @override
  String get registerConfirmPassword => 'Confirmar contraseña';

  @override
  String get registerConfirmRequired => 'Confirma tu contraseña';

  @override
  String get registerConfirmMismatch => 'Las contraseñas no coinciden';

  @override
  String get registerCreate => 'Crear cuenta';

  @override
  String get registerMagicLink => 'Enviar enlace de invitación en su lugar';

  @override
  String get registerEmailFirst => 'Introduce primero tu correo electrónico';

  @override
  String get registerInvitationSent => 'Enlace de invitación enviado';

  @override
  String get registerHaveAccount => '¿Ya tienes una cuenta? ';

  @override
  String get registerInviteRequiresEmailConfirmation => 'This server requires email confirmation for invited signups, which isn\'t supported yet. Please ask your admin for help.';

  @override
  String get serverPickerTitle => 'Seleccionar servidor';

  @override
  String get serverPickerEmptyTitle => 'Conéctate a un servidor VoceChat';

  @override
  String get serverPickerEmptySubtitle => 'Agrega un servidor para empezar a chatear con tu equipo.';

  @override
  String get serverPickerAddFirst => 'Agrega tu primer servidor';

  @override
  String get serverPickerAdd => 'Agregar servidor';

  @override
  String get serverPickerContinue => 'Continuar';

  @override
  String get serverPickerUseInviteLink => 'Use invitation link';

  @override
  String get serverAddTitle => 'Agregar servidor';

  @override
  String get serverUrl => 'URL del servidor';

  @override
  String get serverUrlHint => 'https://chat.example.com';

  @override
  String get serverUrlRequired => 'La URL es obligatoria';

  @override
  String get serverUrlMustHttps => 'Debe empezar con http:// o https://';

  @override
  String get serverTesting => 'Probando…';

  @override
  String get serverTestConnection => 'Probar conexión';

  @override
  String get serverTestSuccess => 'Conexión exitosa';

  @override
  String get serverTestFailed => 'No se pudo conectar con el servidor';

  @override
  String get serverSave => 'Guardar y continuar';

  @override
  String get inviteLinkSheetTitle => 'Join with invitation link';

  @override
  String get inviteLinkHint => 'Paste your invitation link here';

  @override
  String get inviteLinkRequired => 'Please paste an invitation link';

  @override
  String get inviteLinkPasteFromClipboard => 'Paste from clipboard';

  @override
  String get inviteLinkInvalid => 'This doesn\'t look like a valid invitation link';

  @override
  String get inviteLinkExpired => 'This invitation link has expired or already been used';

  @override
  String get inviteLinkCheckFailed => 'Couldn\'t verify the invitation link. Check your network and try again.';

  @override
  String get inviteLinkContinue => 'Continue';

  @override
  String get chatListSearch => 'Buscar...';

  @override
  String get chatListNewChat => 'Nuevo chat';

  @override
  String get chatListLoading => 'Cargando chats…';

  @override
  String get chatListUpdating => 'Actualizando…';

  @override
  String get chatListEmpty => 'Todavía no hay conversaciones';

  @override
  String chatListNoResults(String query) {
    return 'No hay resultados para \"$query\"';
  }

  @override
  String get chatListSelectTitle => 'Selecciona una conversación';

  @override
  String get chatListSelectSubtitle => 'Elige un chat del panel izquierdo para empezar a escribir';

  @override
  String get chatListPin => 'Fijar arriba';

  @override
  String get chatListUnpin => 'Desfijar';

  @override
  String chatListPinFailed(String error) {
    return 'Error al fijar: $error';
  }

  @override
  String chatListUnpinFailed(String error) {
    return 'Error al desfijar: $error';
  }

  @override
  String get timeJustNow => 'justo ahora';

  @override
  String timeMinutesAgo(int count) {
    return 'hace $count min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'hace $count horas';
  }

  @override
  String timeDaysAgo(int count) {
    return 'hace $count días';
  }

  @override
  String get contactsSearch => 'Buscar...';

  @override
  String get contactsAdd => 'Agregar contacto';

  @override
  String get contactsLoading => 'Cargando contactos…';

  @override
  String get contactsEmpty => 'No se encontraron contactos';

  @override
  String contactsSectionBot(int count) {
    return 'BOT - $count';
  }

  @override
  String contactsSectionContact(int count) {
    return 'CONTACTO - $count';
  }

  @override
  String get contactsSelectTitle => 'Selecciona un contacto';

  @override
  String get contactsSelectSubtitle => 'Elige a alguien de la lista para ver su perfil';

  @override
  String get contactsMessage => 'Mensaje';

  @override
  String get contactsCall => 'Llamar';

  @override
  String get chatLoadingMessages => 'Cargando mensajes…';

  @override
  String get chatStatusOnline => 'En línea';

  @override
  String get chatStatusOffline => 'Desconectado';

  @override
  String get chatGroupIntro => '¡Preséntate a la comunidad!';

  @override
  String get chatEmpty => 'Todavía no hay mensajes';

  @override
  String chatSendFailed(String error) {
    return 'Error al enviar: $error';
  }

  @override
  String chatMessagePlaceholderChannel(String name) {
    return 'Mensaje a #$name';
  }

  @override
  String chatMessagePlaceholderUser(String name) {
    return 'Mensaje a $name';
  }

  @override
  String get chatPinned => 'fijado';

  @override
  String get chatUnsupported => '[mensaje no compatible]';

  @override
  String get chatMarkdown => 'Markdown';

  @override
  String get chatAttach => 'Adjuntar';

  @override
  String get chatVoiceMessage => 'Mensaje de voz';

  @override
  String get chatVideoMessage => 'Mensaje de video';

  @override
  String get chatVoiceRecording => 'Grabando mensaje de voz';

  @override
  String get chatVoiceRecordingCancel => 'Cancelar';

  @override
  String get chatVoiceRecordingSend => 'Enviar';

  @override
  String get chatRecordingPermissionDenied => 'Permiso denegado: habilita el acceso al micrófono o la cámara en la configuración del sistema';

  @override
  String get chatPhotoPermissionDenied => 'Permission denied — enable photo library access in system settings';

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
    return 'Enviar a $name';
  }

  @override
  String get chatDropOverlayHint => 'Suelta los archivos aquí para enviarlos';

  @override
  String get chatEmoji => 'Emoji';

  @override
  String chatUserFallback(int uid) {
    return 'Usuario $uid';
  }

  @override
  String chatGroupFallback(int gid) {
    return 'Grupo $gid';
  }

  @override
  String get previewFile => '[Archivo]';

  @override
  String get previewVoice => '[Voz]';

  @override
  String get previewArchive => '[Archivo comprimido]';

  @override
  String get previewImage => '[Imagen]';

  @override
  String get previewReaction => '[Reacción]';

  @override
  String errorPrefix(String message) {
    return 'Error: $message';
  }

  @override
  String get errorRequestFailed => 'Error en la solicitud';

  @override
  String get authKickedFromOtherDevice => 'Sesión cerrada: tu cuenta acaba de iniciar sesión en otro dispositivo.';

  @override
  String get authAccountDeleted => 'Tu cuenta ha sido eliminada.';

  @override
  String get authSessionEnded => 'Tu sesión ha finalizado. Inicia sesión de nuevo.';

  @override
  String get chatListMarkRead => 'Marcar como leído';

  @override
  String get chatListMute => 'Silenciar';

  @override
  String get chatListUnmute => 'Quitar silencio';

  @override
  String get chatListHide => 'Ocultar';

  @override
  String get chatListLeave => 'Abandonar canal';

  @override
  String get chatListMarkReadDone => 'Marcado como leído';

  @override
  String get chatListMuteDone => 'Silenciado';

  @override
  String get chatListUnmuteDone => 'Silencio desactivado';

  @override
  String get chatListHideDone => 'Oculto';

  @override
  String get chatListLeaveDone => 'Canal abandonado';

  @override
  String chatListLeaveFailed(String error) {
    return 'Error al abandonar: $error';
  }

  @override
  String chatListMuteFailed(String error) {
    return 'Error al silenciar: $error';
  }

  @override
  String get chatListMarkReadFailed => 'Error al marcar como leído';

  @override
  String get createChannelTitle => 'Nuevo canal';

  @override
  String get createChannelNameLabel => 'Nombre del canal';

  @override
  String get channelPublicLabel => 'Canal público';

  @override
  String get createChannelPublicAdminOnly => 'Solo los administradores pueden crear canales públicos';

  @override
  String get createChannelSubmit => 'Crear';

  @override
  String get createChannelNameRequired => 'Introduce un nombre para el canal';

  @override
  String get createChannelFailed => 'Error al crear el canal';

  @override
  String get channelSettingsTitle => 'Configuración del canal';

  @override
  String get channelUpdated => 'Canal actualizado';

  @override
  String get avatarUpdated => 'Avatar actualizado';

  @override
  String get channelVisibilityChanged => 'Visibilidad cambiada';

  @override
  String get inviteLinkCopied => 'Enlace copiado';

  @override
  String get channelOverview => 'Resumen';

  @override
  String get channelNameLabel => 'Nombre';

  @override
  String get channelDescriptionLabel => 'Descripción';

  @override
  String get channelSaveChanges => 'Guardar cambios';

  @override
  String get channelAddMember => 'Agregar miembro';

  @override
  String get channelInviteLinkSection => 'Enlace de invitación';

  @override
  String get channelGenerateInviteLink => 'Generar enlace de invitación';

  @override
  String get channelMuteLabel => 'Silenciar canal';

  @override
  String get channelLeaveConfirmBody => '¿Seguro que quieres abandonar este canal?';

  @override
  String get channelDeleteTitle => 'Eliminar canal';

  @override
  String get channelDeleteConfirmBody => 'Esto eliminará permanentemente el canal para todos los miembros. Esta acción no se puede deshacer.';

  @override
  String get actionLeave => 'Abandonar';

  @override
  String get accountEditNameTitle => 'Editar nombre';

  @override
  String get accountNameLabel => 'Nombre';

  @override
  String get accountNameUpdated => 'Nombre actualizado';

  @override
  String get accountChangePasswordTitle => 'Cambiar contraseña';

  @override
  String get accountCurrentPasswordLabel => 'Contraseña actual';

  @override
  String get accountNewPasswordLabel => 'Nueva contraseña';

  @override
  String get accountPasswordChanged => 'Contraseña cambiada';

  @override
  String get chatActionCopy => 'Copiar';

  @override
  String get chatActionForward => 'Reenviar';

  @override
  String get chatActionSelect => 'Seleccionar';

  @override
  String get chatCopiedToClipboard => 'Copiado al portapapeles';

  @override
  String get chatForwardedMessagePreview => '[Mensaje reenviado]';

  @override
  String get chatAutoDeleteTitle => 'Eliminación automática de mensajes';

  @override
  String chatExpiresTooltip(String duration) {
    return 'Desaparece $duration después de enviarse';
  }

  @override
  String get chatAutoDeleteOff => 'Desactivado';

  @override
  String get chatAutoDelete5Min => '5 minutos';

  @override
  String get chatAutoDelete10Min => '10 minutos';

  @override
  String get chatAutoDelete1Hour => '1 hora';

  @override
  String get chatAutoDelete1Day => '1 día';

  @override
  String get chatAutoDelete1Week => '1 semana';

  @override
  String get chatAutoDeleteSaved => 'Guardado';

  @override
  String get chatAutoDeleteSaveFailed => 'Error al guardar';

  @override
  String get forwardSheetTitle => 'Reenviar a...';

  @override
  String get forwardMessageSent => 'Mensaje reenviado';

  @override
  String forwardFailed(String error) {
    return 'Error al reenviar: $error';
  }

  @override
  String get forwardNoConversations => 'No hay conversaciones';

  @override
  String forwardSelectedCount(int count) {
    return '$count seleccionados';
  }

  @override
  String get archiveForwardedLabel => 'Mensaje(s) reenviado(s)';

  @override
  String get archiveLoadFailed => 'Error al cargar el mensaje reenviado';

  @override
  String get archiveTapToView => 'Toca para ver detalles';

  @override
  String archiveViewAll(int count) {
    return 'Ver los $count mensajes';
  }

  @override
  String get voiceStartCall => 'Start voice call';

  @override
  String get voiceIncomingCall => 'Incoming call';

  @override
  String get voiceCallingOut => 'Calling...';

  @override
  String get voiceMute => 'Mute';

  @override
  String get voiceUnmute => 'Unmute';

  @override
  String get voiceDeafen => 'Deafen';

  @override
  String get voiceUndeafen => 'Undeafen';

  @override
  String get voiceCameraOn => 'Turn on camera';

  @override
  String get voiceCameraOff => 'Turn off camera';

  @override
  String get voiceShareScreen => 'Share screen';

  @override
  String get voiceFullscreen => 'Fullscreen';

  @override
  String get voiceLeave => 'Leave call';

  @override
  String get voiceConnected => 'Voice connected';

  @override
  String get voiceReconnecting => 'Reconnecting...';
}
