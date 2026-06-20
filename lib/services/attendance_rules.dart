import 'api_service.dart';

enum AttendanceMode {
  checkIn,
  apel,
  checkOut,
  outsideHours,
}

enum AttendanceScheduleMode {
  official,
  demoCheckIn,
  demoCheckOut,
  demoFlexible,
}

class AttendanceRules {
  static final ApiService _apiService = ApiService();

  static AttendanceScheduleMode currentScheduleMode =
      AttendanceScheduleMode.official;

  static DateTime? _lastScheduleSyncAt;
  static List<_ScheduleEntry> _scheduleEntries = [];
  static bool _isSyncInProgress = false;

  static Future<void> syncSchedulesFromApi({bool force = false}) async {
    if (_isSyncInProgress) {
      return;
    }

    final now = DateTime.now();
    if (!force &&
        _lastScheduleSyncAt != null &&
        now.difference(_lastScheduleSyncAt!) < const Duration(minutes: 5)) {
      return;
    }

    _isSyncInProgress = true;
    try {
      final response = await _apiService.getAttendanceSchedules();
      final categories = (response['categories'] as List?) ?? const [];
      final schedules = (response['schedules'] as List?) ?? const [];

      final Map<int, int> categoryPriority = {};
      for (final raw in categories) {
        if (raw is! Map) continue;
        final id = _toInt(raw['id']);
        final priority = _toInt(raw['priority']);
        if (id != null) {
          categoryPriority[id] = priority ?? 9999;
        }
      }

      final parsed = <_ScheduleEntry>[];
      for (final raw in schedules) {
        if (raw is! Map) continue;

        final day = _toInt(raw['day_of_week']);
        final start = _parseMinutes(raw['start_time']?.toString());
        final end = _parseMinutes(raw['end_time']?.toString());
        final isActive = _toBool(raw['is_active']);

        if (day == null || start == null || end == null || !isActive) {
          continue;
        }

        final categoryId = _toInt(raw['category_id']);
        final tolerance = _toInt(raw['tolerance_minutes']) ?? 0;
        final category = raw['category'];
        final priorityFromRelation =
            category is Map ? _toInt(category['priority']) : null;
        final priority = priorityFromRelation ??
            (categoryId != null ? categoryPriority[categoryId] : null) ??
            9999;

        parsed.add(_ScheduleEntry(
          dayOfWeek: day,
          startMinutes: start,
          endMinutes: end,
          toleranceMinutes: tolerance,
          categoryPriority: priority,
        ));
      }

      parsed.sort((a, b) {
        final p = a.categoryPriority.compareTo(b.categoryPriority);
        if (p != 0) return p;
        return a.startMinutes.compareTo(b.startMinutes);
      });

      _scheduleEntries = parsed;
      _lastScheduleSyncAt = now;
    } catch (_) {
      // Keep previous cache if API is temporarily unavailable.
    } finally {
      _isSyncInProgress = false;
    }
  }

  static AttendanceMode getAttendanceMode(DateTime now) {
    switch (currentScheduleMode) {
      case AttendanceScheduleMode.demoCheckIn:
        return AttendanceMode.checkIn;

      case AttendanceScheduleMode.demoCheckOut:
        return AttendanceMode.checkOut;

      case AttendanceScheduleMode.demoFlexible:
        final minutes = now.hour * 60 + now.minute;
        if (minutes < 15 * 60) {
          return AttendanceMode.checkIn;
        } else {
          return AttendanceMode.checkOut;
        }

      case AttendanceScheduleMode.official:
        return _officialMode(now);
    }
  }

  static AttendanceMode _officialMode(DateTime now) {
    final int weekday = now.weekday;
    final int minutes = now.hour * 60 + now.minute;

    // Check if Ramadhan Mode is active based on schedule category priority
    // or just assume Normal mode if we can't tell easily. Since the DB schedule lacks apel_time,
    // we will hardcode the check here, assuming Normal mode by default unless Ramadhan schedule is active.
    bool isRamadhan = false;
    final schedule = _scheduleForWeekday(weekday);
    if (schedule != null && schedule.categoryPriority == 2) {
      isRamadhan = true;
    }

    // Jumat
    if (weekday == DateTime.friday) {
      if (_between(minutes, 7, 0, 7, 30)) {
        return AttendanceMode.checkIn;
      }
      if (_between(minutes, 15, 0, 21, 0)) {
        return AttendanceMode.checkOut;
      }
      return AttendanceMode.outsideHours;
    }

    // Senin
    if (weekday == DateTime.monday) {
      // Masuk (Sama baik Normal maupun Ramadhan menurut SE)
      // Tunggu, SE bilang Ramadhan Masuk 07.30 - 08.00. Normal Masuk 07.00 - 07.30.
      if (isRamadhan) {
        if (_between(minutes, 7, 30, 8, 0)) return AttendanceMode.checkIn;
        if (_between(minutes, 8, 30, 8, 45)) return AttendanceMode.apel;
        if (_between(minutes, 15, 0, 21, 0)) return AttendanceMode.checkOut;
      } else {
        if (_between(minutes, 7, 0, 7, 30)) return AttendanceMode.checkIn;
        if (_between(minutes, 8, 0, 8, 15)) return AttendanceMode.apel;
        if (_between(minutes, 15, 30, 21, 0)) return AttendanceMode.checkOut;
      }
      return AttendanceMode.outsideHours;
    }

    // Selasa-Kamis
    if (weekday >= DateTime.tuesday && weekday <= DateTime.thursday) {
      if (isRamadhan) {
        if (_between(minutes, 7, 30, 8, 0)) return AttendanceMode.checkIn;
        if (_between(minutes, 15, 0, 21, 0)) return AttendanceMode.checkOut;
      } else {
        if (_between(minutes, 7, 0, 7, 30)) return AttendanceMode.checkIn;
        if (_between(minutes, 15, 30, 21, 0)) return AttendanceMode.checkOut;
      }
      return AttendanceMode.outsideHours;
    }

    return AttendanceMode.outsideHours;
  }

  static String getInstructionText(DateTime now) {
    final mode = getAttendanceMode(now);

    switch (mode) {
      case AttendanceMode.checkIn:
        return 'Arahkan wajah ke lingkaran untuk absensi masuk';
      case AttendanceMode.apel:
        return 'Arahkan wajah ke lingkaran untuk absensi apel pagi';
      case AttendanceMode.checkOut:
        return 'Arahkan wajah ke lingkaran untuk absensi pulang';
      case AttendanceMode.outsideHours:
        return 'Saat ini di luar jam absensi';
    }
  }

  static String getModeValue(AttendanceMode mode) {
    if (mode == AttendanceMode.checkIn) return 'masuk';
    if (mode == AttendanceMode.apel) return 'apel';
    if (mode == AttendanceMode.checkOut) return 'pulang';

    // Jika outsideHours, kita tentukan berdasarkan jam
    final hour = DateTime.now().hour;
    if (hour < 8) return 'masuk';
    if (hour < 10 && DateTime.now().weekday == DateTime.monday) return 'apel';
    return 'pulang';
  }

  static bool _between(
    int current,
    int startHour,
    int startMinute,
    int endHour,
    int endMinute,
  ) {
    final start = startHour * 60 + startMinute;
    final end = endHour * 60 + endMinute;
    return current >= start && current <= end;
  }

  static _ScheduleEntry? _scheduleForWeekday(int weekday) {
    for (final item in _scheduleEntries) {
      if (item.dayOfWeek == weekday) {
        return item;
      }
    }
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final parsed = value?.toString().toLowerCase();
    return parsed == '1' || parsed == 'true';
  }

  static int? _parseMinutes(String? timeValue) {
    if (timeValue == null || timeValue.isEmpty) {
      return null;
    }

    final parts = timeValue.split(':');
    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    return hour * 60 + minute;
  }
}

class _ScheduleEntry {
  final int dayOfWeek;
  final int startMinutes;
  final int endMinutes;
  final int toleranceMinutes;
  final int categoryPriority;

  const _ScheduleEntry({
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    required this.toleranceMinutes,
    required this.categoryPriority,
  });
}