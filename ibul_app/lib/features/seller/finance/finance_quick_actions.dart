class FinanceQuickActionEvent {
  const FinanceQuickActionEvent({
    required this.id,
    required this.action,
    this.payload = const <String, dynamic>{},
  });

  final int id;
  final String action;
  final Map<String, dynamic> payload;
}

abstract final class FinanceQuickActions {
  static const incomeAdd = 'income.add';
  static const incomePending = 'income.pending';
  static const incomeReset = 'income.reset';

  static const expenseAdd = 'expense.add';
  static const expensePending = 'expense.pending';
  static const expenseOverdue = 'expense.overdue';
  static const expenseAddPayment = 'expense.add_payment';

  static const debtAdd = 'debt.add';
  static const debtAddPayment = 'debt.add_payment';
  static const debtOverdue = 'debt.overdue';

  static const salaryAddEmployee = 'salary.add_employee';
  static const salaryAddRecord = 'salary.add_record';
  static const salaryBulkPayment = 'salary.bulk_payment';

  static const paymentsOverdue = 'payments.overdue';
  static const paymentsNext30 = 'payments.next30';

  static const cashAddAccount = 'cash.add_account';
  static const cashInflow = 'cash.inflow';
  static const cashOutflow = 'cash.outflow';
  static const cashTransfer = 'cash.transfer';
  static const cashCorrection = 'cash.correction';
  static const cashAdvance = 'cash.advance';
  static const cashDebtPaymentLink = 'cash.debt_payment_link';

  static const paymentSupplier = 'payment.supplier';
  static const paymentSalary = 'payment.salary';
  static const paymentExpense = 'payment.expense';
  static const paymentDebt = 'payment.debt';
  static const paymentCashOutflow = 'payment.cash_outflow';
  static const paymentBankTransfer = 'payment.bank_transfer';

  static const Set<String> incomeTabActions = {
    incomeAdd,
    incomePending,
    incomeReset,
  };

  static const Set<String> expenseTabActions = {
    expenseAdd,
    expensePending,
    expenseOverdue,
    expenseAddPayment,
    paymentExpense,
  };

  static const Set<String> debtTabActions = {
    debtAdd,
    debtAddPayment,
    debtOverdue,
    paymentSupplier,
    paymentDebt,
    cashDebtPaymentLink,
  };

  static const Set<String> salaryTabActions = {
    salaryAddEmployee,
    salaryAddRecord,
    salaryBulkPayment,
    paymentSalary,
  };

  static const Set<String> paymentsTabActions = {
    paymentsOverdue,
    paymentsNext30,
  };

  static const Set<String> cashTabActions = {
    cashAddAccount,
    cashInflow,
    cashOutflow,
    cashTransfer,
    cashCorrection,
    cashAdvance,
    paymentCashOutflow,
    paymentBankTransfer,
  };

  static int? tabIndexFor(String action) {
    if (incomeTabActions.contains(action)) return 2;
    if (expenseTabActions.contains(action)) return 3;
    if (debtTabActions.contains(action)) return 4;
    if (salaryTabActions.contains(action)) return 5;
    if (paymentsTabActions.contains(action)) return 6;
    if (cashTabActions.contains(action)) return 1;
    return null;
  }
}