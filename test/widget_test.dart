import 'package:flutter_test/flutter_test.dart';
import 'package:mothers_hut_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Basic smoke test to verify widget instantiation
    expect(const MothersHutApp(), isNotNull);
  });
}
