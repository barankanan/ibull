// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';

// ─────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────

enum CashAccountType {
  cash('cash', 'Nakit Kasa', Icons.account_balance_wallet_rounded, Color(0xFF10B981)),
  bank('bank', 'Banka Hesabı', Icons.account_balance_rounded, Color(0xFF3B82F6)),
  pos('pos', 'POS Hesabı', Icons.point_of_sale_rounded, Color(0xFF8B5CF6)),
  courier('courier', 'Kurye Kasası', Icons.delivery_dining_rounded, Color(0xFFF59E0B)),
  branch('branch', 'Şube Kasası', Icons.storefront_rounded, Color(0xFF06B6D4)),
  partner('partner', 'Ortak Hesabı', Icons.people_rounded, Color(0xFFEC4899));

  const CashAccountType(this.value, this.label, this.icon, this.color);
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  static CashAccountType fromValue(String v) =>
      CashAccountType.values.firstWhere((e) => e.value == v,
          orElse: () => CashAccountType.cash);
}

enum CashMovementType {
  opening('opening', 'Açılış'),
  closing('closing', 'Kapanış'),
  income('income', 'Giriş'),
  expense('expense', 'Çıkış'),
  transfer('transfer', 'Transfer'),
  salaryPayment('salary_payment', 'Maaş Ödemesi'),
  supplierPayment('supplier_payment', 'Tedarikçi Ödemesi'),
  correction('correction', 'Düzeltme'),
  other('other', 'Diğer');

  const CashMovementType(this.value, this.label);
  final String value;
  final String label;

  static CashMovementType fromValue(String v) =>
      CashMovementType.values.firstWhere((e) => e.value == v,
          orElse: () => CashMovementType.other);
}

enum IncomeType {
  sales('sales', 'Satış Geliri'),
  delivery('delivery', 'Paket Servis'),
  platform('platform', 'Platform Geliri'),
  commission('commission', 'Komisyon'),
  rental('rental', 'Kira Geliri'),
  other('other', 'Diğer');

  const IncomeType(this.value, this.label);
  final String value;
  final String label;

  static IncomeType fromValue(String v) =>
      IncomeType.values.firstWhere((e) => e.value == v,
          orElse: () => IncomeType.other);
}

enum ExpenseCategory {
  rent('rent', 'Kira'),
  electricity('electricity', 'Elektrik'),
  water('water', 'Su'),
  gas('gas', 'Doğalgaz'),
  internet('internet', 'İnternet'),
  cleaning('cleaning', 'Temizlik'),
  packaging('packaging', 'Ambalaj'),
  advertising('advertising', 'Reklam'),
  accounting('accounting', 'Muhasebe'),
  software('software', 'Yazılım'),
  tax('tax', 'Vergi'),
  maintenance('maintenance', 'Bakım/Onarım'),
  salary('salary', 'Maaş'),
  sgk('sgk', 'SGK'),
  other('other', 'Diğer');

  const ExpenseCategory(this.value, this.label);
  final String value;
  final String label;

  static ExpenseCategory fromValue(String v) =>
      ExpenseCategory.values.firstWhere((e) => e.value == v,
          orElse: () => ExpenseCategory.other);
}

enum DebtType {
  supplier('supplier', 'Tedarikçi Borcu'),
  credit('credit', 'Kredi Borcu'),
  rent('rent', 'Kira Borcu'),
  tax('tax', 'Vergi Borcu'),
  sgk('sgk', 'SGK Borcu'),
  partner('partner', 'Ortak Borcu'),
  employeeAdvance('employee_advance', 'Personel Avans'),
  other('other', 'Diğer');

  const DebtType(this.value, this.label);
  final String value;
  final String label;

  static DebtType fromValue(String v) =>
      DebtType.values.firstWhere((e) => e.value == v,
          orElse: () => DebtType.other);
}

enum DebtStatus {
  active('active', 'Aktif', Color(0xFF3B82F6)),
  partiallyPaid('partially_paid', 'Kısmen Ödendi', Color(0xFFF59E0B)),
  paid('paid', 'Ödendi', Color(0xFF10B981)),
  overdue('overdue', 'Gecikmiş', Color(0xFFEF4444)),
  cancelled('cancelled', 'İptal', Color(0xFF6B7280));

  const DebtStatus(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  static DebtStatus fromValue(String v) =>
      DebtStatus.values.firstWhere((e) => e.value == v,
          orElse: () => DebtStatus.active);
}

enum SalaryStatus {
  pending('pending', 'Bekliyor', Color(0xFFF59E0B)),
  partial('partial', 'Kısmen Ödendi', Color(0xFF3B82F6)),
  paid('paid', 'Ödendi', Color(0xFF10B981));

  const SalaryStatus(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  static SalaryStatus fromValue(String v) =>
      SalaryStatus.values.firstWhere((e) => e.value == v,
          orElse: () => SalaryStatus.pending);
}

enum ReconciliationStatus {
  open('open', 'Açık', Color(0xFFF59E0B)),
  pending('pending', 'Bekliyor', Color(0xFF3B82F6)),
  resolved('resolved', 'Çözüldü', Color(0xFF10B981));

  const ReconciliationStatus(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  static ReconciliationStatus fromValue(String v) =>
      ReconciliationStatus.values.firstWhere((e) => e.value == v,
          orElse: () => ReconciliationStatus.open);
}

// ─────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────

class FinanceSupplier {
  const FinanceSupplier({
    required this.id,
    required this.sellerId,
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.taxNumber,
    this.notes,
    this.isActive = true,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxNumber;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;

  factory FinanceSupplier.fromJson(Map<String, dynamic> j) => FinanceSupplier(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        name: j['name'] as String,
        contactName: j['contact_name'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        address: j['address'] as String?,
        taxNumber: j['tax_number'] as String?,
        notes: j['notes'] as String?,
        isActive: (j['is_active'] as bool?) ?? true,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'name': name,
        if (contactName != null) 'contact_name': contactName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (taxNumber != null) 'tax_number': taxNumber,
        if (notes != null) 'notes': notes,
        'is_active': isActive,
      };
}

class CashAccount {
  const CashAccount({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.accountType,
    this.bankName,
    this.iban,
    this.currency = 'TRY',
    this.currentBalance = 0,
    this.isDefault = false,
    this.isActive = true,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final String name;
  final CashAccountType accountType;
  final String? bankName;
  final String? iban;
  final String currency;
  final double currentBalance;
  final bool isDefault;
  final bool isActive;
  final String? notes;
  final DateTime createdAt;

  factory CashAccount.fromJson(Map<String, dynamic> j) => CashAccount(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        name: j['name'] as String,
        accountType: CashAccountType.fromValue(j['account_type'] as String? ?? 'cash'),
        bankName: j['bank_name'] as String?,
        iban: j['iban'] as String?,
        currency: j['currency'] as String? ?? 'TRY',
        currentBalance: _toDouble(j['current_balance']),
        isDefault: (j['is_default'] as bool?) ?? false,
        isActive: (j['is_active'] as bool?) ?? true,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'name': name,
        'account_type': accountType.value,
        if (bankName != null) 'bank_name': bankName,
        if (iban != null) 'iban': iban,
        'currency': currency,
        'current_balance': currentBalance,
        'is_default': isDefault,
        'is_active': isActive,
        if (notes != null) 'notes': notes,
      };
}

class CashMovement {
  const CashMovement({
    required this.id,
    required this.sellerId,
    required this.accountId,
    required this.movementType,
    required this.amount,
    required this.direction,
    this.referenceId,
    this.referenceType,
    this.description,
    this.documentUrl,
    required this.movementDate,
    required this.createdAt,
    this.accountName,
  });

  final String id;
  final String sellerId;
  final String accountId;
  final CashMovementType movementType;
  final double amount;
  final String direction; // 'in' | 'out'
  final String? referenceId;
  final String? referenceType;
  final String? description;
  final String? documentUrl;
  final DateTime movementDate;
  final DateTime createdAt;
  final String? accountName; // joined

  bool get isIn => direction == 'in';

  factory CashMovement.fromJson(Map<String, dynamic> j) => CashMovement(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        accountId: j['account_id'] as String,
        movementType: CashMovementType.fromValue(j['movement_type'] as String? ?? 'other'),
        amount: _toDouble(j['amount']),
        direction: j['direction'] as String? ?? 'in',
        referenceId: j['reference_id'] as String?,
        referenceType: j['reference_type'] as String?,
        description: j['description'] as String?,
        documentUrl: j['document_url'] as String?,
        movementDate: DateTime.parse(j['movement_date'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
        accountName: j['finance_cash_accounts']?['name'] as String?,
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'account_id': accountId,
        'movement_type': movementType.value,
        'amount': amount,
        'direction': direction,
        if (referenceId != null) 'reference_id': referenceId,
        if (referenceType != null) 'reference_type': referenceType,
        if (description != null) 'description': description,
        'movement_date': movementDate.toIso8601String().substring(0, 10),
      };
}

class IncomeRecord {
  const IncomeRecord({
    required this.id,
    required this.sellerId,
    required this.incomeType,
    this.source,
    required this.grossAmount,
    required this.netAmount,
    this.taxAmount = 0,
    this.isCollected = false,
    this.collectedAt,
    this.accountId,
    this.periodMonth,
    this.periodYear,
    this.description,
    this.documentUrl,
    required this.incomeDate,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final IncomeType incomeType;
  final String? source;
  final double grossAmount;
  final double netAmount;
  final double taxAmount;
  final bool isCollected;
  final DateTime? collectedAt;
  final String? accountId;
  final int? periodMonth;
  final int? periodYear;
  final String? description;
  final String? documentUrl;
  final DateTime incomeDate;
  final DateTime createdAt;

  factory IncomeRecord.fromJson(Map<String, dynamic> j) => IncomeRecord(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        incomeType: IncomeType.fromValue(j['income_type'] as String? ?? 'other'),
        source: j['source'] as String?,
        grossAmount: _toDouble(j['gross_amount']),
        netAmount: _toDouble(j['net_amount']),
        taxAmount: _toDouble(j['tax_amount']),
        isCollected: (j['is_collected'] as bool?) ?? false,
        collectedAt: j['collected_at'] != null
            ? DateTime.parse(j['collected_at'] as String)
            : null,
        accountId: j['account_id'] as String?,
        periodMonth: j['period_month'] as int?,
        periodYear: j['period_year'] as int?,
        description: j['description'] as String?,
        documentUrl: j['document_url'] as String?,
        incomeDate: DateTime.parse(j['income_date'] as String),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'income_type': incomeType.value,
        if (source != null) 'source': source,
        'gross_amount': grossAmount,
        'net_amount': netAmount,
        'tax_amount': taxAmount,
        'is_collected': isCollected,
        if (accountId != null) 'account_id': accountId,
        if (periodMonth != null) 'period_month': periodMonth,
        if (periodYear != null) 'period_year': periodYear,
        if (description != null) 'description': description,
        'income_date': incomeDate.toIso8601String().substring(0, 10),
      };
}

class Expense {
  const Expense({
    required this.id,
    required this.sellerId,
    required this.category,
    this.supplierId,
    this.supplierName,
    required this.amount,
    this.isPaid = false,
    this.paidAt,
    this.dueDate,
    this.accountId,
    this.description,
    this.documentUrl,
    required this.expenseDate,
    this.isRecurring = false,
    this.recurringInterval,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final ExpenseCategory category;
  final String? supplierId;
  final String? supplierName; // joined
  final double amount;
  final bool isPaid;
  final DateTime? paidAt;
  final DateTime? dueDate;
  final String? accountId;
  final String? description;
  final String? documentUrl;
  final DateTime expenseDate;
  final bool isRecurring;
  final String? recurringInterval;
  final DateTime createdAt;

  bool get isOverdue =>
      !isPaid && dueDate != null && dueDate!.isBefore(DateTime.now());

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        category: ExpenseCategory.fromValue(j['category'] as String? ?? 'other'),
        supplierId: j['supplier_id'] as String?,
        supplierName: j['finance_suppliers']?['name'] as String?,
        amount: _toDouble(j['amount']),
        isPaid: (j['is_paid'] as bool?) ?? false,
        paidAt: j['paid_at'] != null
            ? DateTime.parse(j['paid_at'] as String)
            : null,
        dueDate: j['due_date'] != null
            ? DateTime.parse(j['due_date'] as String)
            : null,
        accountId: j['account_id'] as String?,
        description: j['description'] as String?,
        documentUrl: j['document_url'] as String?,
        expenseDate: DateTime.parse(j['expense_date'] as String),
        isRecurring: (j['is_recurring'] as bool?) ?? false,
        recurringInterval: j['recurring_interval'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'category': category.value,
        if (supplierId != null) 'supplier_id': supplierId,
        'amount': amount,
        'is_paid': isPaid,
        if (dueDate != null)
          'due_date': dueDate!.toIso8601String().substring(0, 10),
        if (accountId != null) 'account_id': accountId,
        if (description != null) 'description': description,
        'expense_date': expenseDate.toIso8601String().substring(0, 10),
        'is_recurring': isRecurring,
        if (recurringInterval != null) 'recurring_interval': recurringInterval,
      };
}

class Debt {
  const Debt({
    required this.id,
    required this.sellerId,
    required this.debtType,
    required this.creditorName,
    this.supplierId,
    required this.originalAmount,
    this.paidAmount = 0,
    required this.startDate,
    this.dueDate,
    required this.status,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final DebtType debtType;
  final String creditorName;
  final String? supplierId;
  final double originalAmount;
  final double paidAmount;
  final DateTime startDate;
  final DateTime? dueDate;
  final DebtStatus status;
  final String? description;
  final DateTime createdAt;

  double get remainingAmount => originalAmount - paidAmount;
  double get paidPercent =>
      originalAmount > 0 ? (paidAmount / originalAmount * 100).clamp(0, 100) : 0;

  factory Debt.fromJson(Map<String, dynamic> j) => Debt(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        debtType: DebtType.fromValue(j['debt_type'] as String? ?? 'other'),
        creditorName: j['creditor_name'] as String,
        supplierId: j['supplier_id'] as String?,
        originalAmount: _toDouble(j['original_amount']),
        paidAmount: _toDouble(j['paid_amount']),
        startDate: DateTime.parse(j['start_date'] as String),
        dueDate: j['due_date'] != null
            ? DateTime.parse(j['due_date'] as String)
            : null,
        status: DebtStatus.fromValue(j['status'] as String? ?? 'active'),
        description: j['description'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'debt_type': debtType.value,
        'creditor_name': creditorName,
        if (supplierId != null) 'supplier_id': supplierId,
        'original_amount': originalAmount,
        'start_date': startDate.toIso8601String().substring(0, 10),
        if (dueDate != null)
          'due_date': dueDate!.toIso8601String().substring(0, 10),
        if (description != null) 'description': description,
      };
}

class DebtPayment {
  const DebtPayment({
    required this.id,
    required this.sellerId,
    required this.debtId,
    required this.amount,
    required this.paymentDate,
    this.accountId,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final String debtId;
  final double amount;
  final DateTime paymentDate;
  final String? accountId;
  final String? description;
  final DateTime createdAt;

  factory DebtPayment.fromJson(Map<String, dynamic> j) => DebtPayment(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        debtId: j['debt_id'] as String,
        amount: _toDouble(j['amount']),
        paymentDate: DateTime.parse(j['payment_date'] as String),
        accountId: j['account_id'] as String?,
        description: j['description'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'debt_id': debtId,
        'amount': amount,
        'payment_date': paymentDate.toIso8601String().substring(0, 10),
        if (accountId != null) 'account_id': accountId,
        if (description != null) 'description': description,
      };
}

class FinanceEmployee {
  const FinanceEmployee({
    required this.id,
    required this.sellerId,
    required this.fullName,
    this.position,
    required this.baseSalary,
    this.paymentDay = 1,
    this.isActive = true,
    this.hireDate,
    this.phone,
    this.iban,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final String fullName;
  final String? position;
  final double baseSalary;
  final int paymentDay;
  final bool isActive;
  final DateTime? hireDate;
  final String? phone;
  final String? iban;
  final String? notes;
  final DateTime createdAt;

  factory FinanceEmployee.fromJson(Map<String, dynamic> j) => FinanceEmployee(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        fullName: j['full_name'] as String,
        position: j['position'] as String?,
        baseSalary: _toDouble(j['base_salary']),
        paymentDay: (j['payment_day'] as int?) ?? 1,
        isActive: (j['is_active'] as bool?) ?? true,
        hireDate: j['hire_date'] != null
            ? DateTime.parse(j['hire_date'] as String)
            : null,
        phone: j['phone'] as String?,
        iban: j['iban'] as String?,
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'full_name': fullName,
        if (position != null) 'position': position,
        'base_salary': baseSalary,
        'payment_day': paymentDay,
        'is_active': isActive,
        if (hireDate != null)
          'hire_date': hireDate!.toIso8601String().substring(0, 10),
        if (phone != null) 'phone': phone,
        if (iban != null) 'iban': iban,
        if (notes != null) 'notes': notes,
      };
}

class SalaryRecord {
  const SalaryRecord({
    required this.id,
    required this.sellerId,
    required this.employeeId,
    this.employeeName,
    required this.periodMonth,
    required this.periodYear,
    required this.baseSalary,
    this.bonus = 0,
    this.overtime = 0,
    this.deduction = 0,
    this.advanceDeduction = 0,
    required this.netSalary,
    required this.status,
    this.paidAmount = 0,
    this.notes,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final String employeeId;
  final String? employeeName; // joined
  final int periodMonth;
  final int periodYear;
  final double baseSalary;
  final double bonus;
  final double overtime;
  final double deduction;
  final double advanceDeduction;
  final double netSalary;
  final SalaryStatus status;
  final double paidAmount;
  final String? notes;
  final DateTime createdAt;

  double get remainingAmount => (netSalary - paidAmount).clamp(0, double.infinity);

  factory SalaryRecord.fromJson(Map<String, dynamic> j) => SalaryRecord(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        employeeId: j['employee_id'] as String,
        employeeName: j['finance_employees']?['full_name'] as String?,
        periodMonth: j['period_month'] as int,
        periodYear: j['period_year'] as int,
        baseSalary: _toDouble(j['base_salary']),
        bonus: _toDouble(j['bonus']),
        overtime: _toDouble(j['overtime']),
        deduction: _toDouble(j['deduction']),
        advanceDeduction: _toDouble(j['advance_deduction']),
        netSalary: _toDouble(j['net_salary']),
        status: SalaryStatus.fromValue(j['status'] as String? ?? 'pending'),
        paidAmount: _toDouble(j['paid_amount']),
        notes: j['notes'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'employee_id': employeeId,
        'period_month': periodMonth,
        'period_year': periodYear,
        'base_salary': baseSalary,
        'bonus': bonus,
        'overtime': overtime,
        'deduction': deduction,
        'advance_deduction': advanceDeduction,
        if (notes != null) 'notes': notes,
      };
}

class SalaryPayment {
  const SalaryPayment({
    required this.id,
    required this.sellerId,
    required this.salaryRecordId,
    required this.amount,
    required this.paymentDate,
    this.accountId,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final String salaryRecordId;
  final double amount;
  final DateTime paymentDate;
  final String? accountId;
  final String? description;
  final DateTime createdAt;

  factory SalaryPayment.fromJson(Map<String, dynamic> j) => SalaryPayment(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        salaryRecordId: j['salary_record_id'] as String,
        amount: _toDouble(j['amount']),
        paymentDate: DateTime.parse(j['payment_date'] as String),
        accountId: j['account_id'] as String?,
        description: j['description'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

class ReconciliationNote {
  const ReconciliationNote({
    required this.id,
    required this.sellerId,
    required this.subject,
    required this.noteDate,
    this.relatedAccountId,
    this.expectedAmount,
    this.actualAmount,
    required this.status,
    this.responsiblePerson,
    this.dueDate,
    this.description,
    required this.createdAt,
  });

  final String id;
  final String sellerId;
  final String subject;
  final DateTime noteDate;
  final String? relatedAccountId;
  final double? expectedAmount;
  final double? actualAmount;
  final ReconciliationStatus status;
  final String? responsiblePerson;
  final DateTime? dueDate;
  final String? description;
  final DateTime createdAt;

  double? get difference => (expectedAmount != null && actualAmount != null)
      ? actualAmount! - expectedAmount!
      : null;

  factory ReconciliationNote.fromJson(Map<String, dynamic> j) =>
      ReconciliationNote(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        subject: j['subject'] as String,
        noteDate: DateTime.parse(j['note_date'] as String),
        relatedAccountId: j['related_account_id'] as String?,
        expectedAmount: j['expected_amount'] != null
            ? _toDouble(j['expected_amount'])
            : null,
        actualAmount: j['actual_amount'] != null
            ? _toDouble(j['actual_amount'])
            : null,
        status: ReconciliationStatus.fromValue(
            j['status'] as String? ?? 'open'),
        responsiblePerson: j['responsible_person'] as String?,
        dueDate: j['due_date'] != null
            ? DateTime.parse(j['due_date'] as String)
            : null,
        description: j['description'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toInsertJson(String sellerId) => {
        'seller_id': sellerId,
        'subject': subject,
        'note_date': noteDate.toIso8601String().substring(0, 10),
        if (relatedAccountId != null) 'related_account_id': relatedAccountId,
        if (expectedAmount != null) 'expected_amount': expectedAmount,
        if (actualAmount != null) 'actual_amount': actualAmount,
        'status': status.value,
        if (responsiblePerson != null) 'responsible_person': responsiblePerson,
        if (dueDate != null)
          'due_date': dueDate!.toIso8601String().substring(0, 10),
        if (description != null) 'description': description,
      };
}

class CompanySettings {
  const CompanySettings({
    required this.id,
    required this.sellerId,
    this.companyName,
    this.taxNumber,
    this.taxOffice,
    this.address,
    this.phone,
    this.email,
    this.fiscalYearStart = 1,
    this.defaultCurrency = 'TRY',
    this.platformCommissionRate = 0.15,
    this.defaultCashAccountId,
  });

  final String id;
  final String sellerId;
  final String? companyName;
  final String? taxNumber;
  final String? taxOffice;
  final String? address;
  final String? phone;
  final String? email;
  final int fiscalYearStart;
  final String defaultCurrency;
  final double platformCommissionRate;
  final String? defaultCashAccountId;

  factory CompanySettings.fromJson(Map<String, dynamic> j) => CompanySettings(
        id: j['id'] as String,
        sellerId: j['seller_id'] as String,
        companyName: j['company_name'] as String?,
        taxNumber: j['tax_number'] as String?,
        taxOffice: j['tax_office'] as String?,
        address: j['address'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        fiscalYearStart: (j['fiscal_year_start'] as int?) ?? 1,
        defaultCurrency: j['default_currency'] as String? ?? 'TRY',
        platformCommissionRate: _toDouble(j['platform_commission_rate'] ?? 0.15),
        defaultCashAccountId: j['default_cash_account_id'] as String?,
      );

  Map<String, dynamic> toUpsertJson(String sellerId) => {
        'seller_id': sellerId,
        if (companyName != null) 'company_name': companyName,
        if (taxNumber != null) 'tax_number': taxNumber,
        if (taxOffice != null) 'tax_office': taxOffice,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        'fiscal_year_start': fiscalYearStart,
        'default_currency': defaultCurrency,
        'platform_commission_rate': platformCommissionRate,
        if (defaultCashAccountId != null)
          'default_cash_account_id': defaultCashAccountId,
      };
}

// ─────────────────────────────────────────
// Overview KPI aggregation model
// ─────────────────────────────────────────
class FinanceOverview {
  const FinanceOverview({
    required this.totalCashBalance,
    required this.totalBankBalance,
    required this.pendingCollections,
    required this.pendingPayments,
    required this.totalDebt,
    required this.monthSalaryLoad,
    required this.monthIncome,
    required this.monthExpense,
    required this.overduePayments,
    required this.upcomingPayments,
    required this.overdueDebts,
  });

  final double totalCashBalance;
  final double totalBankBalance;
  final double pendingCollections;
  final double pendingPayments;
  final double totalDebt;
  final double monthSalaryLoad;
  final double monthIncome;
  final double monthExpense;
  final int overduePayments;
  final int upcomingPayments;
  final int overdueDebts;

  double get monthNetIncome => monthIncome - monthExpense;
  double get monthNetPosition => monthIncome - monthExpense - monthSalaryLoad;
  double get totalLiquidity => totalCashBalance + totalBankBalance;

  /// Finans sağlığı puanı: 0–100
  int get healthScore {
    double score = 100;

    // Gelir/gider oranı
    if (monthExpense > 0) {
      final ratio = monthIncome / monthExpense;
      if (ratio < 1.0) {
        score -= 25;
      } else if (ratio < 1.2) {
        score -= 15;
      } else if (ratio < 1.5) {
        score -= 5;
      }
    }

    // Borç baskısı (aylık gelire oranla)
    if (monthIncome > 0 && totalDebt > 0) {
      final debtMonths = totalDebt / monthIncome;
      if (debtMonths > 6) {
        score -= 20;
      } else if (debtMonths > 3) {
        score -= 10;
      } else if (debtMonths > 1) {
        score -= 5;
      }
    }

    // Maaş yükü
    if (monthIncome > 0 && monthSalaryLoad > 0) {
      final salaryRatio = monthSalaryLoad / monthIncome;
      if (salaryRatio > 0.6) {
        score -= 15;
      } else if (salaryRatio > 0.4) {
        score -= 8;
      }
    }

    // Geciken ödemeler
    score -= (overduePayments * 3).clamp(0, 20);

    // Geciken borçlar
    score -= (overdueDebts * 5).clamp(0, 15);

    // Nakit durumu
    if (totalLiquidity < monthExpense) score -= 10;

    return score.round().clamp(0, 100);
  }

  String get healthLabel {
    final s = healthScore;
    if (s >= 80) return 'Mükemmel';
    if (s >= 60) return 'İyi';
    if (s >= 40) return 'Orta';
    if (s >= 20) return 'Zayıf';
    return 'Kritik';
  }

  Color get healthColor {
    final s = healthScore;
    if (s >= 80) return const Color(0xFF10B981);
    if (s >= 60) return const Color(0xFF3B82F6);
    if (s >= 40) return const Color(0xFFF59E0B);
    if (s >= 20) return const Color(0xFFEF4444);
    return const Color(0xFF7F1D1D);
  }

  factory FinanceOverview.fromJson(Map<String, dynamic> j) => FinanceOverview(
        totalCashBalance: _toDouble(j['total_cash_balance']),
        totalBankBalance: _toDouble(j['total_bank_balance']),
        pendingCollections: _toDouble(j['pending_collections']),
        pendingPayments: _toDouble(j['pending_payments']),
        totalDebt: _toDouble(j['total_debt']),
        monthSalaryLoad: _toDouble(j['month_salary_load']),
        monthIncome: _toDouble(j['month_income']),
        monthExpense: _toDouble(j['month_expense']),
        overduePayments: (j['overdue_payments'] as num?)?.toInt() ?? 0,
        upcomingPayments: (j['upcoming_payments'] as num?)?.toInt() ?? 0,
        overdueDebts: (j['overdue_debts'] as num?)?.toInt() ?? 0,
      );

  static const empty = FinanceOverview(
    totalCashBalance: 0,
    totalBankBalance: 0,
    pendingCollections: 0,
    pendingPayments: 0,
    totalDebt: 0,
    monthSalaryLoad: 0,
    monthIncome: 0,
    monthExpense: 0,
    overduePayments: 0,
    upcomingPayments: 0,
    overdueDebts: 0,
  );
}

class MonthlyTrendPoint {
  const MonthlyTrendPoint({
    required this.label,
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.net,
  });

  final String label;
  final int year;
  final int month;
  final double income;
  final double expense;
  final double net;

  factory MonthlyTrendPoint.fromJson(Map<String, dynamic> j) =>
      MonthlyTrendPoint(
        label: j['label'] as String,
        year: (j['yr'] as num).toInt(),
        month: (j['mo'] as num).toInt(),
        income: _toDouble(j['income']),
        expense: _toDouble(j['expense']),
        net: _toDouble(j['net']),
      );
}

// ─────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────
double _toDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}
