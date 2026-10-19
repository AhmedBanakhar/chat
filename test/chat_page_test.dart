import 'package:chat/pages/chat_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats a Firestore timestamp into a readable clock time', () {
    final timestamp = Timestamp.fromDate(DateTime(2024, 6, 1, 14, 30));

    expect(formatMessageTime(timestamp), '14:30');
  });
}
