import '../../data/database/app_database.dart';

/// Fracción del préstamo ya pagada (0 a 1).
double loanProgress(Loan loan) {
  if (loan.principal <= 0) return loan.paidAmount > 0 ? 1 : 0;
  return (loan.paidAmount / loan.principal).clamp(0.0, 1.0);
}

/// Porcentaje entero pagado, listo para mostrar.
int loanProgressPercent(Loan loan) => (loanProgress(loan) * 100).round();

/// `true` cuando el monto pagado cubre el total del préstamo.
bool isLoanSettled(Loan loan) => loanProgress(loan) >= 0.999;

/// Texto corto: `Liquidado` o `62% pagado`.
String loanProgressLabel(Loan loan) =>
    isLoanSettled(loan) ? 'Liquidado' : '${loanProgressPercent(loan)}% pagado';
