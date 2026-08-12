import 'package:flutter_test/flutter_test.dart';

import 'package:xowcase/main.dart';

void main() {
  testWidgets('XowCase app boots to capture screen', (WidgetTester tester) async {
    await tester.pumpWidget(const XowCaseApp());
    await tester.pump();

    expect(find.text('Select Source'), findsOneWidget);
  });
}
