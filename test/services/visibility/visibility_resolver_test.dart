import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/services/visibility/visibility_resolver.dart';

void main() {
  group('expandVisibility', () {
    test('expands an included group into its member uids', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        includeGroupIds: ['g1'],
        groupMembers: {
          'g1': ['alice', 'bob'],
        },
      );

      expect(result.visibleUids, ['alice', 'bob']);
      expect(result.excludeUids, isEmpty);
    });

    test('merges individually included friends with group members', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        includeGroupIds: ['g1'],
        includeFriendUids: ['carol'],
        groupMembers: {
          'g1': ['alice'],
        },
      );

      expect(result.visibleUids, ['alice', 'carol']);
    });

    test('dedupes a uid that belongs to two included groups', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        includeGroupIds: ['g1', 'g2'],
        groupMembers: {
          'g1': ['alice', 'bob'],
          'g2': ['bob', 'carol'],
        },
      );

      expect(result.visibleUids, ['alice', 'bob', 'carol']);
    });

    test('ignores a group id with no matching group', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        includeGroupIds: ['g1', 'deleted-group'],
        groupMembers: {
          'g1': ['alice'],
        },
      );

      expect(result.visibleUids, ['alice']);
    });

    test('removes an individually excluded friend from visibleUids', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        includeGroupIds: ['g1'],
        excludeFriendUids: ['bob'],
        groupMembers: {
          'g1': ['alice', 'bob'],
        },
      );

      expect(result.visibleUids, ['alice']);
      expect(result.excludeUids, ['bob']);
    });

    test('removes members of an excluded group from visibleUids', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        includeGroupIds: ['g1'],
        excludeGroupIds: ['g2'],
        groupMembers: {
          'g1': ['alice', 'bob', 'carol'],
          'g2': ['bob', 'carol'],
        },
      );

      expect(result.visibleUids, ['alice']);
      expect(result.excludeUids, ['bob', 'carol']);
    });

    test('exclusion wins when a uid is both included and excluded', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        includeFriendUids: ['alice'],
        excludeFriendUids: ['alice'],
      );

      expect(result.visibleUids, isEmpty);
      expect(result.excludeUids, ['alice']);
    });

    test('never lists the owner in visibleUids', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        includeGroupIds: ['g1'],
        includeFriendUids: ['owner'],
        groupMembers: {
          'g1': ['owner', 'alice'],
        },
      );

      expect(result.visibleUids, ['alice']);
    });

    test('never lists the owner in excludeUids', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        excludeGroupIds: ['g1'],
        excludeFriendUids: ['owner'],
        groupMembers: {
          'g1': ['owner', 'bob'],
        },
      );

      expect(result.excludeUids, ['bob']);
    });

    test('returns empty sets when nothing is targeted', () {
      final result = expandVisibility(ownerUid: 'owner');

      expect(result.visibleUids, isEmpty);
      expect(result.excludeUids, isEmpty);
    });

    test('orders both sets so repeated writes produce identical documents', () {
      final result = expandVisibility(
        ownerUid: 'owner',
        includeFriendUids: ['zoe', 'alice', 'mike'],
        excludeFriendUids: ['yan', 'bob'],
      );

      expect(result.visibleUids, ['alice', 'mike', 'zoe']);
      expect(result.excludeUids, ['bob', 'yan']);
    });
  });

  group('VisibilityResolver', () {
    test('loads referenced groups and expands them into uid sets', () async {
      final resolver = VisibilityResolver(
        loadGroupMembers: (groupIds) async => {
          'g1': ['alice', 'bob'],
        },
      );

      final result = await resolver.resolve(
        ownerUid: 'owner',
        includeGroupIds: ['g1'],
        excludeFriendUids: ['bob'],
      );

      expect(result.visibleUids, ['alice']);
      expect(result.excludeUids, ['bob']);
    });

    test('requests every referenced group exactly once', () async {
      final requested = <List<String>>[];
      final resolver = VisibilityResolver(
        loadGroupMembers: (groupIds) async {
          requested.add(groupIds);
          return const {};
        },
      );

      await resolver.resolve(
        ownerUid: 'owner',
        includeGroupIds: ['g1', 'g2'],
        excludeGroupIds: ['g2', 'g3'],
      );

      expect(requested, hasLength(1));
      expect(requested.single..sort(), ['g1', 'g2', 'g3']);
    });

    test('skips the group load entirely when no group is targeted', () async {
      var called = false;
      final resolver = VisibilityResolver(
        loadGroupMembers: (groupIds) async {
          called = true;
          return const {};
        },
      );

      final result = await resolver.resolve(
        ownerUid: 'owner',
        includeFriendUids: ['alice'],
      );

      expect(called, isFalse);
      expect(result.visibleUids, ['alice']);
    });
  });
}
