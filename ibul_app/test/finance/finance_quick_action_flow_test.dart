import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ibul_app/features/seller/finance/finance_quick_actions.dart';
import 'package:ibul_app/features/seller/finance/providers/finance_provider.dart';

void main() {
  testWidgets('quick action dogru sekmeye gider ve dialog bir kez acilir', (
    WidgetTester tester,
  ) async {
    final provider = FinanceProvider(sellerId: 'seller-test');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: _QuickActionTestHost()),
      ),
    );

    expect(find.text('tab:0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('trigger-expense-payment')));
    await tester.pump();
    await tester.pump();

    expect(find.text('tab:3'), findsOneWidget);
    expect(find.text('expense-dialog'), findsOneWidget);

    await tester.pump();
    expect(find.text('expense-dialog'), findsOneWidget);

    await tester.tap(find.text('Kapat'));
    await tester.pumpAndSettle();

    expect(find.text('expense-dialog'), findsNothing);

    await tester.pump();
    expect(find.text('expense-dialog'), findsNothing);
  });
}

class _QuickActionTestHost extends StatefulWidget {
  const _QuickActionTestHost();

  @override
  State<_QuickActionTestHost> createState() => _QuickActionTestHostState();
}

class _QuickActionTestHostState extends State<_QuickActionTestHost> {
  int _selectedIndex = 0;
  int? _scheduledEventId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final event = provider.quickAction;
    if (event != null && _scheduledEventId != event.id) {
      _scheduledEventId = event.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final tabIndex = FinanceQuickActions.tabIndexFor(event.action);
        if (tabIndex != null && _selectedIndex != tabIndex) {
          setState(() => _selectedIndex = tabIndex);
        }
      });
    }

    return Scaffold(
      body: Column(
        children: [
          Text('tab:$_selectedIndex'),
          ElevatedButton(
            key: const Key('trigger-expense-payment'),
            onPressed: () => provider.triggerQuickAction(FinanceQuickActions.paymentExpense),
            child: const Text('Trigger'),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                SizedBox.shrink(),
                SizedBox.shrink(),
                SizedBox.shrink(),
                _FakeQuickActionTab(
                  acceptedActions: FinanceQuickActions.expenseTabActions,
                  dialogTitle: 'expense-dialog',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FakeQuickActionTab extends StatefulWidget {
  const _FakeQuickActionTab({
    required this.acceptedActions,
    required this.dialogTitle,
  });

  final Set<String> acceptedActions;
  final String dialogTitle;

  @override
  State<_FakeQuickActionTab> createState() => _FakeQuickActionTabState();
}

class _FakeQuickActionTabState extends State<_FakeQuickActionTab> {
  int? _scheduledEventId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final event = provider.quickAction;
    if (event != null &&
        widget.acceptedActions.contains(event.action) &&
        _scheduledEventId != event.id) {
      _scheduledEventId = event.id;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final accepted = provider.consumeQuickAction(event.id);
        _scheduledEventId = null;
        if (!accepted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(widget.dialogTitle),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Kapat'),
              ),
            ],
          ),
        );
      });
    }

    return const SizedBox.expand();
  }
}