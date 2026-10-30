import 'package:flutter_test/flutter_test.dart';
import 'package:dream_community_app/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const DreamApp(hasSeenOnboarding: false));
    expect(find.byType(DreamApp), findsOneWidget);
  });
}
