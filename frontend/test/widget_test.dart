import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go4/main.dart';

void main() {
  testWidgets('Go4App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: Go4App()));
    // App renders without throwing
    expect(find.byType(Go4App), findsOneWidget);
  });
}
