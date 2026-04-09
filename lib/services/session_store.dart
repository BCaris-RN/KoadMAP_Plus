import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/operator_session.dart';

class SessionStore {
  const SessionStore();

  static const String _sessionKey = 'koadmap.operator_session';

  Future<OperatorSession?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
      return OperatorSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<OperatorSession> create(AccessDraft draft) async {
    final String now = DateTime.now().toUtc().toIso8601String();
    final OperatorSession existing =
        await load() ??
        OperatorSession(
          email: draft.email,
          fullName: draft.fullName,
          organization: draft.organization,
          marketingOptIn: draft.marketingOptIn,
          analyticsOptIn: draft.analyticsOptIn,
          usageOptIn: draft.usageOptIn,
          createdAtUtc: now,
          lastAccessedAtUtc: now,
          loginCount: 0,
          scansRun: 0,
          lastTarget: null,
        );

    final OperatorSession session = existing.copyWith(
      email: draft.email,
      fullName: draft.fullName,
      organization: draft.organization,
      marketingOptIn: draft.marketingOptIn,
      analyticsOptIn: draft.analyticsOptIn,
      usageOptIn: draft.usageOptIn,
      lastAccessedAtUtc: now,
      loginCount: existing.loginCount + 1,
    );
    await save(session);
    return session;
  }

  Future<OperatorSession> recordScan(
    OperatorSession session, {
    required String target,
  }) async {
    final OperatorSession updated = session.copyWith(
      scansRun: session.scansRun + 1,
      lastTarget: target,
      lastAccessedAtUtc: DateTime.now().toUtc().toIso8601String(),
    );
    await save(updated);
    return updated;
  }

  Future<void> save(OperatorSession session) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
