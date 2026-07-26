class LicenseModel {
  final String status; // "trial" | "active" | "locked"
  final String tier; // "trial" | "monthly" | "yearly" | "corporate"
  final DateTime? trialEndsAt; // deneme bitiş tarihi
  final DateTime? licenseExpiresAt; // lisans bitiş tarihi
  final int projectCount;
  final List<String> pdfProjects;
  final String? orgId; // kurumsal lisansa bağlıysa organizasyon id'si
  final String? orgRole; // "owner" | "member" | null

  const LicenseModel({
    required this.status,
    required this.tier,
    required this.trialEndsAt,
    required this.licenseExpiresAt,
    required this.projectCount,
    required this.pdfProjects,
    this.orgId,
    this.orgRole,
  });

  factory LicenseModel.fromMap(Map<String, dynamic> map) {
    final trialMs = map['trialEndsAt'];
    final licenseMs = map['licenseExpiresAt'];
    return LicenseModel(
      status: (map['status'] ?? 'trial') as String,
      tier: (map['tier'] ?? 'trial') as String,
      trialEndsAt: trialMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((trialMs as num).toInt()),
      licenseExpiresAt: licenseMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((licenseMs as num).toInt()),
      projectCount: ((map['projectCount'] ?? 0) as num).toInt(),
      pdfProjects: ((map['pdfProjects'] ?? const <dynamic>[]) as List)
          .map((e) => e.toString())
          .toList(),
      orgId: map['orgId'] as String?,
      orgRole: map['orgRole'] as String?,
    );
  }

  /// Kurumsal lisansa bağlı mı?
  bool get isCorporate => orgId != null;

  /// Bu kullanıcı kendi kurumunun sahibi mi?
  bool get isOrgOwner => orgRole == 'owner';

  /// Lisanslı mı?
  bool get isLicensed => status == 'active';

  /// Tamamen kilitli mi?
  bool get isLocked => status == 'locked';

  /// Deneme modunda mı?
  bool get isTrial => status == 'trial';

  /// Denemenin bitmesine kalan gün (negatifse süresi geçmiş).
  int? get trialDaysLeft {
    if (trialEndsAt == null) return null;
    return trialEndsAt!.difference(DateTime.now()).inDays;
  }

  /// Lisansın bitmesine kalan gün.
  int? get licenseDaysLeft {
    if (licenseExpiresAt == null) return null;
    return licenseExpiresAt!.difference(DateTime.now()).inDays;
  }

  /// Aktif lisansın bitiş tarihi — gösterim için.
  DateTime? get activeExpiresAt {
    if (status == 'active') return licenseExpiresAt;
    return null;
  }
}
