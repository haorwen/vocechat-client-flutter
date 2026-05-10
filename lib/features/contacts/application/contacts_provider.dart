import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/dio_client.dart';

part 'contacts_provider.g.dart';

// ---------------------------------------------------------------------------
// ContactInfo — minimal user representation for the contacts list
// ---------------------------------------------------------------------------

class ContactInfo {
  const ContactInfo({
    required this.uid,
    required this.name,
    String? email,
  }) : email = email ?? '';

  final int uid;
  final String name;
  final String email;

  factory ContactInfo.fromJson(Map<String, dynamic> j) => ContactInfo(
        uid: (j['uid'] as num).toInt(),
        name: j['name'] as String? ?? 'Unknown',
        email: j['email'] as String?,
      );
}

// ---------------------------------------------------------------------------
// contactsProvider — awaits live server; falls back to empty list when offline
// ---------------------------------------------------------------------------

@riverpod
Future<List<ContactInfo>> contacts(Ref ref) async {
  final dio = ref.watch(dioProvider);

  try {
    final resp = await dio.get('/api/user');
    final list = (resp.data as List<dynamic>).cast<Map<String, dynamic>>();
    return list.map(ContactInfo.fromJson).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  } on DioException {
    // awaits live server; falls back to empty list when offline
    return [];
  }
}
