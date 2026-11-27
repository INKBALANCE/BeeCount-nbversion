import 'workday_calendar_data.dart';

/// 非工作日的原因。用于向用户解释"这一天为什么没记账 / 为什么顺延"。
enum NonWorkdayReason {
  /// 法定节假日（含调休连休日）
  holiday,

  /// 普通周末
  weekend,
}

/// 中国法定节假日 / 调休上班日判定。
///
/// 纯同步 API，供周期记账引擎在计算日期时直接调用；数据来自两层：
///   1. [kBuiltinWorkdayYears] 内置快照（离线也能算对）
///   2. 运行时由 `WorkdayCalendarSync` 拉取的远程数据，通过 [applyRemote] 覆盖内置
///
/// 判定优先级（这个顺序不能变）：
///   调休上班 > 法定节假日 > 周末
/// 例：2027-01-31 是周日，但按国办发通知要上班（春节调休），必须判为工作日。
class WorkdayCalendar {
  WorkdayCalendar._();

  static final Map<int, WorkdayYearData> _remote = {};

  /// 取某年的数据：远程优先，其次内置，都没有返回 null。
  static WorkdayYearData? dataFor(int year) =>
      _remote[year] ?? kBuiltinWorkdayYears[year];

  /// 该年是否有日历数据。没有时判定会退化为"只看周一到周五"。
  static bool hasDataFor(int year) => dataFor(year) != null;

  /// 当前已知数据的年份（升序），用于设置页展示"日历数据：2025–2027"。
  static List<int> get knownYears {
    final years = <int>{...kBuiltinWorkdayYears.keys, ..._remote.keys}.toList()
      ..sort();
    return years;
  }

  /// `MM-dd`
  static String _key(DateTime d) => '${_two(d.month)}-${_two(d.day)}';

  static String _two(int v) => v < 10 ? '0$v' : '$v';

  /// 法定节假日（含调休连休日）。
  static bool isHoliday(DateTime d) {
    final data = dataFor(d.year);
    if (data == null) return false;
    return data.offDays.contains(_key(d));
  }

  /// 调休上班日：通常是周末，但按通知需要上班。
  static bool isMakeupWorkday(DateTime d) {
    final data = dataFor(d.year);
    if (data == null) return false;
    return data.makeupWorkdays.contains(_key(d));
  }

  static bool isWeekend(DateTime d) => d.weekday >= DateTime.saturday;

  /// 是否工作日。
  ///
  /// 数据缺失时退化为"周一到周五"，不会把周末误判成工作日。
  static bool isWorkday(DateTime d) {
    if (isMakeupWorkday(d)) return true; // 调休上班，优先于周末判定
    if (isHoliday(d)) return false;
    return d.weekday <= DateTime.friday;
  }

  static bool isNonWorkday(DateTime d) => !isWorkday(d);

  /// 关联的节日名称，如 `国庆节`。
  ///
  /// 放假日志（1/1 → 元旦）和调休上班日（1/31 → 春节）都会返回名称，UI 借此可以
  /// 解释"这天为什么不上班"或"这天为什么周末还要上班"。
  static String? holidayName(DateTime d) => dataFor(d.year)?.holidayName(_key(d));

  /// 非工作日的原因；是工作日则返回 null。
  static NonWorkdayReason? nonWorkdayReason(DateTime d) {
    if (isWorkday(d)) return null;
    return isHoliday(d) ? NonWorkdayReason.holiday : NonWorkdayReason.weekend;
  }

  /// 用远程数据覆盖内置数据（仅覆盖传入的年份）。
  static void applyRemote(Map<int, WorkdayYearData> data) {
    data.forEach((year, value) => _remote[year] = value);
  }

  /// 清空远程覆盖，回到内置快照。
  static void clearRemote() => _remote.clear();

  /// 当前生效的数据是否是远程数据（设置页用来显示数据来源）。
  static bool isRemoteActive(int year) => _remote.containsKey(year);
}
