import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../system/logger_service.dart';
import 'workday_calendar.dart';
import 'workday_calendar_data.dart';

/// 节假日数据的远程同步。
///
/// 数据源：国务院办公厅《关于 XXXX 年部分节假日安排的通知》的结构化转写
/// （https://github.com/NateScarlet/holiday-cn），只含放假/调休日期，不含任何
/// 个人信息，请求就是一次普通 GET。
///
/// 策略（与内置快照配合）：
///   1. [hydrate] 在启动时把上次抓到的数据装进 [WorkdayCalendar]（离线可用）
///   2. [refreshIfNeeded] 发现当前/次年缺数据或数据过期时，才真正联网
///   3. 多个镜像依次尝试，全部失败就保持现状，不打断任何业务流程
///
/// 之所以不用系统日历：Android/iOS 都没有"今天是否法定节假日"的 API，系统日历
/// 只存事件标题，且**不含调休上班日**（如 2027-01-31 周日要上班），各厂商数据源
/// 还不一致，无法作为机器可读判定依据。
class WorkdayCalendarSync {
  WorkdayCalendarSync._();

  static const String _tag = 'WorkdayCalendar';

  /// 缓存整体（含 fetchedAt 与各年数据）的 prefs 键。
  static const String _prefsKey = 'workday_calendar_remote_v1';

  /// 超过这个时长就认为数据可能过期，允许重新拉取。
  static const Duration _staleAfter = Duration(days: 90);

  /// 镜像按可用性排序：国内网络下 jsdelivr 通常可达，GitHub 直连作为兜底。
  static const List<String> _mirrorTemplates = <String>[
    'https://fastly.jsdelivr.net/gh/NateScarlet/holiday-cn@master/%YEAR%.json',
    'https://cdn.jsdelivr.net/gh/NateScarlet/holiday-cn@master/%YEAR%.json',
    'https://gh-proxy.com/https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/%YEAR%.json',
    'https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/%YEAR%.json',
  ];

  static const Duration _perRequestTimeout = Duration(seconds: 8);

  static DateTime? _lastFetchedAt;

  /// 上次成功拉取的时间，null 表示从未成功过。
  static DateTime? get lastFetchedAt => _lastFetchedAt;

  /// 启动时调用：把缓存装进 [WorkdayCalendar]。
  ///
  /// 失败不影响任何功能——内置快照始终可用。
  static Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = _decode(raw);
      if (decoded == null) return;
      WorkdayCalendar.applyRemote(decoded.years);
      _lastFetchedAt = decoded.fetchedAt;
      logger.info(_tag,
          '已载入缓存节假日数据：${decoded.years.keys.toList()..sort()}');
    } catch (e) {
      logger.warning(_tag, '载入缓存节假日数据失败，继续使用内置快照', e);
    }
  }

  /// 需要时联网更新。返回是否发生了更新。
  ///
  /// [force] 为 true 时忽略新鲜度判断（设置页的"立即更新"按钮）。
  static Future<bool> refreshIfNeeded({bool force = false}) async {
    final now = DateTime.now();
    final years = <int>[now.year, now.year + 1];

    if (!force) {
      final fresh = _lastFetchedAt != null &&
          now.difference(_lastFetchedAt!) < _staleAfter &&
          years.every(WorkdayCalendar.hasDataFor);
      if (fresh) return false;
    }

    final fetched = <int, WorkdayYearData>{};
    for (final year in years) {
      final data = await _fetchYear(year);
      if (data != null) fetched[year] = data;
    }

    // 次年数据可能尚未发布（每年 11 月才发布次年安排），只要求当年成功。
    if (!fetched.containsKey(now.year)) {
      logger.info(_tag, '节假日数据更新失败，继续使用现有数据');
      return false;
    }

    WorkdayCalendar.applyRemote(fetched);
    _lastFetchedAt = now;
    await _persist(fetched, now);
    logger.info(_tag, '节假日数据已更新：${fetched.keys.toList()..sort()}');
    return true;
  }

  /// 清空缓存并回到内置快照。
  static Future<void> clear() async {
    WorkdayCalendar.clearRemote();
    _lastFetchedAt = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      logger.warning(_tag, '清除节假日缓存失败', e);
    }
  }

  static Future<WorkdayYearData?> _fetchYear(int year) async {
    for (final template in _mirrorTemplates) {
      final url = template.replaceAll('%YEAR%', '$year');
      try {
        final resp = await http.get(Uri.parse(url)).timeout(_perRequestTimeout);
        if (resp.statusCode != 200) continue;
        final parsed = parseYear(resp.body, year);
        if (parsed != null) {
          logger.info(_tag, '$year 年数据来源：$url');
          return parsed;
        }
      } catch (e) {
        // 换下一个镜像，不打日志噪音（国内网络常见）
        logger.debug(_tag, '$url 拉取失败：$e');
      }
    }
    return null;
  }

  /// 解析单年 JSON：
  /// `{"year":2027,"days":[{"name":"国庆节","date":"2027-10-01","isOffDay":true}]}`
  ///
  /// 数据源格式变化时宁可返回 null 走下一个镜像，也不要抛出异常。
  @visibleForTesting
  static WorkdayYearData? parseYear(String body, int year) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return null;
      if (json['year'] != year) return null;
      final days = json['days'];
      if (days is! List || days.isEmpty) return null;

      final offDays = <String>{};
      final makeup = <String>{};
      final names = <String, String>{};
      for (final item in days) {
        if (item is! Map) continue;
        final date = item['date'];
        final isOff = item['isOffDay'];
        if (date is! String || isOff is! bool) continue;
        if (!date.startsWith('$year-')) continue;
        final mmdd = date.substring(5);
        if (mmdd.length != 5) continue;
        // 节日名对放假与调休上班都记录：UI 要能解释"周末为什么还要上班"
        final name = item['name'];
        if (name is String && name.isNotEmpty) {
          names.putIfAbsent(mmdd, () => name);
        }
        if (isOff) {
          offDays.add(mmdd);
        } else {
          makeup.add(mmdd);
        }
      }
      if (offDays.isEmpty) return null;

      final papers = json['papers'];
      final source = (papers is List && papers.isNotEmpty && papers.first is String)
          ? papers.first as String
          : '';

      return WorkdayYearData(
        offDays: offDays,
        makeupWorkdays: makeup,
        holidayNames: names,
        source: source,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _persist(
      Map<int, WorkdayYearData> data, DateTime fetchedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = <String, dynamic>{
        'fetchedAt': fetchedAt.toIso8601String(),
        'years': {
          for (final entry in data.entries)
            '${entry.key}': {
              'off': entry.value.offDays.toList()..sort(),
              'work': entry.value.makeupWorkdays.toList()..sort(),
              'names': entry.value.holidayNames,
              'source': entry.value.source,
            },
        },
      };
      await prefs.setString(_prefsKey, jsonEncode(payload));
    } catch (e) {
      logger.warning(_tag, '保存节假日缓存失败', e);
    }
  }

  static _DecodedCache? _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final fetchedAtRaw = json['fetchedAt'];
      final yearsRaw = json['years'];
      if (yearsRaw is! Map) return null;

      final years = <int, WorkdayYearData>{};
      yearsRaw.forEach((key, value) {
        final year = int.tryParse('$key');
        if (year == null || value is! Map) return;
        final off = value['off'];
        final work = value['work'];
        if (off is! List) return;
        years[year] = WorkdayYearData(
          offDays: off.map((e) => '$e').toSet(),
          makeupWorkdays:
              work is List ? work.map((e) => '$e').toSet() : <String>{},
          holidayNames: value['names'] is Map
              ? (value['names'] as Map)
                  .map((k, v) => MapEntry('$k', '$v'))
              : <String, String>{},
          source: value['source'] is String ? value['source'] as String : '',
        );
      });
      if (years.isEmpty) return null;

      return _DecodedCache(
        years: years,
        fetchedAt: fetchedAtRaw is String ? DateTime.tryParse(fetchedAtRaw) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class _DecodedCache {
  const _DecodedCache({required this.years, this.fetchedAt});
  final Map<int, WorkdayYearData> years;
  final DateTime? fetchedAt;
}
