enum AttendanceMode {
  checkIn,
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
  static AttendanceScheduleMode currentScheduleMode =
      AttendanceScheduleMode.demoFlexible;

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
      if (_between(minutes, 8, 0, 8, 15)) {
        return AttendanceMode.checkIn;
      }
      if (_between(minutes, 15, 30, 21, 0)) {
        return AttendanceMode.checkOut;
      }
      return AttendanceMode.outsideHours;
    }

    // Selasa-Kamis
    if (weekday >= DateTime.tuesday && weekday <= DateTime.thursday) {
      if (_between(minutes, 7, 0, 7, 30)) {
        return AttendanceMode.checkIn;
      }
      if (_between(minutes, 15, 30, 21, 0)) {
        return AttendanceMode.checkOut;
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
      case AttendanceMode.checkOut:
        return 'Arahkan wajah ke lingkaran untuk absensi pulang';
      case AttendanceMode.outsideHours:
        return 'Saat ini di luar jam absensi';
    }
  }

  static String getModeValue(AttendanceMode mode) {
    switch (mode) {
      case AttendanceMode.checkIn:
        return 'masuk';
      case AttendanceMode.checkOut:
        return 'pulang';
      case AttendanceMode.outsideHours:
        return 'di_luar_jam';
    }
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
}