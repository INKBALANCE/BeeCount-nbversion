import 'dart:convert';

import 'package:beecount/services/data/workday_calendar.dart';
import 'package:beecount/services/data/workday_calendar_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('远程 JSON 解析', () {
    test('正常年份：区分放假日与调休上班日，并保留节日名', () {
      final body = jsonEncode({
        'year': 2027,
        'papers': ['https://www.gov.cn/zhengce/zhengceku/202611/content_1.htm'],
        'days': [
          {'name': '元旦', 'date': '2027-01-01', 'isOffDay': true},
          {'name': '春节', 'date': '2027-01-31', 'isOffDay': false},
          {'name': '春节', 'date': '2027-02-05', 'isOffDay': true},
        ],
      });
      final data = WorkdayCalendarSync.parseYear(body, 2027)!;
      expect(data.offDays, {'01-01', '02-05'});
      expect(data.makeupWorkdays, {'01-31'});
      expect(data.holidayNames['01-31'], '春节');
      expect(data.source, contains('gov.cn'));
    });

    test('年份不匹配直接丢弃，避免把去年数据当今年用', () {
      final body = jsonEncode({
        'year': 2026,
        'days': [
          {'name': '国庆节', 'date': '2026-10-01', 'isOffDay': true},
        ],
      });
      expect(WorkdayCalendarSync.parseYear(body, 2027), isNull);
    });

    test('字段缺失或格式异常时返回 null，不抛异常', () {
      expect(WorkdayCalendarSync.parseYear('not json', 2027), isNull);
      expect(WorkdayCalendarSync.parseYear('{"year":2027}', 2027), isNull);
      expect(
        WorkdayCalendarSync.parseYear(
            jsonEncode({'year': 2027, 'days': []}), 2027),
        isNull,
      );
    });

    test('忽略不属于该年的日期', () {
      final body = jsonEncode({
        'year': 2027,
        'days': [
          {'name': '元旦', 'date': '2027-01-01', 'isOffDay': true},
          {'name': '脏数据', 'date': '2026-01-01', 'isOffDay': true},
          {'name': '脏数据', 'date': 'bad', 'isOffDay': true},
        ],
      });
      final data = WorkdayCalendarSync.parseYear(body, 2027)!;
      expect(data.offDays, {'01-01'});
    });
  });

  group('缓存装载', () {
    // 键名与 WorkdayCalendarSync 内部常量一致；测试里直接写死以便构造缓存。
    const cacheKey = 'workday_calendar_remote_v1';

    tearDown(WorkdayCalendar.clearRemote);

    test('hydrate 能把缓存装回内存并生效', () async {
      SharedPreferences.setMockInitialValues({
        cacheKey: jsonEncode({
          'fetchedAt': '2026-11-27T10:00:00.000',
          'years': {
            '2030': {
              'off': ['01-01', '01-02'],
              'work': ['01-05'],
              'names': {'01-01': '元旦'},
              'source': 'test-source',
            },
          },
        }),
      });

      await WorkdayCalendarSync.hydrate();

      expect(WorkdayCalendar.hasDataFor(2030), isTrue);
      expect(WorkdayCalendar.isHoliday(DateTime(2030, 1, 1)), isTrue);
      // 1/5 是周六，但缓存里标为调休上班
      expect(WorkdayCalendar.isWorkday(DateTime(2030, 1, 5)), isTrue);
      expect(WorkdayCalendarSync.lastFetchedAt, isNotNull);
    });

    test('缓存损坏时静默回退到内置快照', () async {
      SharedPreferences.setMockInitialValues({cacheKey: '{broken'});
      await WorkdayCalendarSync.hydrate();
      // 内置数据仍然可用
      expect(WorkdayCalendar.hasDataFor(2027), isTrue);
      expect(WorkdayCalendar.isWorkday(DateTime(2027, 1, 31)), isTrue);
    });
  });
}
