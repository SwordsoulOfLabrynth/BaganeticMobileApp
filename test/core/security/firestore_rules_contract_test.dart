import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('community totals are server-owned in Firestore rules', () {
    final rules = File('firestore.rules').readAsStringSync();

    expect(rules, contains('isCommunityPostOwnerUpdate'));
    expect(rules, contains('upvoteCount == resource.data.upvoteCount'));
    expect(rules, contains('commentCount == resource.data.commentCount'));
    expect(rules, isNot(contains("hasOnly(['upvoteCount', 'commentCount', 'updatedAt'])")));
  });

  test('trusted functions own community counter updates', () {
    final functions = File('functions/index.js').readAsStringSync();

    expect(functions, contains('incrementCommunityCommentCount'));
    expect(functions, contains('decrementCommunityCommentCount'));
    expect(functions, contains('incrementCommunityVoteCount'));
    expect(functions, contains('decrementCommunityVoteCount'));
  });
}
