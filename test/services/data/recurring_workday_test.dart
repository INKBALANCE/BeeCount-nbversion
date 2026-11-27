import 'package:beecount/services/data/recurring_transaction_service.dart';
import 'package:beecount/services/data/workday_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

/// 工作日规则的行为测试。
///
/// 两个入口的语义要分清：
///   nextDueDate      —— "此刻该生成的日期"，未到期或顺延日未到都返回 null
///   previewUpcoming  —— "计划中的下一期是哪天"，不受 now 限制
///
/// 最容易写错的地方是 shift 与 skip 的区别：
///   shift 顺延 —— 这一期仍要记账，只是挪到下一个工作日（房租 10/1 → 10/8）
///   skip  跳过 —— 这一期整期丢弃，日历推进到下一个正常期次（每月 1 日 → 11/1）
///
/// 2027 年国庆：10/1(周五)–10/7(周四) 放假，10/8(周五) 上班，10/9(周六) 调休上班。
RecurringScheduleSpec _spec({
  RecurringFrequency frequency = RecurringFrequency.monthly,
  int interval = 1,
  DateTime? startDate,
  int? dayOfMonth,
  DateTime? endDate,
  DateTime? lastGeneratedDate,
  WorkdayMode mode = WorkdayMode.none,
}) {
  return RecurringScheduleSpec(
    frequency: frequency,
    interval: interval,
    startDate: startDate ?? DateTime(2027, 1, 1),
    dayOfMonth: dayOfMonth,
    endDate: endDate,
    lastGeneratedDate: lastGeneratedDate,
    workdayMode: mode,
  );
}

DateTime? _due(RecurringScheduleSpec spec, DateTime now) =>
    RecurringTransactionService.nextDueDate(spec, now: now);

DateTime _plannedFirst(RecurringScheduleSpec spec, DateTime now) =>
    RecurringTransactionService.previewUpcomingOccurrences(spec,
            count: 1, now: now)
        .first
        .date;

void main() {
  group('不处理（none）：与存量行为一致', () {
    test('每月 1 日遇国庆仍在 10/1 生成', () {
      final spec = _spec(dayOfMonth: 1, lastGeneratedDate: DateTime(2027, 9, 1));
      expect(_plannedFirst(spec, DateTime(2027, 9, 2)), DateTime(2027, 10, 1));
      expect(_due(spec, DateTime(2027, 10, 1)), DateTime(2027, 10, 1));
    });
  });

  group('顺延（shift）：这一期仍然记账，日期后移', () {
    final spec = _spec(
      dayOfMonth: 1,
      lastGeneratedDate: DateTime(2027, 9, 1),
      mode: WorkdayMode.shift,
    );

    test('计划日期是 10/8（10/1–10/7 放假）', () {
      expect(_plannedFirst(spec, DateTime(2027, 9, 2)), DateTime(2027, 10, 8));
    });

    test('顺延日未到时不生成：10/3 打开 App 不应提前记账', () {
      expect(_due(spec, DateTime(2027, 10, 3)), isNull);
    });

    test('顺延日当天生成', () {
      expect(_due(spec, DateTime(2027, 10, 8)), DateTime(2027, 10, 8));
    });

    test('周末顺延到周一：11/6 周六的账单 → 11/8', () {
      final daily = _spec(
        frequency: RecurringFrequency.daily,
        startDate: DateTime(2027, 11, 1),
        lastGeneratedDate: DateTime(2027, 11, 5),
        mode: WorkdayMode.shift,
      );
      expect(_plannedFirst(daily, DateTime(2027, 11, 5)), DateTime(2027, 11, 8));
      expect(_due(daily, DateTime(2027, 11, 6)), isNull);
      expect(_due(daily, DateTime(2027, 11, 8)), DateTime(2027, 11, 8));
    });

    test('调休上班日算工作日：10/9 周六不顺延', () {
      final daily = _spec(
        frequency: RecurringFrequency.daily,
        startDate: DateTime(2027, 10, 1),
        lastGeneratedDate: DateTime(2027, 10, 8),
        mode: WorkdayMode.shift,
      );
      expect(_due(daily, DateTime(2027, 10, 9)), DateTime(2027, 10, 9));
    });
  });

  group('跳过（skip）：整期丢弃，推进到下一期', () {
    test('每月 1 日遇国庆 → 直接跳到 11/1，而不是 10/8', () {
      final spec = _spec(
        dayOfMonth: 1,
        lastGeneratedDate: DateTime(2027, 9, 1),
        mode: WorkdayMode.skip,
      );
      expect(_plannedFirst(spec, DateTime(2027, 9, 2)), DateTime(2027, 11, 1));
    });

    test('每天通勤：国庆假期不记，10/8 恢复', () {
      final daily = _spec(
        frequency: RecurringFrequency.daily,
        startDate: DateTime(2027, 9, 28),
        lastGeneratedDate: DateTime(2027, 9, 30),
        mode: WorkdayMode.skip,
      );
      expect(_due(daily, DateTime(2027, 10, 10)), DateTime(2027, 10, 8));
    });

    test('假期中不生成', () {
      final daily = _spec(
        frequency: RecurringFrequency.daily,
        startDate: DateTime(2027, 9, 28),
        lastGeneratedDate: DateTime(2027, 9, 30),
        mode: WorkdayMode.skip,
      );
      expect(_due(daily, DateTime(2027, 10, 5)), isNull);
    });

    test('普通周末跳过：周五之后直接到周一', () {
      final daily = _spec(
        frequency: RecurringFrequency.daily,
        startDate: DateTime(2027, 11, 1),
        lastGeneratedDate: DateTime(2027, 11, 5),
        mode: WorkdayMode.skip,
      );
      expect(_plannedFirst(daily, DateTime(2027, 11, 5)), DateTime(2027, 11, 8));
      expect(_due(daily, DateTime(2027, 11, 7)), isNull, reason: '周日尚不到周一');
      expect(_due(daily, DateTime(2027, 11, 8)), DateTime(2027, 11, 8));
    });

    test('调休上班日照常记：1/31 周日（春节调休）', () {
      final daily = _spec(
        frequency: RecurringFrequency.daily,
        startDate: DateTime(2027, 1, 25),
        lastGeneratedDate: DateTime(2027, 1, 30),
        mode: WorkdayMode.skip,
      );
      expect(_due(daily, DateTime(2027, 1, 31)), DateTime(2027, 1, 31));
    });
  });

  group('结束日期与工作日规则同时生效', () {
    test('顺延后的日期超出 endDate 则不再生成', () {
      final spec = _spec(
        dayOfMonth: 1,
        lastGeneratedDate: DateTime(2027, 9, 1),
        endDate: DateTime(2027, 10, 5),
        mode: WorkdayMode.shift,
      );
      // 10/1 顺延到 10/8，已越过 10/5 的结束日
      expect(_due(spec, DateTime(2027, 10, 8)), isNull);
    });
  });

  group('未来期次预览与实际生成同源', () {
    test('顺延模式下预览的每一期都落在工作日', () {
      final preview = RecurringTransactionService.previewUpcomingOccurrences(
        _spec(
          dayOfMonth: 1,
          lastGeneratedDate: DateTime(2027, 9, 1),
          mode: WorkdayMode.shift,
        ),
        count: 4,
        now: DateTime(2027, 9, 2),
      );
      expect(preview, isNotEmpty);
      for (final item in preview) {
        expect(WorkdayCalendar.isWorkday(item.date), isTrue,
            reason: '${item.date} 应是工作日');
      }
    });

    test('跳过模式下预览不会出现假期中的日期', () {
      final preview = RecurringTransactionService.previewUpcomingOccurrences(
        _spec(
          frequency: RecurringFrequency.daily,
          startDate: DateTime(2027, 9, 28),
          lastGeneratedDate: DateTime(2027, 9, 30),
          mode: WorkdayMode.skip,
        ),
        count: 5,
        now: DateTime(2027, 10, 10),
      );
      expect(preview.first.date, DateTime(2027, 10, 8));
      for (final item in preview) {
        expect(WorkdayCalendar.isWorkday(item.date), isTrue);
      }
    });
  });
}
