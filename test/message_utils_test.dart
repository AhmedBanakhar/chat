import 'package:chat/utils/message_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractMentions', () {
    test('returns mentioned names from text', () {
      final mentions = extractMentions('مرحبا @سارة و@أحمد');
      expect(mentions, ['سارة', 'أحمد']);
    });

    test('ignores non-mentioned text', () {
      final mentions = extractMentions('رسالة عادية');
      expect(mentions, isEmpty);
    });
  });
}
