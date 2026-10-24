import 'dart:async';

import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/privacy/email_privacy_provider.dart';

part 'contacts_provider.g.dart';

// ---------------------------------------------------------------------------
// ContactInfo — minimal user representation for the contacts list
// ---------------------------------------------------------------------------

class ContactInfo {
  const ContactInfo({
    required this.uid,
    required this.name,
    String? email,
    this.isBot,
  }) : email = email ?? '';

  final int uid;
  final String name;
  final String email;
  final bool? isBot;

  // Older servers omit is_bot. Only the name is a stable fallback when
  // email is hidden; an explicit false always takes precedence.
  bool get bot => isBot ?? name.toLowerCase().contains('bot');

  ContactInfo withEmail(String? email) =>
      ContactInfo(uid: uid, name: name, email: email, isBot: isBot);

  factory ContactInfo.fromJson(Map<String, dynamic> j) => ContactInfo(
        uid: (j['uid'] as num).toInt(),
        name: j['name'] as String? ?? 'Unknown',
        email: j['email'] as String?,
        isBot: j['is_bot'] as bool?,
      );
}

// ---------------------------------------------------------------------------
// contactsProvider — awaits live server; falls back to empty list when offline
// ---------------------------------------------------------------------------

@riverpod
class Contacts extends _$Contacts {
  Object _request = Object();
  Object _lifetime = Object();

  @override
  Future<List<ContactInfo>> build() async {
    final lifetime = _lifetime = Object();
    ref.onDispose(() {
      _lifetime = Object();
      _request = Object();
    });
    ref.listen(emailPrivacyProvider, (previous, policy) {
      _request = Object();
      final current = state.valueOrNull;
      if (previous?.session != policy.session) {
        state = const AsyncData([]);
      } else if (current != null && policy.redact) {
        state = AsyncData(_protect(current));
      }
      unawaited(refresh());
    });
    final users = await _fetch(_request = Object());
    if (lifetime != _lifetime) return const [];
    return users ?? state.valueOrNull ?? const [];
  }

  List<ContactInfo> _protect(List<ContactInfo> users) =>
      ref.read(emailPrivacyProvider).redact
          ? users.map((u) => u.withEmail(null)).toList()
          : users;

  Future<void> refresh() async {
    final request = _request = Object();
    final users = await _fetch(request);
    if (request == _request && users != null) state = AsyncData(users);
  }

  Future<List<ContactInfo>?> _fetch(Object request) async {
    final policy = ref.read(emailPrivacyProvider);
    if (policy.accountId == null) return const [];
    final dio = ref.read(dioProvider);
    try {
      final response = await dio.get('/api/user');
      if (request != _request) return null;
      if (ref.read(emailPrivacyProvider).revision != policy.revision)
        return null;
      final users = (response.data as List)
          .map((u) => ContactInfo.fromJson(Map<String, dynamic>.from(u as Map)))
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return _protect(users);
    } on DioException {
      // Retain names/range during an outage. The privacy listener already
      // removed emails synchronously, independently of this request's result.
    }
    return null;
  }

  void applyUsers(List<Map<String, dynamic>> users, {bool partial = false}) {
    final current = state.valueOrNull;
    if (current == null || current.isEmpty) return;
    final updates = {for (final u in users) (u['uid'] as num).toInt(): u};
    _request = Object();
    state = AsyncData(_protect([
      for (final contact in current)
        if (updates[contact.uid] case final update?)
          ContactInfo.fromJson({
            'uid': contact.uid,
            'name': contact.name,
            'email': contact.email,
            'is_bot': contact.isBot,
            for (final entry in update.entries)
              if (!partial || entry.value != null) entry.key: entry.value,
          })
        else
          contact,
    ]));
  }
}
