import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storypad/core/services/messenger_service.dart';

void main() {
  testWidgets(
    'showLoading pops the dialog and rethrows when the future fails',
    (tester) async {
      late BuildContext capturedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );

      Object? caught;
      // Attach the error handler immediately so the rethrown error is never
      // unhandled while the dialog is pumping.
      final Future<int?> loadingFuture = MessengerService.of(capturedContext)
          .showLoading<int>(
            debugSource: 'test#fails',
            future: () async => throw const FormatException('malformed file'),
          )
          .then(
            (value) => value,
            onError: (Object e) {
              caught = e;
              return null;
            },
          );

      await tester.pump(); // dialog opens
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      await loadingFuture;

      // The error surfaced to the caller…
      expect(caught, isA<FormatException>());
      // …and the loading dialog is gone — no spinner stuck on screen forever.
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('showLoading completes with the future value on success', (
    tester,
  ) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );

    final loadingFuture = MessengerService.of(capturedContext).showLoading<int>(
      debugSource: 'test#ok',
      future: () async => 42,
    );

    // Dialog open/close animations need frames to complete.
    await tester.pumpAndSettle();
    final result = await loadingFuture;

    expect(result, 42);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
