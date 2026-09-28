import 'package:flutter_test/flutter_test.dart';
import 'package:sk_live/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('SkLiveApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: SkLiveApp()));
    expect(find.byType(SkLiveApp), findsOneWidget);
  });
}
