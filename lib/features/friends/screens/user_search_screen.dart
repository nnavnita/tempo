import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/user_model.dart';
import '../../../models/friendship_model.dart';
import '../../../providers/auth_provider.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _ctrl = TextEditingController();
  List<UserModel> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final results =
          await ref.read(userRepositoryProvider).searchByName(query.trim());
      final myUid = ref.read(currentUidProvider);
      setState(() {
        _results = results.where((u) => u.uid != myUid).toList();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search by name...',
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, i) =>
                  _UserResultTile(user: _results[i]),
            ),
    );
  }
}

class _UserResultTile extends ConsumerStatefulWidget {
  const _UserResultTile({required this.user});

  final UserModel user;

  @override
  ConsumerState<_UserResultTile> createState() => _UserResultTileState();
}

class _UserResultTileState extends ConsumerState<_UserResultTile> {
  FriendshipModel? _friendship;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkFriendship();
  }

  Future<void> _checkFriendship() async {
    final myUid = ref.read(currentUidProvider);
    if (myUid == null) return;
    final f = await ref
        .read(friendRepositoryProvider)
        .getFriendship(myUid, widget.user.uid);
    if (mounted) {
      setState(() {
        _friendship = f;
        _checking = false;
      });
    }
  }

  Future<void> _sendRequest() async {
    final myUid = ref.read(currentUidProvider);
    if (myUid == null) return;
    await ref
        .read(friendRepositoryProvider)
        .sendFriendRequest(fromUid: myUid, toUid: widget.user.uid);
    await _checkFriendship();
  }

  @override
  Widget build(BuildContext context) {
    Widget trailing;
    if (_checking) {
      trailing = const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2));
    } else if (_friendship == null) {
      trailing = ElevatedButton(
        onPressed: _sendRequest,
        child: const Text('Add'),
      );
    } else if (_friendship!.isPending) {
      trailing = const Text('Pending',
          style: TextStyle(color: AppColors.onSurfaceVariant));
    } else {
      trailing = const Icon(Icons.check, color: AppColors.secondary);
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: widget.user.photoURL != null
            ? CachedNetworkImageProvider(widget.user.photoURL!)
            : null,
        child: widget.user.photoURL == null
            ? Text(widget.user.displayName[0].toUpperCase())
            : null,
      ),
      title: Text(widget.user.displayName),
      subtitle: Text(widget.user.email),
      trailing: trailing,
    );
  }
}
