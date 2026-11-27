#!/usr/bin/env python3
"""生成 lib/services/data/workday_calendar_data.dart 的内置节假日快照。

数据来源
--------
国务院办公厅每年 11 月发布《关于 XXXX 年部分节假日安排的通知》。本脚本不手抄
通知，而是使用社区维护的结构化转写（NateScarlet/holiday-cn，该仓库每年在通知
发布后更新，并保留 gov.cn 原文链接）：

    https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/<year>.json

用法
----
    # 先把需要的内置年份下载到本地
    for y in 2025 2026 2027; do
      curl -sL https://raw.githubusercontent.com/NateScarlet/holiday-cn/master/$y.json -o /tmp/h$y.json
    done

    python3 tool/personal/gen_workday_data.py /tmp/h2025.json /tmp/h2026.json /tmp/h2027.json

为什么要生成而不是运行时联网
----------------------------
内置快照保证首启、离线、无网络时也能算对；运行时另有 workday_calendar_sync.dart
负责拉取更新并覆盖内置数据。内置年份只需要覆盖"当前年份及次年"，滚动保留即可。
"""

from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path

OUT = Path("lib/services/data/workday_calendar_data.dart")


def load(path: str) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def build(years: list[dict]) -> str:
    years.sort(key=lambda d: d["year"])
    parts: list[str] = []

    header = f'''// GENERATED FILE —— 由 tool/personal/gen_workday_data.py 生成，请勿手改。
//
// 数据来源：国务院办公厅《关于 XXXX 年部分节假日安排的通知》的结构化转写
//           https://github.com/NateScarlet/holiday-cn
// 生成日期：{dt.date.today().isoformat()}
// 覆盖年份：{", ".join(str(d["year"]) for d in years)}
//
// 每年 11 月国办发通知发布后，重新跑一次生成脚本即可。运行时也可以通过
// WorkdayCalendarSync 拉取最新数据覆盖本文件的内容（内置数据只作兜底）。

/// 一年的放假 / 调休安排。
///
/// 日期键统一为 `MM-dd`（同年内唯一，避免重复存年份）。
class WorkdayYearData {{
  const WorkdayYearData({{
    required this.offDays,
    required this.makeupWorkdays,
    required this.holidayNames,
    required this.source,
  }});

  /// 放假日：法定节假日及其调休连休日。
  final Set<String> offDays;

  /// 调休上班日：通常是周六或周日，但按通知需要上班。
  final Set<String> makeupWorkdays;

  /// 关联的节日名称，`MM-dd` -> `国庆节`。
  ///
  /// 放假日志与调休上班日都会记录：前者用于解释"这天为什么不上班"，
  /// 后者用于解释"这天为什么周末还要上班"（如 2027-01-31 春节调休）。
  final Map<String, String> holidayNames;

  /// 国办发通知原文链接，便于追溯核对。
  final String source;

  String? holidayName(String mmdd) => holidayNames[mmdd];
}}

/// 内置快照。运行时若已从网络拉到更新，以网络数据为准。
const Map<int, WorkdayYearData> kBuiltinWorkdayYears = {{
'''
    parts.append(header)

    for d in years:
        year = d["year"]
        off = sorted({x["date"] for x in d["days"] if x["isOffDay"]})
        mk = sorted({x["date"] for x in d["days"] if not x["isOffDay"]})
        # 放假与调休上班都记录节日名，UI 才能解释"周末为什么上班"
        names: dict[str, str] = {}
        for x in d["days"]:
            names.setdefault(x["date"], x["name"])
        source = (d.get("papers") or [""])[0]

        def mmdd(s: str) -> str:
            return s[5:]

        parts.append(f"  {year}: WorkdayYearData(\n")
        parts.append("    offDays: <String>{\n")
        for s in off:
            parts.append(f"      '{mmdd(s)}',\n")
        parts.append("    },\n")
        parts.append("    makeupWorkdays: <String>{\n")
        for s in mk:
            parts.append(f"      '{mmdd(s)}',\n")
        parts.append("    },\n")
        parts.append("    holidayNames: <String, String>{\n")
        for s in sorted(names):
            parts.append(f"      '{mmdd(s)}': '{names[s]}',\n")
        parts.append("    },\n")
        parts.append(f"    source: '{source}',\n")
        parts.append("  ),\n")

    parts.append("};\n")
    return "".join(parts)


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    years = [load(p) for p in argv]
    text = build(years)
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT} ({len(text)} bytes) for {[d['year'] for d in years]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
