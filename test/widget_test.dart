import 'package:chat/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts with login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ScholarChat());

    expect(find.text('Scholar Chat'), findsOneWidget);
    expect(find.text('Login to your account'), findsOneWidget);
  });
}
