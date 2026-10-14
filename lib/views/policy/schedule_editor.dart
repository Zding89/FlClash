import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/policy/models.dart';
import 'package:flutter/material.dart';

class PolicyScheduleEditor extends StatelessWidget {
  const PolicyScheduleEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final PolicySchedule value;
  final ValueChanged<PolicySchedule> onChanged;
  void _window(int index, PolicyWindow? next) => onChanged(
    PolicySchedule(
      timeZone: value.timeZone,
      windows: [
        for (var i = 0; i < value.windows.length; i++)
          if (i != index) value.windows[i] else ?next,
      ],
    ),
  );
  String _clock(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
  int? _minute(String text) {
    final parts = text.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null ||
        m == null ||
        h < 0 ||
        h > 24 ||
        m < 0 ||
        m > 59 ||
        h == 24 && m != 0) {
      return null;
    }
    return h * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.appLocalizations;
    final days = [
      s.policyWeekdayMon,
      s.policyWeekdayTue,
      s.policyWeekdayWed,
      s.policyWeekdayThu,
      s.policyWeekdayFri,
      s.policyWeekdaySat,
      s.policyWeekdaySun,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.policyScheduleEnabled),
          subtitle: Text(
            value.windows.isEmpty
                ? s.policyScheduleAllDay
                : s.policyScheduleHint,
          ),
          value: value.windows.isNotEmpty,
          onChanged: (enabled) => onChanged(
            PolicySchedule(
              timeZone: value.timeZone,
              windows: enabled ? [const PolicyWindow()] : [],
            ),
          ),
        ),
        if (value.windows.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: value.timeZone,
            decoration: InputDecoration(labelText: s.policyScheduleTimezone),
            items: [
              for (final zone in {'Asia/Shanghai', 'UTC', value.timeZone})
                DropdownMenuItem(value: zone, child: Text(zone)),
            ],
            onChanged: (zone) {
              if (zone != null) {
                onChanged(
                  PolicySchedule(timeZone: zone, windows: value.windows),
                );
              }
            },
          ),
          for (final (index, window) in value.windows.indexed)
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 4,
                      children: [
                        for (var day = 1; day <= 7; day++)
                          FilterChip(
                            label: Text(days[day - 1]),
                            selected: window.weekdays.contains(day),
                            onSelected: (selected) {
                              final weekdays = [...window.weekdays];
                              if (selected) {
                                weekdays.add(day);
                              } else {
                                weekdays.remove(day);
                              }
                              _window(
                                index,
                                PolicyWindow(
                                  weekdays: weekdays,
                                  startMinute: window.startMinute,
                                  endMinute: window.endMinute,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              'schedule-$index-${value.windows.length}-start',
                            ),
                            initialValue: _clock(window.startMinute),
                            decoration: InputDecoration(
                              labelText: s.policyStartTime,
                              hintText: 'HH:mm',
                            ),
                            validator: (text) =>
                                _minute(text ?? '') == null ||
                                    _minute(text!)! >= 1440
                                ? s.policyInvalidData
                                : null,
                            onChanged: (text) {
                              final minute = _minute(text);
                              if (minute != null) {
                                _window(
                                  index,
                                  PolicyWindow(
                                    weekdays: window.weekdays,
                                    startMinute: minute,
                                    endMinute: window.endMinute,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            key: ValueKey(
                              'schedule-$index-${value.windows.length}-end',
                            ),
                            initialValue: _clock(window.endMinute),
                            decoration: InputDecoration(
                              labelText: s.policyEndTime,
                              hintText: 'HH:mm',
                            ),
                            validator: (text) =>
                                _minute(text ?? '') == null ||
                                    _minute(text!) == window.startMinute
                                ? s.policyInvalidData
                                : null,
                            onChanged: (text) {
                              final minute = _minute(text);
                              if (minute != null) {
                                _window(
                                  index,
                                  PolicyWindow(
                                    weekdays: window.weekdays,
                                    startMinute: window.startMinute,
                                    endMinute: minute,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: s.delete,
                          onPressed: () => _window(index, null),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            onPressed: value.windows.length >= 20
                ? null
                : () => onChanged(
                    PolicySchedule(
                      timeZone: value.timeZone,
                      windows: [...value.windows, const PolicyWindow()],
                    ),
                  ),
            icon: const Icon(Icons.add),
            label: Text(s.add),
          ),
        ],
      ],
    );
  }
}
