class OperatorSession {
  const OperatorSession({
    required this.email,
    required this.fullName,
    required this.organization,
    required this.marketingOptIn,
    required this.analyticsOptIn,
    required this.usageOptIn,
    required this.createdAtUtc,
    required this.lastAccessedAtUtc,
    required this.loginCount,
    required this.scansRun,
    required this.lastTarget,
  });

  final String email;
  final String fullName;
  final String organization;
  final bool marketingOptIn;
  final bool analyticsOptIn;
  final bool usageOptIn;
  final String createdAtUtc;
  final String lastAccessedAtUtc;
  final int loginCount;
  final int scansRun;
  final String? lastTarget;

  String get displayName {
    if (fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    return email;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'email': email,
      'fullName': fullName,
      'organization': organization,
      'marketingOptIn': marketingOptIn,
      'analyticsOptIn': analyticsOptIn,
      'usageOptIn': usageOptIn,
      'createdAtUtc': createdAtUtc,
      'lastAccessedAtUtc': lastAccessedAtUtc,
      'loginCount': loginCount,
      'scansRun': scansRun,
      'lastTarget': lastTarget,
    };
  }

  factory OperatorSession.fromJson(Map<String, dynamic> json) {
    return OperatorSession(
      email: json['email'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      marketingOptIn: json['marketingOptIn'] as bool? ?? false,
      analyticsOptIn: json['analyticsOptIn'] as bool? ?? false,
      usageOptIn: json['usageOptIn'] as bool? ?? false,
      createdAtUtc: json['createdAtUtc'] as String? ?? '',
      lastAccessedAtUtc: json['lastAccessedAtUtc'] as String? ?? '',
      loginCount: (json['loginCount'] as num?)?.toInt() ?? 1,
      scansRun: (json['scansRun'] as num?)?.toInt() ?? 0,
      lastTarget: json['lastTarget'] as String?,
    );
  }

  OperatorSession copyWith({
    String? email,
    String? fullName,
    String? organization,
    bool? marketingOptIn,
    bool? analyticsOptIn,
    bool? usageOptIn,
    String? createdAtUtc,
    String? lastAccessedAtUtc,
    int? loginCount,
    int? scansRun,
    String? lastTarget,
  }) {
    return OperatorSession(
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      organization: organization ?? this.organization,
      marketingOptIn: marketingOptIn ?? this.marketingOptIn,
      analyticsOptIn: analyticsOptIn ?? this.analyticsOptIn,
      usageOptIn: usageOptIn ?? this.usageOptIn,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      lastAccessedAtUtc: lastAccessedAtUtc ?? this.lastAccessedAtUtc,
      loginCount: loginCount ?? this.loginCount,
      scansRun: scansRun ?? this.scansRun,
      lastTarget: lastTarget ?? this.lastTarget,
    );
  }
}

class AccessDraft {
  const AccessDraft({
    required this.email,
    required this.fullName,
    required this.organization,
    required this.marketingOptIn,
    required this.analyticsOptIn,
    required this.usageOptIn,
  });

  final String email;
  final String fullName;
  final String organization;
  final bool marketingOptIn;
  final bool analyticsOptIn;
  final bool usageOptIn;
}
