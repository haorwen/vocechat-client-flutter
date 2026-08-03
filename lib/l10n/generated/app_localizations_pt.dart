// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppL10nPt extends AppL10n {
  AppL10nPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'VoceChat';

  @override
  String get actionCancel => 'Cancelar';

  @override
  String get actionOpen => 'Abrir';

  @override
  String get actionChange => 'Alterar';

  @override
  String get actionContact => 'Contato';

  @override
  String get actionEdit => 'Editar';

  @override
  String get actionSend => 'Enviar';

  @override
  String get actionSearch => 'Pesquisar';

  @override
  String get actionMore => 'Mais';

  @override
  String get actionRetry => 'Tentar novamente';

  @override
  String get chatToolPin => 'Fixado';

  @override
  String get chatActionReact => 'Adicionar reação';

  @override
  String get chatActionReply => 'Responder';

  @override
  String get chatActionEdit => 'Editar';

  @override
  String get chatActionDelete => 'Excluir';

  @override
  String get chatEditMarker => '(editado)';

  @override
  String chatReplyingTo(String name) {
    return 'Respondendo a $name';
  }

  @override
  String get chatDeleteConfirmTitle => 'Excluir mensagem?';

  @override
  String get chatDeleteConfirmBody => 'Esta ação não pode ser desfeita.';

  @override
  String get chatEditCancel => 'Cancelar';

  @override
  String get chatEditSave => 'Salvar';

  @override
  String get chatFileDetailsTitle => 'Detalhes do arquivo';

  @override
  String get chatFileNameLabel => 'Nome';

  @override
  String chatEditFailed(String error) {
    return 'Falha ao editar: $error';
  }

  @override
  String chatDeleteFailed(String error) {
    return 'Falha ao excluir: $error';
  }

  @override
  String chatReplyFailed(String error) {
    return 'Falha ao responder: $error';
  }

  @override
  String get chatReplyDeleted => 'Esta mensagem foi excluída.';

  @override
  String get chatReplyVoiceMessage => '[Mensagem de voz]';

  @override
  String get chatToolSaved => 'Salvo';

  @override
  String get chatToolMembers => 'Membros';

  @override
  String get chatToolEmpty => 'Ainda não há conteúdo.';

  @override
  String get chatToolPinEmpty => 'Nenhuma mensagem fixada.';

  @override
  String get chatToolSavedEmpty => 'Nenhuma mensagem salva.';

  @override
  String get chatToolMembersEmpty => 'Nenhum membro.';

  @override
  String get chatToolUnpin => 'Desafixar';

  @override
  String get chatToolRemoveFav => 'Remover';

  @override
  String get chatToolPinFail => 'Falha ao fixar';

  @override
  String get chatToolUnpinFail => 'Falha ao desafixar';

  @override
  String get chatToolSaveFail => 'Falha ao salvar';

  @override
  String get chatToolRemoveFavFail => 'Falha ao remover';

  @override
  String get chatToolSavedAdded => 'Salvo';

  @override
  String get chatToolPinAdded => 'Fixado';

  @override
  String get chatToolUnpinned => 'Desafixado';

  @override
  String get chatSearchHint => 'Pesquisar mensagens';

  @override
  String get chatSearchEmpty => 'Nenhuma mensagem encontrada.';

  @override
  String get navChats => 'Conversas';

  @override
  String get navContacts => 'Contatos';

  @override
  String get navSettings => 'Configurações';

  @override
  String get navSaved => 'Salvos';

  @override
  String get comingSoon => 'Em breve';

  @override
  String get actionBack => 'Voltar';

  @override
  String get actionClose => 'Fechar';

  @override
  String get memberRoleOwner => 'Proprietário';

  @override
  String get tooltipDownload => 'Baixar';

  @override
  String get tooltipZoomIn => 'Aumentar zoom';

  @override
  String get tooltipZoomOut => 'Diminuir zoom';

  @override
  String get tooltipFullscreen => 'Tela cheia';

  @override
  String get tooltipExitFullscreen => 'Sair da tela cheia';

  @override
  String get tooltipShowPassword => 'Mostrar senha';

  @override
  String get tooltipHidePassword => 'Ocultar senha';

  @override
  String get reactionDeletedUser => 'Usuário excluído';

  @override
  String reactionTooltipMany(String names, int count, String emoji) {
    return '$names e mais $count pessoas reagiram com $emoji';
  }

  @override
  String reactionTooltipFew(String names, String emoji) {
    return '$names reagiu com $emoji';
  }

  @override
  String get expiredImageTitle => 'Imagem não encontrada';

  @override
  String get expiredImageBody => 'Imagem expirada ou excluída';

  @override
  String get expiredVideoTitle => 'Vídeo não encontrado';

  @override
  String get expiredVideoBody => 'Vídeo expirado ou excluído';

  @override
  String get expiredAudioTitle => 'Áudio não encontrado';

  @override
  String get expiredAudioBody => 'Áudio expirado ou excluído';

  @override
  String get expiredFileTitle => 'Arquivo não encontrado';

  @override
  String get expiredFileBody => 'Arquivo expirado ou excluído';

  @override
  String get mediaLoadFailedRetry => 'Failed to load — tap to retry';

  @override
  String get mediaLikelyIncompatible =>
      'This device can\'t play this video format. Try downloading it instead.';

  @override
  String get featureUnavailable => 'Este recurso ainda não está disponível';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsGroupGeneral => 'geral';

  @override
  String get settingsGroupAbout => 'sobre';

  @override
  String get settingsMyAccount => 'Minha conta';

  @override
  String get settingsNotifications => 'Notificações';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsStorage => 'Armazenamento e dados';

  @override
  String get settingsAbout => 'Sobre';

  @override
  String get settingsLogout => 'Sair';

  @override
  String get settingsLogoutConfirmTitle => 'Sair da conta?';

  @override
  String get settingsLogoutConfirmContent =>
      'Você precisará entrar novamente para acessar este servidor.';

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
  String get accountEmail => 'E-mail';

  @override
  String get accountUsername => 'Nome de usuário';

  @override
  String get accountPassword => 'Senha';

  @override
  String get accountPasswordMasked => '*********';

  @override
  String get notificationsPush => 'Notificações push';

  @override
  String get notificationsPushSubtitle =>
      'Receba notificações de novas mensagens e menções.';

  @override
  String get notificationsSound => 'Sons de notificação';

  @override
  String get notificationsSoundSubtitle =>
      'Reproduzir um som ao receber mensagens.';

  @override
  String get notificationsMentionsOnly => 'Somente menções';

  @override
  String get notificationsMentionsOnlySubtitle =>
      'Notificar apenas para @menções.';

  @override
  String get appearanceTheme => 'TEMA';

  @override
  String get appearanceLight => 'Claro';

  @override
  String get appearanceSystem => 'Padrão do sistema';

  @override
  String get appearanceDark => 'Escuro';

  @override
  String get appearanceLanguage => 'IDIOMA';

  @override
  String get languageSystem => 'Padrão do sistema';

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
  String get storageUsage => 'Uso de armazenamento';

  @override
  String get storageAutoDownload => 'Download automático de mídia';

  @override
  String get storageWifiOnly => 'Somente Wi-Fi';

  @override
  String get storageClearCache => 'Limpar cache';

  @override
  String get storageClearCacheConfirmTitle => 'Limpar cache?';

  @override
  String get storageClearCacheConfirmBody =>
      'Isso remove mensagens e imagens armazenadas localmente. Serão baixadas novamente quando necessário.';

  @override
  String get storageClearCacheConfirm => 'Limpar';

  @override
  String get storageCacheCleared => 'Cache limpo';

  @override
  String get aboutAppVersion => 'Versão do aplicativo';

  @override
  String get aboutWebsite => 'Site';

  @override
  String get aboutReportBug => 'Reportar um problema';

  @override
  String get aboutReportBugSubtitle => 'Ajude-nos a melhorar o VoceChat.';

  @override
  String get loginWelcomeBack => 'Bem-vindo de volta';

  @override
  String get loginEmail => 'E-mail';

  @override
  String get loginEmailRequired => 'O e-mail é obrigatório';

  @override
  String get loginEmailInvalid => 'Insira um endereço de e-mail válido';

  @override
  String get loginPassword => 'Senha';

  @override
  String get loginPasswordRequired => 'A senha é obrigatória';

  @override
  String get loginPasswordTooShort =>
      'A senha deve ter pelo menos 6 caracteres';

  @override
  String get loginForgotPassword => 'Esqueceu a senha?';

  @override
  String get loginRememberMe => 'Lembrar senha';

  @override
  String get loginSignIn => 'Entrar';

  @override
  String get loginMagicLink => 'Usar link mágico';

  @override
  String get loginPasskey => 'Entrar com chave de acesso';

  @override
  String get loginSwitchServer => 'Trocar servidor';

  @override
  String get loginNoAccount => 'Não tem uma conta? ';

  @override
  String get loginSignUp => 'Cadastre-se';

  @override
  String get loginErrorInvalidCredentials => 'E-mail ou senha incorretos';

  @override
  String get loginErrorAccountFrozen =>
      'Esta conta foi congelada. Contate o administrador.';

  @override
  String get loginErrorNotInvited =>
      'Nenhuma conta associada encontrada. Peça um link de convite ao administrador.';

  @override
  String get loginErrorMethodNotSupported =>
      'Este método de login não é suportado pelo servidor.';

  @override
  String get loginErrorCannotReachServer =>
      'Não foi possível conectar ao servidor. Verifique sua rede ou o endereço do servidor.';

  @override
  String get registerTitle => 'Criar conta';

  @override
  String get registerHeader => 'Junte-se à conversa';

  @override
  String get registerSubtitle => 'Preencha seus dados para começar.';

  @override
  String get registerName => 'Nome completo';

  @override
  String get registerNameRequired => 'O nome é obrigatório';

  @override
  String get registerNameTooShort => 'O nome deve ter pelo menos 2 caracteres';

  @override
  String get registerEmailRequired => 'O e-mail é obrigatório';

  @override
  String get registerEmailInvalid => 'Insira um e-mail válido';

  @override
  String get registerPasswordRequired => 'A senha é obrigatória';

  @override
  String get registerPasswordTooShort =>
      'São necessários pelo menos 6 caracteres';

  @override
  String get registerConfirmPassword => 'Confirmar senha';

  @override
  String get registerConfirmRequired => 'Confirme sua senha';

  @override
  String get registerConfirmMismatch => 'As senhas não coincidem';

  @override
  String get registerCreate => 'Criar conta';

  @override
  String get registerMagicLink => 'Enviar link de convite em vez disso';

  @override
  String get registerEmailFirst => 'Insira seu e-mail primeiro';

  @override
  String get registerInvitationSent => 'Link de convite enviado';

  @override
  String get registerHaveAccount => 'Já tem uma conta? ';

  @override
  String get registerInviteRequiresEmailConfirmation =>
      'This server requires email confirmation for invited signups, which isn\'t supported yet. Please ask your admin for help.';

  @override
  String get serverPickerTitle => 'Selecionar servidor';

  @override
  String get serverPickerEmptyTitle => 'Conecte-se a um servidor VoceChat';

  @override
  String get serverPickerEmptySubtitle =>
      'Adicione um servidor para começar a conversar com sua equipe.';

  @override
  String get serverPickerAddFirst => 'Adicione seu primeiro servidor';

  @override
  String get serverPickerAdd => 'Adicionar servidor';

  @override
  String get serverPickerContinue => 'Continuar';

  @override
  String get serverPickerUseInviteLink => 'Use invitation link';

  @override
  String get serverAddTitle => 'Adicionar servidor';

  @override
  String get serverUrl => 'URL do servidor';

  @override
  String get serverUrlHint => 'https://chat.example.com';

  @override
  String get serverUrlRequired => 'A URL é obrigatória';

  @override
  String get serverUrlMustHttps => 'Deve começar com http:// ou https://';

  @override
  String get serverTesting => 'Testando…';

  @override
  String get serverTestConnection => 'Testar conexão';

  @override
  String get serverTestSuccess => 'Conexão bem-sucedida';

  @override
  String get serverTestFailed => 'Não foi possível conectar ao servidor';

  @override
  String get serverSave => 'Salvar e continuar';

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
  String get chatListSearch => 'Pesquisar...';

  @override
  String get chatListNewChat => 'Nova conversa';

  @override
  String get chatListLoading => 'Carregando conversas…';

  @override
  String get chatListUpdating => 'Atualizando…';

  @override
  String get chatListEmpty => 'Ainda não há conversas';

  @override
  String chatListNoResults(String query) {
    return 'Nenhum resultado para \"$query\"';
  }

  @override
  String get chatListSelectTitle => 'Selecione uma conversa';

  @override
  String get chatListSelectSubtitle =>
      'Escolha uma conversa no painel à esquerda para começar a enviar mensagens';

  @override
  String get chatListPin => 'Fixar no topo';

  @override
  String get chatListUnpin => 'Desafixar';

  @override
  String chatListPinFailed(String error) {
    return 'Falha ao fixar: $error';
  }

  @override
  String chatListUnpinFailed(String error) {
    return 'Falha ao desafixar: $error';
  }

  @override
  String get timeJustNow => 'agora mesmo';

  @override
  String timeMinutesAgo(int count) {
    return 'há $count min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'há $count horas';
  }

  @override
  String timeDaysAgo(int count) {
    return 'há $count dias';
  }

  @override
  String get contactsSearch => 'Pesquisar...';

  @override
  String get contactsAdd => 'Adicionar contato';

  @override
  String get contactsLoading => 'Carregando contatos…';

  @override
  String get contactsEmpty => 'Nenhum contato encontrado';

  @override
  String contactsSectionBot(int count) {
    return 'BOT - $count';
  }

  @override
  String contactsSectionContact(int count) {
    return 'CONTATO - $count';
  }

  @override
  String get contactsSelectTitle => 'Selecione um contato';

  @override
  String get contactsSelectSubtitle =>
      'Escolha alguém na lista para ver o perfil';

  @override
  String get contactsMessage => 'Mensagem';

  @override
  String get contactsCall => 'Chamada';

  @override
  String get chatLoadingMessages => 'Carregando mensagens…';

  @override
  String get chatStatusOnline => 'Online';

  @override
  String get chatStatusOffline => 'Offline';

  @override
  String get chatGroupIntro => 'Apresente-se à comunidade!';

  @override
  String get chatEmpty => 'Ainda não há mensagens';

  @override
  String chatSendFailed(String error) {
    return 'Falha ao enviar: $error';
  }

  @override
  String chatMessagePlaceholderChannel(String name) {
    return 'Mensagem para #$name';
  }

  @override
  String chatMessagePlaceholderUser(String name) {
    return 'Mensagem para $name';
  }

  @override
  String get chatPinned => 'fixado';

  @override
  String get chatUnsupported => '[mensagem não suportada]';

  @override
  String get chatMarkdown => 'Markdown';

  @override
  String get chatAttach => 'Anexar';

  @override
  String get chatVoiceMessage => 'Mensagem de voz';

  @override
  String get chatVideoMessage => 'Mensagem de vídeo';

  @override
  String get chatVoiceRecording => 'Gravando mensagem de voz';

  @override
  String get chatVoiceRecordingCancel => 'Cancelar';

  @override
  String get chatVoiceRecordingSend => 'Enviar';

  @override
  String get chatRecordingPermissionDenied =>
      'Permissão negada — ative o acesso ao microfone/câmera nas configurações do sistema';

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
    return 'Enviar para $name';
  }

  @override
  String get chatDropOverlayHint => 'Solte os arquivos aqui para enviá-los';

  @override
  String get chatEmoji => 'Emoji';

  @override
  String chatUserFallback(int uid) {
    return 'Usuário $uid';
  }

  @override
  String chatGroupFallback(int gid) {
    return 'Grupo $gid';
  }

  @override
  String get previewFile => '[Arquivo]';

  @override
  String get previewVoice => '[Voz]';

  @override
  String get previewArchive => '[Arquivo compactado]';

  @override
  String get previewImage => '[Imagem]';

  @override
  String get previewReaction => '[Reação]';

  @override
  String errorPrefix(String message) {
    return 'Erro: $message';
  }

  @override
  String get errorRequestFailed => 'Falha na solicitação';

  @override
  String get authKickedFromOtherDevice =>
      'Sessão encerrada: sua conta acabou de entrar em outro dispositivo.';

  @override
  String get authAccountDeleted => 'Sua conta foi excluída.';

  @override
  String get authSessionEnded =>
      'Sua sessão foi encerrada. Faça login novamente.';

  @override
  String get chatListMarkRead => 'Marcar como lida';

  @override
  String get chatListMute => 'Silenciar';

  @override
  String get chatListUnmute => 'Reativar som';

  @override
  String get chatListHide => 'Ocultar';

  @override
  String get chatListLeave => 'Sair do canal';

  @override
  String get chatListMarkReadDone => 'Marcado como lida';

  @override
  String get chatListMuteDone => 'Silenciado';

  @override
  String get chatListUnmuteDone => 'Som reativado';

  @override
  String get chatListHideDone => 'Ocultado';

  @override
  String get chatListLeaveDone => 'Você saiu do canal';

  @override
  String chatListLeaveFailed(String error) {
    return 'Falha ao sair: $error';
  }

  @override
  String chatListMuteFailed(String error) {
    return 'Falha ao silenciar: $error';
  }

  @override
  String get chatListMarkReadFailed => 'Falha ao marcar como lida';

  @override
  String get createChannelTitle => 'Novo canal';

  @override
  String get createChannelNameLabel => 'Nome do canal';

  @override
  String get channelPublicLabel => 'Canal público';

  @override
  String get createChannelPublicAdminOnly =>
      'Somente administradores podem criar canais públicos';

  @override
  String get createChannelSubmit => 'Criar';

  @override
  String get createChannelNameRequired => 'Informe um nome para o canal';

  @override
  String get createChannelFailed => 'Falha ao criar o canal';

  @override
  String get channelSettingsTitle => 'Configurações do canal';

  @override
  String get channelUpdated => 'Canal atualizado';

  @override
  String get avatarUpdated => 'Avatar atualizado';

  @override
  String get channelVisibilityChanged => 'Visibilidade alterada';

  @override
  String get inviteLinkCopied => 'Link copiado';

  @override
  String get channelOverview => 'Visão geral';

  @override
  String get channelNameLabel => 'Nome';

  @override
  String get channelDescriptionLabel => 'Descrição';

  @override
  String get channelSaveChanges => 'Salvar alterações';

  @override
  String get channelAddMember => 'Adicionar membro';

  @override
  String get channelInviteLinkSection => 'Link de convite';

  @override
  String get channelGenerateInviteLink => 'Gerar link de convite';

  @override
  String get channelMuteLabel => 'Silenciar canal';

  @override
  String get channelLeaveConfirmBody =>
      'Tem certeza de que deseja sair deste canal?';

  @override
  String get channelDeleteTitle => 'Excluir canal';

  @override
  String get channelDeleteConfirmBody =>
      'Isso excluirá permanentemente o canal para todos os membros. Esta ação não pode ser desfeita.';

  @override
  String get actionLeave => 'Sair';

  @override
  String get accountEditNameTitle => 'Editar nome';

  @override
  String get accountNameLabel => 'Nome';

  @override
  String get accountNameUpdated => 'Nome atualizado';

  @override
  String get accountChangePasswordTitle => 'Alterar senha';

  @override
  String get accountCurrentPasswordLabel => 'Senha atual';

  @override
  String get accountNewPasswordLabel => 'Nova senha';

  @override
  String get accountPasswordChanged => 'Senha alterada';

  @override
  String get chatActionCopy => 'Copiar';

  @override
  String get chatActionForward => 'Encaminhar';

  @override
  String get chatActionSelect => 'Selecionar';

  @override
  String get chatCopiedToClipboard => 'Copiado para a área de transferência';

  @override
  String get chatForwardedMessagePreview => '[Mensagem encaminhada]';

  @override
  String get chatAutoDeleteTitle => 'Exclusão automática de mensagens';

  @override
  String chatExpiresTooltip(String duration) {
    return 'Desaparece $duration após o envio';
  }

  @override
  String get chatAutoDeleteOff => 'Desativado';

  @override
  String get chatAutoDelete5Min => '5 minutos';

  @override
  String get chatAutoDelete10Min => '10 minutos';

  @override
  String get chatAutoDelete1Hour => '1 hora';

  @override
  String get chatAutoDelete1Day => '1 dia';

  @override
  String get chatAutoDelete1Week => '1 semana';

  @override
  String get chatAutoDeleteSaved => 'Salvo';

  @override
  String get chatAutoDeleteSaveFailed => 'Falha ao salvar';

  @override
  String get forwardSheetTitle => 'Encaminhar para...';

  @override
  String get forwardMessageSent => 'Mensagem encaminhada';

  @override
  String forwardFailed(String error) {
    return 'Falha ao encaminhar: $error';
  }

  @override
  String get forwardNoConversations => 'Nenhuma conversa';

  @override
  String forwardSelectedCount(int count) {
    return '$count selecionada(s)';
  }

  @override
  String get archiveForwardedLabel => 'Mensagem(ns) encaminhada(s)';

  @override
  String get archiveLoadFailed => 'Falha ao carregar mensagem encaminhada';

  @override
  String get archiveTapToView => 'Toque para ver detalhes';

  @override
  String archiveViewAll(int count) {
    return 'Ver todas as $count mensagens';
  }
}
