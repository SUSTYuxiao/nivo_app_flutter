import 'package:flutter_test/flutter_test.dart';

import 'package:nivo_app/app.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NivoApp());
    expect(find.text('Nivo App'), findsOneWidget);
  });
}
