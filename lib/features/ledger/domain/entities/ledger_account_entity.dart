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

  /// How much of this account's normal monthly allowance is left — the
  /// figure shown in the cart/checkout ledger toggle and the amount it
  /// actually offsets against an order (see checkout's ledger-balance
  /// toggle, mirroring the wallet-balance toggle). Deliberately based on
  /// [monthlyCreditLimit], not [hardLimit]: hardLimit is a much higher
  /// fraud backstop the backend still separately enforces on any draw
  /// (drawForUser/draw()'s guarded UPDATE), never something offered to the
  /// customer as their "available" balance — showing hardLimit here would
  /// let the toggle silently draw far more than a customer would expect
  /// from a number labelled "available credit".
  double get availableCredit {
    final remaining = monthlyCreditLimit - currentBalance;
    return remaining < 0 ? 0 : remaining;
  }
}
