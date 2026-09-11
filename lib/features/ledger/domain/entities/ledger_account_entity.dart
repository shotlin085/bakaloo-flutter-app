class LedgerAccountEntity {
  const LedgerAccountEntity({
    required this.id,
    required this.status,
    required this.currentBalance,
    required this.monthlyCreditLimit,
    required this.hardLimit,
    required this.billingDay,
  });

  final String id;
  final String status; // 'ACTIVE' | 'SUSPENDED' | 'CLOSED'
  final double currentBalance;
  final double monthlyCreditLimit;
  final double hardLimit;
  final int billingDay;

  bool get isActive => status == 'ACTIVE';

  double get availableCredit {
    final remaining = hardLimit - currentBalance;
    return remaining < 0 ? 0 : remaining;
  }
}
