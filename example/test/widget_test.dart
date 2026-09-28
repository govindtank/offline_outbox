import 'package:flutter_test/flutter_test.dart';
import 'package:offline_outbox_example/main.dart';

void main() {
  testWidgets('Offline outbox example app mounts properly',
      (WidgetTester tester) async {
    await tester.pumpWidget(const OutboxDemoApp());
    await tester.pump();

    expect(find.text('Offline Outbox Engine'), findsOneWidget);
    expect(find.text('Trigger Outbox Actions'), findsOneWidget);
  });
}
