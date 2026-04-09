import 'package:flutter_test/flutter_test.dart';
import 'package:koadmap_plus/domain/operator_session.dart';
import 'package:koadmap_plus/services/session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('creates, persists, and updates operator session', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    const SessionStore store = SessionStore();

    final OperatorSession created = await store.create(
      const AccessDraft(
        email: 'operator@example.com',
        fullName: 'Operator One',
        organization: 'KoadMAP',
        marketingOptIn: true,
        analyticsOptIn: true,
        usageOptIn: false,
      ),
    );

    expect(created.email, 'operator@example.com');
    expect(created.loginCount, 1);
    expect(created.scansRun, 0);
    expect(created.usageOptIn, isFalse);

    final OperatorSession? loaded = await store.load();
    expect(loaded, isNotNull);
    expect(loaded!.organization, 'KoadMAP');

    final OperatorSession updated = await store.recordScan(
      loaded,
      target: 'BCaris-RN/KoadMAP_Plus',
    );

    expect(updated.scansRun, 1);
    expect(updated.lastTarget, 'BCaris-RN/KoadMAP_Plus');

    final OperatorSession? reloaded = await store.load();
    expect(reloaded, isNotNull);
    expect(reloaded!.scansRun, 1);
    expect(reloaded.lastTarget, 'BCaris-RN/KoadMAP_Plus');
  });
}
