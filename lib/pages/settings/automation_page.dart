import 'package:beecount_ui/beecount_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/reminder_providers.dart';
import '../shared/scaffold/widgets/page_scaffold.dart';
import '../transaction/recurring_transaction_page.dart';
import 'reminder_settings_page.dart';

/// Entry only: recurring rules and OS reminder settings stay in their original
/// pages, with the same Navigator stack and current Provider scope.
class AutomationPage extends ConsumerWidget {
  const AutomationPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final reminder = ref.watch(reminderSettingsProvider);
    // 未开启时沿用原文案（"设置每日记账提醒"），开启后直接显示生效时间，
    // 这样不进二级页也能确认提醒到底有没有生效。
    final reminderSubtitle = reminder.isEnabled
        ? l.reminderStatusOn(reminder.timeString)
        : l.mineReminderSettingsSubtitle;
    void open(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    return V4PageScaffold(
        body: Column(children: [
      BeePageHeader(title: l.automationPageTitle, leading: const BackButton()),
      Expanded(
          child: ListView(padding: const EdgeInsets.all(17), children: [
        Text(l.automationPageSubtitle,
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        const SizedBox(height: 12),
        BeeSurface(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              BeeMenuRow(
                  title: l.mineRecurringTransactions,
                  subtitle: l.mineRecurringTransactionsSubtitle,
                  leading: const BeeLineIcon('Repeat2'),
                  onTap: () => open(const RecurringTransactionPage())),
              const BeeDivider(),
              BeeMenuRow(
                  title: l.mineReminderSettings,
                  subtitle: reminderSubtitle,
                  leading: const BeeLineIcon('Bell'),
                  onTap: () => open(const ReminderSettingsPage())),
            ])),
      ])),
    ]));
  }
}
