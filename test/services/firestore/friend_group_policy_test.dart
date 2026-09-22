import 'package:flutter_test/flutter_test.dart';
import 'package:tempo/services/firestore/friend_group_policy.dart';

void main() {
  group('assertMayJoinGroup', () {
    test('allows an accepted friend to be added', () async {
      await expectLater(
        assertMayJoinGroup(
          ownerUid: 'owner',
          memberUid: 'alice',
          isFriend: (a, b) async => true,
        ),
        completes,
      );
    });

    test('rejects a uid that is not an accepted friend', () async {
      await expectLater(
        assertMayJoinGroup(
          ownerUid: 'owner',
          memberUid: 'stranger',
          isFriend: (a, b) async => false,
        ),
        throwsA(isA<NotAFriendException>()),
      );
    });

    test('rejects the owner joining their own group', () async {
      var checked = false;
      await expectLater(
        assertMayJoinGroup(
          ownerUid: 'owner',
          memberUid: 'owner',
          isFriend: (a, b) async {
            checked = true;
            return true;
          },
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(checked, isFalse,
          reason: 'self-membership is rejected without a friendship read');
    });

    test('checks friendship between the owner and the candidate', () async {
      late String checkedA;
      late String checkedB;
      await assertMayJoinGroup(
        ownerUid: 'owner',
        memberUid: 'alice',
        isFriend: (a, b) async {
          checkedA = a;
          checkedB = b;
          return true;
        },
      );

      expect(checkedA, 'owner');
      expect(checkedB, 'alice');
    });

    test('names the rejected uid in the exception message', () async {
      try {
        await assertMayJoinGroup(
          ownerUid: 'owner',
          memberUid: 'stranger',
          isFriend: (a, b) async => false,
        );
        fail('expected NotAFriendException');
      } on NotAFriendException catch (e) {
        expect(e.toString(), contains('stranger'));
      }
    });
  });
}
