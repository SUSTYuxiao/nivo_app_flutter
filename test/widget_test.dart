import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nivo_app/shared/widgets/loading_overlay.dart';

void main() {
  testWidgets('LoadingOverlay shows indicator when loading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoadingOverlay(
          isLoading: true,
          message: '加载中',
          child: SizedBox(),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('加载中'), findsOneWidget);
  });

  testWidgets('LoadingOverlay hides indicator when not loading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoadingOverlay(
          isLoading: false,
          child: Text('content'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });
}
