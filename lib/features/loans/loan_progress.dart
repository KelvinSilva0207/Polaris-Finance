import '../../data/database/app_database.dart';

/// Fracción del préstamo ya pagada (0 a 1).
double loanProgress(Loan loan) {
  if (loan.principal <= 0) return loan.paidAmount > 0 ? 1 : 0;
  return (loan.paidAmount / loan.principal).clamp(0.0, 1.0);
}

/// Porcentaje entero pagado, listo para mostrar.
int loanProgressPercent(Loan loan) => (loanProgress(loan) * 100).round();

/// Porcentaje con un decimal, para que el avance se vea con precisión
/// (por ejemplo, `75.5%`).
double loanProgressPercentValue(Loan loan) =>
    double.parse((loanProgress(loan) * 100).toStringAsFixed(1));

/// `true` cuando el monto pagado cubre el total del préstamo.
bool isLoanSettled(Loan loan) => loanProgress(loan) >= 0.999;

/// Texto corto: `Liquidado` o `62.5% pagado`.
String loanProgressLabel(Loan loan) => isLoanSettled(loan)
    ? 'Liquidado'
    : '${loanProgressPercentValue(loan).toStringAsFixed(1)}% pagado';
