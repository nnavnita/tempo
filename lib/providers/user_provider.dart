import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/providers/firebase_providers.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';

/// Watches the current user's Firestore document.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const Stream.empty();
  return ref.watch(userRepositoryProvider).watchUser(uid);
});
