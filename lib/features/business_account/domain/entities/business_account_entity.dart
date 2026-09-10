class BusinessAccountEntity {
  const BusinessAccountEntity({
    required this.id,
    required this.companyName,
    required this.gstNumber,
    required this.status,
    required this.b2bEnabled,
    required this.submittedAt,
    this.rejectionReason,
    this.reviewedAt,
  });

  final String id;
  final String companyName;
  final String gstNumber;
  final String status; // 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED'
  final bool b2bEnabled;
  final String? rejectionReason;
  final DateTime submittedAt;
  final DateTime? reviewedAt;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';
  bool get isSuspended => status == 'SUSPENDED';

  /// A rejected application can be corrected and resubmitted.
  bool get canReapply => isRejected;
}
