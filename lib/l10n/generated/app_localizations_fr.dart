import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppL10nFr extends AppL10n {
  AppL10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'VoceChat';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionOpen => 'Ouvrir';

  @override
  String get actionChange => 'Changer';

  @override
  String get actionContact => 'Contacter';

  @override
  String get actionEdit => 'Modifier';

  @override
  String get actionSend => 'Envoyer';

  @override
  String get actionSearch => 'Rechercher';

  @override
  String get actionMore => 'Plus';

  @override
  String get actionRetry => 'Réessayer';

  @override
  String get chatToolPin => 'Épinglé';

  @override
  String get chatActionReact => 'Ajouter une réaction';

  @override
  String get chatActionReply => 'Répondre';

  @override
  String get chatActionEdit => 'Modifier';

  @override
  String get chatActionDelete => 'Supprimer';

  @override
  String get chatEditMarker => '(modifié)';

  @override
  String chatReplyingTo(String name) {
    return 'Réponse à $name';
  }

  @override
  String get chatDeleteConfirmTitle => 'Supprimer le message ?';

  @override
  String get chatDeleteConfirmBody => 'Cette action est irréversible.';

  @override
  String get chatEditCancel => 'Annuler';

  @override
  String get chatEditSave => 'Enregistrer';

  @override
  String get chatFileDetailsTitle => 'Détails du fichier';

  @override
  String get chatFileNameLabel => 'Nom';

  @override
  String chatEditFailed(String error) {
    return 'Modification échouée : $error';
  }

  @override
  String chatDeleteFailed(String error) {
    return 'Suppression échouée : $error';
  }

  @override
  String chatReplyFailed(String error) {
    return 'Réponse échouée : $error';
  }

  @override
  String get chatReplyDeleted => 'Ce message a été supprimé.';

  @override
  String get chatReplyVoiceMessage => '[Message vocal]';

  @override
  String get chatToolSaved => 'Enregistré';

  @override
  String get chatToolMembers => 'Membres';

  @override
  String get chatToolEmpty => 'Aucun contenu pour le moment.';

  @override
  String get chatToolPinEmpty => 'Aucun message épinglé.';

  @override
  String get chatToolSavedEmpty => 'Aucun message enregistré.';

  @override
  String get chatToolMembersEmpty => 'Aucun membre.';

  @override
  String get chatToolUnpin => 'Désépingler';

  @override
  String get chatToolRemoveFav => 'Retirer';

  @override
  String get chatToolPinFail => 'Épinglage échoué';

  @override
  String get chatToolUnpinFail => 'Désépinglage échoué';

  @override
  String get chatToolSaveFail => 'Enregistrement échoué';

  @override
  String get chatToolRemoveFavFail => 'Suppression échouée';

  @override
  String get chatToolSavedAdded => 'Enregistré';

  @override
  String get chatToolPinAdded => 'Épinglé';

  @override
  String get chatToolUnpinned => 'Désépinglé';

  @override
  String get chatSearchHint => 'Rechercher des messages';

  @override
  String get chatSearchEmpty => 'Aucun message correspondant.';

  @override
  String get navChats => 'Discussions';

  @override
  String get navContacts => 'Contacts';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get navSaved => 'Enregistrés';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get actionBack => 'Retour';

  @override
  String get actionClose => 'Fermer';

  @override
  String get memberRoleOwner => 'Propriétaire';

  @override
  String get tooltipDownload => 'Télécharger';

  @override
  String get tooltipZoomIn => 'Zoomer';

  @override
  String get tooltipZoomOut => 'Dézoomer';

  @override
  String get tooltipFullscreen => 'Plein écran';

  @override
  String get tooltipExitFullscreen => 'Quitter le plein écran';

  @override
  String get tooltipShowPassword => 'Afficher le mot de passe';

  @override
  String get tooltipHidePassword => 'Masquer le mot de passe';

  @override
  String get reactionDeletedUser => 'Utilisateur supprimé';

  @override
  String reactionTooltipMany(String names, int count, String emoji) {
    return '$names et $count autres ont réagi avec $emoji';
  }

  @override
  String reactionTooltipFew(String names, String emoji) {
    return '$names a réagi avec $emoji';
  }

  @override
  String get expiredImageTitle => 'Image introuvable';

  @override
  String get expiredImageBody => 'L\'image a expiré ou a été supprimée';

  @override
  String get expiredVideoTitle => 'Vidéo introuvable';

  @override
  String get expiredVideoBody => 'La vidéo a expiré ou a été supprimée';

  @override
  String get expiredAudioTitle => 'Audio introuvable';

  @override
  String get expiredAudioBody => 'L\'audio a expiré ou a été supprimé';

  @override
  String get expiredFileTitle => 'Fichier introuvable';

  @override
  String get expiredFileBody => 'Le fichier a expiré ou a été supprimé';

  @override
  String get featureUnavailable => 'Cette fonctionnalité n\'est pas encore disponible';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsGroupGeneral => 'général';

  @override
  String get settingsGroupAbout => 'à propos';

  @override
  String get settingsMyAccount => 'Mon compte';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsStorage => 'Stockage et données';

  @override
  String get settingsAbout => 'À propos';

  @override
  String get settingsLogout => 'Se déconnecter';

  @override
  String get settingsLogoutConfirmTitle => 'Se déconnecter ?';

  @override
  String get settingsLogoutConfirmContent => 'Vous devrez vous reconnecter pour accéder à ce serveur.';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountUsername => 'Nom d\'utilisateur';

  @override
  String get accountPassword => 'Mot de passe';

  @override
  String get accountPasswordMasked => '*********';

  @override
  String get notificationsPush => 'Notifications push';

  @override
  String get notificationsPushSubtitle => 'Soyez informé des nouveaux messages et des mentions.';

  @override
  String get notificationsSound => 'Sons de notification';

  @override
  String get notificationsSoundSubtitle => 'Jouer un son à la réception d\'un message.';

  @override
  String get notificationsMentionsOnly => 'Mentions uniquement';

  @override
  String get notificationsMentionsOnlySubtitle => 'Ne notifier que pour les @mentions.';

  @override
  String get appearanceTheme => 'THÈME';

  @override
  String get appearanceLight => 'Clair';

  @override
  String get appearanceSystem => 'Système par défaut';

  @override
  String get appearanceDark => 'Sombre';

  @override
  String get appearanceLanguage => 'LANGUE';

  @override
  String get languageSystem => 'Système par défaut';

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
  String get storageUsage => 'Utilisation du stockage';

  @override
  String get storageAutoDownload => 'Téléchargement auto des médias';

  @override
  String get storageWifiOnly => 'Wi-Fi uniquement';

  @override
  String get storageClearCache => 'Vider le cache';

  @override
  String get storageClearCacheConfirmTitle => 'Vider le cache ?';

  @override
  String get storageClearCacheConfirmBody => 'Cela supprime les messages et images mis en cache localement. Ils seront retéléchargés si nécessaire.';

  @override
  String get storageClearCacheConfirm => 'Vider';

  @override
  String get storageCacheCleared => 'Cache vidé';

  @override
  String get aboutAppVersion => 'Version de l\'application';

  @override
  String get aboutWebsite => 'Site web';

  @override
  String get aboutReportBug => 'Signaler un bug';

  @override
  String get aboutReportBugSubtitle => 'Aidez-nous à améliorer VoceChat.';

  @override
  String get loginWelcomeBack => 'Bon retour';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginEmailRequired => 'L\'email est requis';

  @override
  String get loginEmailInvalid => 'Saisissez une adresse email valide';

  @override
  String get loginPassword => 'Mot de passe';

  @override
  String get loginPasswordRequired => 'Le mot de passe est requis';

  @override
  String get loginPasswordTooShort => 'Le mot de passe doit contenir au moins 6 caractères';

  @override
  String get loginForgotPassword => 'Mot de passe oublié ?';

  @override
  String get loginSignIn => 'Se connecter';

  @override
  String get loginMagicLink => 'Utiliser un lien magique';

  @override
  String get loginPasskey => 'Se connecter avec une clé d\'accès';

  @override
  String get loginSwitchServer => 'Changer de serveur';

  @override
  String get loginNoAccount => 'Vous n\'avez pas de compte ? ';

  @override
  String get loginSignUp => 'S\'inscrire';

  @override
  String get loginErrorInvalidCredentials => 'Email ou mot de passe incorrect';

  @override
  String get loginErrorAccountFrozen => 'Ce compte a été gelé. Contactez votre administrateur.';

  @override
  String get loginErrorNotInvited => 'Aucun compte associé trouvé. Demandez un lien d\'invitation à un administrateur.';

  @override
  String get loginErrorMethodNotSupported => 'Cette méthode de connexion n\'est pas prise en charge par le serveur.';

  @override
  String get loginErrorCannotReachServer => 'Impossible d\'atteindre le serveur. Vérifiez votre réseau ou l\'URL du serveur.';

  @override
  String get registerTitle => 'Créer un compte';

  @override
  String get registerHeader => 'Rejoignez la conversation';

  @override
  String get registerSubtitle => 'Renseignez vos informations pour commencer.';

  @override
  String get registerName => 'Nom complet';

  @override
  String get registerNameRequired => 'Le nom est requis';

  @override
  String get registerNameTooShort => 'Le nom doit contenir au moins 2 caractères';

  @override
  String get registerEmailRequired => 'L\'email est requis';

  @override
  String get registerEmailInvalid => 'Saisissez un email valide';

  @override
  String get registerPasswordRequired => 'Le mot de passe est requis';

  @override
  String get registerPasswordTooShort => 'Au moins 6 caractères requis';

  @override
  String get registerConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get registerConfirmRequired => 'Veuillez confirmer votre mot de passe';

  @override
  String get registerConfirmMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get registerCreate => 'Créer un compte';

  @override
  String get registerMagicLink => 'Envoyer un lien d\'invitation à la place';

  @override
  String get registerEmailFirst => 'Veuillez d\'abord saisir votre email';

  @override
  String get registerInvitationSent => 'Lien d\'invitation envoyé';

  @override
  String get registerHaveAccount => 'Vous avez déjà un compte ? ';

  @override
  String get serverPickerTitle => 'Sélectionner un serveur';

  @override
  String get serverPickerEmptyTitle => 'Connectez-vous à un serveur VoceChat';

  @override
  String get serverPickerEmptySubtitle => 'Ajoutez un serveur pour commencer à discuter avec votre équipe.';

  @override
  String get serverPickerAddFirst => 'Ajouter votre premier serveur';

  @override
  String get serverPickerAdd => 'Ajouter un serveur';

  @override
  String get serverPickerContinue => 'Continuer';

  @override
  String get serverAddTitle => 'Ajouter un serveur';

  @override
  String get serverUrl => 'URL du serveur';

  @override
  String get serverUrlHint => 'https://chat.example.com';

  @override
  String get serverUrlRequired => 'L\'URL est requise';

  @override
  String get serverUrlMustHttps => 'Doit commencer par https://';

  @override
  String get serverUrlHttpNotAllowed => 'Seul https:// est autorisé (http non permis pour les serveurs distants)';

  @override
  String get serverAlias => 'Alias (facultatif)';

  @override
  String get serverAliasHint => 'Mon serveur professionnel';

  @override
  String get serverTesting => 'Test en cours…';

  @override
  String get serverTestConnection => 'Tester la connexion';

  @override
  String get serverTestSuccess => 'Connexion réussie';

  @override
  String get serverTestFailed => 'Impossible de se connecter au serveur';

  @override
  String get serverSave => 'Enregistrer et continuer';

  @override
  String get chatListSearch => 'Rechercher...';

  @override
  String get chatListNewChat => 'Nouvelle discussion';

  @override
  String get chatListLoading => 'Chargement des discussions…';

  @override
  String get chatListUpdating => 'Mise à jour…';

  @override
  String get chatListEmpty => 'Aucune conversation pour le moment';

  @override
  String chatListNoResults(String query) {
    return 'Aucun résultat pour « $query »';
  }

  @override
  String get chatListSelectTitle => 'Sélectionnez une conversation';

  @override
  String get chatListSelectSubtitle => 'Choisissez une discussion dans le panneau de gauche pour envoyer un message';

  @override
  String get chatListPin => 'Épingler en haut';

  @override
  String get chatListUnpin => 'Désépingler';

  @override
  String chatListPinFailed(String error) {
    return 'Épinglage échoué : $error';
  }

  @override
  String chatListUnpinFailed(String error) {
    return 'Désépinglage échoué : $error';
  }

  @override
  String get timeJustNow => 'à l\'instant';

  @override
  String timeMinutesAgo(int count) {
    return 'il y a $count min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'il y a $count j';
  }

  @override
  String get contactsSearch => 'Rechercher...';

  @override
  String get contactsAdd => 'Ajouter un contact';

  @override
  String get contactsLoading => 'Chargement des contacts…';

  @override
  String get contactsEmpty => 'Aucun contact trouvé';

  @override
  String contactsSectionBot(int count) {
    return 'BOT - $count';
  }

  @override
  String contactsSectionContact(int count) {
    return 'CONTACT - $count';
  }

  @override
  String get contactsSelectTitle => 'Sélectionnez un contact';

  @override
  String get contactsSelectSubtitle => 'Choisissez une personne dans la liste pour voir son profil';

  @override
  String get contactsMessage => 'Message';

  @override
  String get contactsCall => 'Appeler';

  @override
  String get chatLoadingMessages => 'Chargement des messages…';

  @override
  String get chatStatusOnline => 'En ligne';

  @override
  String get chatStatusOffline => 'Hors ligne';

  @override
  String get chatGroupIntro => 'Présentez-vous à la communauté !';

  @override
  String get chatEmpty => 'Aucun message pour le moment';

  @override
  String chatSendFailed(String error) {
    return 'Envoi échoué : $error';
  }

  @override
  String chatMessagePlaceholderChannel(String name) {
    return 'Message #$name';
  }

  @override
  String chatMessagePlaceholderUser(String name) {
    return 'Message à $name';
  }

  @override
  String get chatPinned => 'épinglé';

  @override
  String get chatUnsupported => '[message non pris en charge]';

  @override
  String get chatMarkdown => 'Markdown';

  @override
  String get chatAttach => 'Joindre';

  @override
  String get chatVoiceMessage => 'Message vocal';

  @override
  String get chatVideoMessage => 'Message vidéo';

  @override
  String get chatVoiceRecording => 'Enregistrement du message vocal';

  @override
  String get chatVoiceRecordingCancel => 'Annuler';

  @override
  String get chatVoiceRecordingSend => 'Envoyer';

  @override
  String get chatRecordingPermissionDenied => 'Permission refusée — activez l\'accès au micro/caméra dans les paramètres système';

  @override
  String chatDropOverlayTitle(String name) {
    return 'Envoyer à $name';
  }

  @override
  String get chatDropOverlayHint => 'Déposez des fichiers ici pour les envoyer';

  @override
  String get chatEmoji => 'Emoji';

  @override
  String chatUserFallback(int uid) {
    return 'Utilisateur $uid';
  }

  @override
  String chatGroupFallback(int gid) {
    return 'Groupe $gid';
  }

  @override
  String get previewFile => '[Fichier]';

  @override
  String get previewVoice => '[Vocal]';

  @override
  String get previewArchive => '[Archive]';

  @override
  String get previewImage => '[Image]';

  @override
  String get previewReaction => '[Réaction]';

  @override
  String errorPrefix(String message) {
    return 'Erreur : $message';
  }

  @override
  String get errorRequestFailed => 'La requête a échoué';

  @override
  String get authKickedFromOtherDevice => 'Déconnecté : votre compte vient de se connecter sur un autre appareil.';

  @override
  String get authAccountDeleted => 'Votre compte a été supprimé.';

  @override
  String get authSessionEnded => 'Votre session a expiré. Veuillez vous reconnecter.';

  @override
  String get chatListMarkRead => 'Marquer comme lu';

  @override
  String get chatListMute => 'Muet';

  @override
  String get chatListUnmute => 'Réactiver le son';

  @override
  String get chatListHide => 'Masquer';

  @override
  String get chatListLeave => 'Quitter le canal';

  @override
  String get chatListMarkReadDone => 'Marqué comme lu';

  @override
  String get chatListMuteDone => 'Muet activé';

  @override
  String get chatListUnmuteDone => 'Muet désactivé';

  @override
  String get chatListHideDone => 'Masqué';

  @override
  String get chatListLeaveDone => 'Canal quitté';

  @override
  String chatListLeaveFailed(String error) {
    return 'Échec pour quitter le canal : $error';
  }

  @override
  String chatListMuteFailed(String error) {
    return 'Échec de l\'opération : $error';
  }

  @override
  String get chatListMarkReadFailed => 'Échec du marquage comme lu';

  @override
  String get createChannelTitle => 'Nouveau canal';

  @override
  String get createChannelNameLabel => 'Nom du canal';

  @override
  String get channelPublicLabel => 'Canal public';

  @override
  String get createChannelPublicAdminOnly => 'Seuls les administrateurs peuvent créer des canaux publics';

  @override
  String get createChannelSubmit => 'Créer';

  @override
  String get createChannelNameRequired => 'Veuillez saisir un nom de canal';

  @override
  String get createChannelFailed => 'Échec de la création du canal';

  @override
  String get channelSettingsTitle => 'Paramètres du canal';

  @override
  String get channelUpdated => 'Canal mis à jour';

  @override
  String get avatarUpdated => 'Avatar mis à jour';

  @override
  String get channelVisibilityChanged => 'Visibilité modifiée';

  @override
  String get inviteLinkCopied => 'Lien copié';

  @override
  String get channelOverview => 'Aperçu';

  @override
  String get channelNameLabel => 'Nom';

  @override
  String get channelDescriptionLabel => 'Description';

  @override
  String get channelSaveChanges => 'Enregistrer les modifications';

  @override
  String get channelAddMember => 'Ajouter un membre';

  @override
  String get channelInviteLinkSection => 'Lien d\'invitation';

  @override
  String get channelGenerateInviteLink => 'Générer un lien d\'invitation';

  @override
  String get channelMuteLabel => 'Rendre le canal muet';

  @override
  String get channelLeaveConfirmBody => 'Voulez-vous vraiment quitter ce canal ?';

  @override
  String get channelDeleteTitle => 'Supprimer le canal';

  @override
  String get channelDeleteConfirmBody => 'Cela supprimera définitivement le canal pour tous les membres. Cette action est irréversible.';

  @override
  String get actionLeave => 'Quitter';

  @override
  String get accountEditNameTitle => 'Modifier le nom';

  @override
  String get accountNameLabel => 'Nom';

  @override
  String get accountNameUpdated => 'Nom mis à jour';

  @override
  String get accountChangePasswordTitle => 'Changer le mot de passe';

  @override
  String get accountCurrentPasswordLabel => 'Mot de passe actuel';

  @override
  String get accountNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get accountPasswordChanged => 'Mot de passe modifié';

  @override
  String get chatActionCopy => 'Copier';

  @override
  String get chatActionForward => 'Transférer';

  @override
  String get chatActionSelect => 'Sélectionner';

  @override
  String get chatCopiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get chatForwardedMessagePreview => '[Message transféré]';

  @override
  String get chatAutoDeleteTitle => 'Suppression automatique des messages';

  @override
  String chatExpiresTooltip(String duration) {
    return 'Disparaît $duration après l\'envoi';
  }

  @override
  String get chatAutoDeleteOff => 'Désactivé';

  @override
  String get chatAutoDelete5Min => '5 minutes';

  @override
  String get chatAutoDelete10Min => '10 minutes';

  @override
  String get chatAutoDelete1Hour => '1 heure';

  @override
  String get chatAutoDelete1Day => '1 jour';

  @override
  String get chatAutoDelete1Week => '1 semaine';

  @override
  String get chatAutoDeleteSaved => 'Enregistré';

  @override
  String get chatAutoDeleteSaveFailed => 'Enregistrement échoué';

  @override
  String get forwardSheetTitle => 'Transférer à...';

  @override
  String get forwardMessageSent => 'Message transféré';

  @override
  String forwardFailed(String error) {
    return 'Transfert échoué : $error';
  }

  @override
  String get forwardNoConversations => 'Aucune conversation';

  @override
  String forwardSelectedCount(int count) {
    return '$count sélectionné(s)';
  }

  @override
  String get archiveForwardedLabel => 'Message(s) transféré(s)';

  @override
  String get archiveLoadFailed => 'Échec du chargement du message transféré';

  @override
  String get archiveTapToView => 'Appuyez pour voir les détails';

  @override
  String archiveViewAll(int count) {
    return 'Voir les $count messages';
  }
}
