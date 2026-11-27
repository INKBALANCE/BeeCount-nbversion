import 'package:beecount/services/data/workday_calendar.dart';
import 'package:beecount/services/data/workday_calendar_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// 节假日判定是"账目对不对"的地基，这里逐条对着国办发通知核对。
///
/// 2025：国办发明电〔2024〕12 号
/// 2026：国办发 2025 年 11 月通知
/// 2027：国办发 2026 年 11 月 5 日通知（春节 1/31、2/14 上班等）
void main() {
  group('2027 年（最新一期通知）', () {
    test('春节调休：周日要上班', () {
      // 1/31 周日、2/14 周日 —— 通知明确要求上班
      expect(WorkdayCalendar.isWorkday(DateTime(2027, 1, 31)), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2027, 2, 14)), isTrue);
      expect(WorkdayCalendar.isMakeupWorkday(DateTime(2027, 1, 31)), isTrue);
    });

    test('春节 2/5–2/13 九天全部放假', () {
      for (var day = 5; day <= 13; day++) {
        final date = DateTime(2027, 2, day);
        expect(WorkdayCalendar.isHoliday(date), isTrue, reason: '2/$day 应放假');
        expect(WorkdayCalendar.isWorkday(date), isFalse, reason: '2/$day 不应上班');
      }
      // 2/14 恢复上班（调休）
      expect(WorkdayCalendar.isWorkday(DateTime(2027, 2, 14)), isTrue);
    });

    test('单日假期：端午 6/9、中秋 9/15', () {
      expect(WorkdayCalendar.isHoliday(DateTime(2027, 6, 9)), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2027, 6, 9)), isFalse);
      expect(WorkdayCalendar.isHoliday(DateTime(2027, 9, 15)), isTrue);
    });

    test('国庆 10/1–10/7 放假，10/9 周六补班', () {
      for (var day = 1; day <= 7; day++) {
        expect(WorkdayCalendar.isHoliday(DateTime(2027, 10, day)), isTrue);
      }
      expect(WorkdayCalendar.isWorkday(DateTime(2027, 10, 9)), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2027, 9, 26)), isTrue);
      // 10/8 是普通周五，正常上班
      expect(WorkdayCalendar.isWorkday(DateTime(2027, 10, 8)), isTrue);
    });

    test('调休上班日能被识别为节假日来源', () {
      expect(WorkdayCalendar.holidayName(DateTime(2027, 1, 31)), '春节');
      expect(WorkdayCalendar.holidayName(DateTime(2027, 10, 9)), '国庆节');
    });
  });

  group('2026 年', () {
    test('国庆 10/1–10/7，9/20 与 10/10 补班', () {
      for (var day = 1; day <= 7; day++) {
        expect(WorkdayCalendar.isHoliday(DateTime(2026, 10, day)), isTrue);
      }
      expect(WorkdayCalendar.isWorkday(DateTime(2026, 9, 20)), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2026, 10, 10)), isTrue);
    });

    test('春节 2/15–2/23 九天，2/14 与 2/28 补班', () {
      for (var day = 15; day <= 23; day++) {
        expect(WorkdayCalendar.isHoliday(DateTime(2026, 2, day)), isTrue);
      }
      expect(WorkdayCalendar.isWorkday(DateTime(2026, 2, 14)), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2026, 2, 28)), isTrue);
    });

    test('元旦 1/1–1/3，1/4 周日补班', () {
      expect(WorkdayCalendar.isHoliday(DateTime(2026, 1, 1)), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2026, 1, 4)), isTrue);
    });

    test('数据条数与通知一致：33 天放假 + 6 天补班', () {
      final data = WorkdayCalendar.dataFor(2026)!;
      expect(data.offDays.length, 33);
      expect(data.makeupWorkdays.length, 6);
    });
  });

  group('2025 年', () {
    test('国庆中秋合并 10/1–10/8，9/28 与 10/11 补班', () {
      for (var day = 1; day <= 8; day++) {
        expect(WorkdayCalendar.isHoliday(DateTime(2025, 10, day)), isTrue);
      }
      expect(WorkdayCalendar.isWorkday(DateTime(2025, 9, 28)), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2025, 10, 11)), isTrue);
    });

    test('春节 1/28–2/4，1/26 与 2/8 补班', () {
      for (var day = 28; day <= 31; day++) {
        expect(WorkdayCalendar.isHoliday(DateTime(2025, 1, day)), isTrue);
      }
      for (var day = 1; day <= 4; day++) {
        expect(WorkdayCalendar.isHoliday(DateTime(2025, 2, day)), isTrue);
      }
      expect(WorkdayCalendar.isWorkday(DateTime(2025, 1, 26)), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2025, 2, 8)), isTrue);
    });
  });

  group('普通日期与非工作日原因', () {
    test('普通工作日 / 普通周末', () {
      expect(WorkdayCalendar.isWorkday(DateTime(2027, 3, 3)), isTrue); // 周三
      final saturday = DateTime(2027, 3, 6);
      expect(saturday.weekday, DateTime.saturday);
      expect(WorkdayCalendar.isWorkday(saturday), isFalse);
      expect(WorkdayCalendar.nonWorkdayReason(saturday),
          NonWorkdayReason.weekend);
    });

    test('节假日与周末的原因可区分', () {
      expect(WorkdayCalendar.nonWorkdayReason(DateTime(2027, 10, 1)),
          NonWorkdayReason.holiday);
      expect(WorkdayCalendar.nonWorkdayReason(DateTime(2027, 3, 3)), isNull);
    });
  });

  group('数据缺失的降级', () {
    test('无数据年份退化为只看周一到周五', () {
      // 2030 年没有数据
      expect(WorkdayCalendar.hasDataFor(2030), isFalse);
      expect(WorkdayCalendar.isWorkday(DateTime(2030, 1, 1)), isTrue); // 周二
      expect(WorkdayCalendar.isWorkday(DateTime(2030, 1, 5)), isFalse); // 周六
      expect(WorkdayCalendar.holidayName(DateTime(2030, 1, 1)), isNull);
    });

    test('已知年份范围可查询', () {
      final years = WorkdayCalendar.knownYears;
      expect(years.contains(2025), isTrue);
      expect(years.contains(2026), isTrue);
      expect(years.contains(2027), isTrue);
    });
  });

  group('远程数据覆盖', () {
    tearDown(WorkdayCalendar.clearRemote);

    test('覆盖后以内置之外的数据为准，清除后回到内置', () {
      // 构造一个"假的 2030 年"：只有 1/1 放假
      WorkdayCalendar.applyRemote({
        2030: const WorkdayYearData(
          offDays: {'01-01'},
          makeupWorkdays: {'01-05'},
          holidayNames: {'01-01': '测试节'},
          source: 'test',
        ),
      });
      expect(WorkdayCalendar.hasDataFor(2030), isTrue);
      expect(WorkdayCalendar.isHoliday(DateTime(2030, 1, 1)), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2030, 1, 5)), isTrue);

      WorkdayCalendar.clearRemote();
      expect(WorkdayCalendar.hasDataFor(2030), isFalse);
    });
  });
}
