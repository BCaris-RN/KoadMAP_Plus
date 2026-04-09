import 'package:flutter_test/flutter_test.dart';
import 'package:koadmap_plus/domain/operator_session.dart';
import 'package:koadmap_plus/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('renders workspace by default in guest mode', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const CodeTreeViewerApp());
    await tester.pumpAndSettle();

    expect(find.text('KoadMAP Plus'), findsOneWidget);
    expect(find.text('Ingest Target'), findsOneWidget);
    expect(
      find.text('Select a folder or enter a GitHub repo.'),
      findsOneWidget,
    );
    expect(find.text('Guest Mode'), findsOneWidget);
  });

  testWidgets(
    'renders workspace with persisted profile when a session is present',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CodeTreeViewerApp(
          initialSession: OperatorSession(
            email: 'operator@example.com',
            fullName: 'Operator One',
            organization: 'KoadMAP',
            marketingOptIn: true,
            analyticsOptIn: true,
            usageOptIn: true,
            createdAtUtc: '2026-04-08T00:00:00.000Z',
            lastAccessedAtUtc: '2026-04-08T00:00:00.000Z',
            loginCount: 1,
            scansRun: 0,
            lastTarget: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('KoadMAP Plus'), findsOneWidget);
      expect(find.text('Ingest Target'), findsOneWidget);
      expect(
        find.text('Select a folder or enter a GitHub repo.'),
        findsOneWidget,
      );
    },
  );
}
