import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'schedule.dart';
import 'storage.dart';
import 'theme.dart';
import 'plan_editor.dart';

class RoutineApp extends StatelessWidget {
  const RoutineApp({
    super.key,
    required this.schedule,
    this.storageError,
    this.writer,
  });
  final Schedule schedule;
  final String? storageError;
  final Future<void> Function(String)? writer;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Routine',
    debugShowCheckedModeBanner: false,
    theme: appTheme(),
    home: SchedulePage(
      initial: schedule,
      storageError: storageError,
      writer: writer ?? saveSchedule,
    ),
  );
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.initial,
    required this.writer,
    this.storageError,
  });
  final Schedule initial;
  final Future<void> Function(String) writer;
  final String? storageError;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late Schedule _schedule;
  late DateTime _day, _month, _miniMonth;
  late String? _storageError;
  bool _monthView = false, _mobileTimeline = false, _saving = false;
  Future<void> _saveQueue = Future.value();
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _schedule = widget.initial;
    _day = southAfricaToday();
    _month = DateTime(_day.year, _day.month, 1, 12);
    _miniMonth = _month;
    _storageError = widget.storageError;
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _key => dateKey(_day);
  bool get _wide => MediaQuery.sizeOf(context).width >= 1050;
  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
    );
  }

  void _save() {
    final text = _schedule.encode();
    setState(() => _saving = true);
    _saveQueue = _saveQueue.then((_) async {
      try {
        await widget.writer(text);
        if (mounted) {
          setState(() {
            _storageError = null;
            _saving = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _storageError =
                'Changes could not be saved. Retry or copy a backup.';
            _saving = false;
          });
        }
      }
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _day = DateTime(day.year, day.month, day.day, 12);
      _month = DateTime(day.year, day.month, 1, 12);
      _miniMonth = _month;
      _monthView = false;
    });
  }

  void _shift(int n) {
    setState(() {
      if (_monthView) {
        _month = DateTime(_month.year, _month.month + n, 1, 12);
        _miniMonth = _month;
      } else {
        _day = _day.add(Duration(days: n));
        _month = DateTime(_day.year, _day.month, 1, 12);
        _miniMonth = _month;
      }
    });
  }

  Future<void> _edit({Plan? plan, DateTime? day, bool event = false}) async {
    final selected = day ?? _day;
    final original =
        plan == null
            ? null
            : _schedule.items.firstWhere((p) => p.id == plan.id);
    final result = await showDialog<PlanEdit>(
      context: context,
      builder:
          (c) => PlanEditor(
            day: selected,
            original: original,
            occurrence: plan,
            event: event,
          ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.remove) {
        if (result.onlyDay) {
          _schedule.changeDay(dateKey(selected), result.plan.id, {
            'deleted': true,
          });
        } else {
          _schedule.items.removeWhere((p) => p.id == result.plan.id);
        }
      } else if (result.onlyDay) {
        final p = result.plan;
        _schedule.changeDay(dateKey(selected), p.id, {
          'title': p.title,
          'category': p.category,
          'start': timeKey(p.start),
          'end': timeKey(p.end),
          'allDay': p.allDay,
          'timeTbc': p.timeTbc,
          'notes': p.notes,
        });
      } else {
        final index = _schedule.items.indexWhere((p) => p.id == result.plan.id);
        if (index >= 0) {
          _schedule.items[index] = result.plan;
        } else {
          _schedule.items.add(result.plan);
        }
      }
    });
    _save();
  }

  Future<void> _move(Plan plan) async {
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (c) => MoveDialog(plan: plan, day: _day),
    );
    if (result == null || !mounted) return;
    setState(
      () => _schedule.changeDay(_key, plan.id, {
        'start': timeKey(result.$1),
        'end': timeKey(result.$2),
      }),
    );
    _save();
  }

  void _drop(Plan plan, int start) {
    final duration = plan.end - plan.start;
    start = start.clamp(0, 1439 - duration);
    setState(
      () => _schedule.changeDay(_key, plan.id, {
        'start': timeKey(start),
        'end': timeKey(start + duration),
      }),
    );
    _save();
    _message('${plan.title}: ${timeText(start)}');
  }

  void _status(Plan p, String value) {
    setState(
      () => _schedule.changeDay(_key, p.id, {
        'status': p.status == value ? 'pending' : value,
      }),
    );
    _save();
  }

  Future<void> _datePicker() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null && mounted) _selectDay(d);
  }

  Future<void> _backup() async {
    await showDialog<void>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Backup'),
            content: const SizedBox(
              width: 360,
              child: Text(
                'Plans save on this device. No device sync. Copy a backup to keep or transfer your plans.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Close'),
              ),
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(
                    ClipboardData(text: _schedule.encode()),
                  );
                  if (mounted) _message('Backup copied.');
                },
                child: const Text('Copy backup'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(c);
                  _restore();
                },
                child: const Text('Restore'),
              ),
            ],
          ),
    );
  }

  Future<void> _restore() async {
    final input = TextEditingController();
    String? error;
    final restored = await showDialog<Schedule>(
      context: context,
      builder:
          (c) => StatefulBuilder(
            builder:
                (c, setLocal) => AlertDialog(
                  title: const Text('Restore backup'),
                  content: SizedBox(
                    width: 450,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Replaces this device’s saved plans.'),
                        const SizedBox(height: 16),
                        TextField(
                          controller: input,
                          maxLines: 7,
                          decoration: InputDecoration(
                            labelText: 'Paste backup JSON',
                            errorText: error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () {
                        try {
                          final s = Schedule.decode(input.text);
                          Navigator.pop(c, s);
                        } catch (_) {
                          setLocal(() => error = 'Invalid Routine backup.');
                        }
                      },
                      child: const Text('Restore'),
                    ),
                  ],
                ),
          ),
    );
    input.dispose();
    if (restored == null || !mounted) return;
    setState(() => _schedule = restored);
    _save();
    _message('Backup restored.');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context), desktop = size.width >= 850;
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (desktop) SizedBox(width: 215, child: _sidebar()),
            Expanded(
              child: Column(
                children: [
                  _toolbar(desktop),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: EdgeInsets.fromLTRB(
                        desktop ? 34 : 18,
                        desktop ? 30 : 22,
                        desktop ? 34 : 18,
                        28,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1450),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _heading(),
                            if (_storageError != null) ...[
                              const SizedBox(height: 18),
                              Surface(
                                color: const Color(0xfff5dfcb),
                                padding: const EdgeInsets.all(13),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _storageError!,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _save,
                                      child: const Text('Retry'),
                                    ),
                                    TextButton(
                                      onPressed: _backup,
                                      child: const Text('Backup'),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (_monthView) _monthly() else _daily(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(bool desktop) => Container(
    height: 76,
    padding: EdgeInsets.symmetric(horizontal: desktop ? 34 : 18),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (!desktop) ...[
          const Icon(
            Icons.calendar_month_outlined,
            color: terracotta,
            size: 23,
          ),
          const SizedBox(width: 8),
          const Text(
            'Routine',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ] else
          Text(
            _saving
                ? 'Saving…'
                : _storageError != null
                ? 'Not saved'
                : 'Saved on this device',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
        const Spacer(),
        if (desktop)
          const Text('SAST', style: TextStyle(fontSize: 11, color: muted)),
        const SizedBox(width: 12),
        IconButton(
          tooltip: 'Backup and restore',
          onPressed: _backup,
          icon: const Icon(Icons.settings_outlined, size: 20),
        ),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed:
              () => _edit(event: _monthView, day: _monthView ? _month : _day),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
        ),
      ],
    ),
  );
  Widget _heading() => LayoutBuilder(
    builder: (context, c) {
      final compact = c.maxWidth < 730;
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _monthView ? 'Month' : '${weekNames[_day.weekday - 1]} · SAST',
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 7),
          Text(
            _monthView
                ? '${monthNames[_month.month - 1]} ${_month.year}'
                : dateLabel(_day),
            style: TextStyle(
              fontSize: compact ? 31 : 38,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.1,
            ),
          ),
        ],
      );
      final controls = Wrap(
        spacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _monthView ? 'Previous month' : 'Previous day',
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left, size: 20),
              ),
              TextButton(
                onPressed:
                    () => setState(() {
                      _day = southAfricaToday();
                      _month = DateTime(_day.year, _day.month, 1, 12);
                      _miniMonth = _month;
                    }),
                child: const Text('Today'),
              ),
              IconButton(
                tooltip: _monthView ? 'Next month' : 'Next day',
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right, size: 20),
              ),
              if (!_monthView)
                IconButton(
                  tooltip: 'Choose date',
                  onPressed: _datePicker,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                ),
            ],
          ),
          SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: false, label: Text('Day')),
              ButtonSegment(value: true, label: Text('Month')),
            ],
            selected: {_monthView},
            onSelectionChanged:
                (v) => setState(() {
                  _monthView = v.first;
                  if (_monthView) {
                    _month = DateTime(_day.year, _day.month, 1, 12);
                  }
                }),
          ),
        ],
      );
      return compact
          ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [title, const SizedBox(height: 16), controls],
          )
          : Row(children: [Expanded(child: title), controls]);
    },
  );
  Widget _sidebar() => Container(
    decoration: const BoxDecoration(
      color: sidebar,
      border: Border(right: BorderSide(color: line)),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 31, 20, 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: terracotta, size: 27),
              SizedBox(width: 9),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Routine',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 31),
          _nav(false, Icons.checklist, 'Daily checklist'),
          const SizedBox(height: 5),
          _nav(true, Icons.calendar_month_outlined, 'Monthly calendar'),
          const SizedBox(height: 27),
          _miniCalendar(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 23),
            child: Divider(),
          ),
          const Text(
            'Upcoming events',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 17),
          ..._upcoming(),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _backup,
            icon: const Icon(Icons.backup_outlined, size: 17),
            label: const Text('Backup', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    ),
  );
  Widget _nav(bool month, IconData icon, String label) => Material(
    color: _monthView == month ? const Color(0xffdacbb9) : Colors.transparent,
    borderRadius: BorderRadius.circular(7),
    child: InkWell(
      borderRadius: BorderRadius.circular(7),
      onTap: () => setState(() => _monthView = month),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: _monthView == month ? terracotta : muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: _monthView == month ? ink : muted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  List<DateTime> _calendarDates(DateTime m) {
    final first = DateTime(m.year, m.month, 1, 12);
    final days = DateTime(m.year, m.month + 1, 0).day;
    final offset = first.weekday - 1;
    return List.generate(
      ((days + offset) / 7).ceil() * 7,
      (i) => first.add(Duration(days: i - offset)),
    );
  }

  Widget _miniCalendar() {
    final dates = _calendarDates(_miniMonth);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${monthNames[_miniMonth.month - 1]} ${_miniMonth.year}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Previous calendar month',
                onPressed:
                    () => setState(
                      () =>
                          _miniMonth = DateTime(
                            _miniMonth.year,
                            _miniMonth.month - 1,
                            1,
                            12,
                          ),
                    ),
                icon: const Icon(Icons.chevron_left, size: 16),
              ),
            ),
            SizedBox(
              width: 24,
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Next calendar month',
                onPressed:
                    () => setState(
                      () =>
                          _miniMonth = DateTime(
                            _miniMonth.year,
                            _miniMonth.month + 1,
                            1,
                            12,
                          ),
                    ),
                icon: const Icon(Icons.chevron_right, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children:
              ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  .map(
                    (d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ),
                    ),
                  )
                  .toList(),
        ),
        const SizedBox(height: 7),
        ...List.generate(
          dates.length ~/ 7,
          (row) => Row(
            children: List.generate(7, (col) {
              final d = dates[row * 7 + col],
                  selected = dateKey(d) == _key,
                  events = _schedule.on(dateKey(d)).any((p) => !p.isTask);
              return Expanded(
                child: Tooltip(
                  message: dateLabel(d),
                  child: InkWell(
                    onTap: () => _selectDay(d),
                    borderRadius: BorderRadius.circular(5),
                    child: Container(
                      height: 28,
                      margin: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: selected ? terracotta : Colors.transparent,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 10,
                              color:
                                  selected
                                      ? panel
                                      : d.month == _miniMonth.month
                                      ? ink
                                      : muted.withValues(alpha: .5),
                            ),
                          ),
                          if (events)
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: selected ? panel : terracotta,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  List<Widget> _upcoming() {
    final seen = <String>{}, result = <Widget>[];
    for (var n = 0; n < 180 && result.length < 4; n++) {
      final date = southAfricaToday().add(Duration(days: n));
      for (final p in _schedule.on(dateKey(date)).where((p) => !p.isTask)) {
        if (!seen.add(p.id)) continue;
        result.add(
          InkWell(
            onTap: () {
              _selectDay(date);
              _edit(plan: p, day: date);
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 37,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      border: Border.all(color: line),
                      borderRadius: BorderRadius.circular(6),
                      color: paper,
                    ),
                    child: Column(
                      children: [
                        Text(
                          monthNames[date.month - 1].substring(0, 3),
                          style: const TextStyle(fontSize: 9, color: muted),
                        ),
                        Text(
                          '${date.day}',
                          style: const TextStyle(fontSize: 17),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          p.timeLabel,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (result.length == 4) break;
      }
    }
    return result.isEmpty
        ? [
          const Text(
            'No upcoming events',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ]
        : result;
  }

  Widget _daily() {
    final items = _schedule.on(_key),
        tasks = items.where((p) => p.isTask).toList(),
        done = tasks.where((p) => p.status == 'done').length,
        skipped = tasks.where((p) => p.status == 'skipped').length,
        allDay = items.where((p) => p.allDay).toList();
    final checklist = _checklist(items), timeline = _timeline(items);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Surface(
          color: const Color(0xffe8e8dc),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: tasks.isEmpty ? 0 : done / tasks.length,
                      color: sage,
                      backgroundColor: const Color(0xffcdd2bf),
                      strokeWidth: 4,
                    ),
                    Text(
                      '$done/${tasks.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 19),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$done of ${tasks.length} complete',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tasks.length - done - skipped} remaining${skipped == 0 ? '' : ' · $skipped skipped'}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Text(
                    '${items.where((p) => !p.isTask).length}',
                    style: const TextStyle(fontSize: 25),
                  ),
                  const Text(
                    'Events',
                    style: TextStyle(fontSize: 10, color: muted),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (allDay.isNotEmpty) ...[
          const SizedBox(height: 22),
          const Text(
            'All-day & unconfirmed events',
            style: TextStyle(
              fontSize: 12,
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                allDay
                    .map(
                      (p) => ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: InkWell(
                          onTap: () => _edit(plan: p),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: categoryColors[p.category]!.withValues(
                                alpha: .08,
                              ),
                              border: Border.all(
                                color: categoryColors[p.category]!.withValues(
                                  alpha: .25,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  p.isTask
                                      ? Icons.check_box_outlined
                                      : Icons.event_outlined,
                                  size: 17,
                                  color: categoryColors[p.category],
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.title,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${p.timeLabel}${p.id == 'sister-trip' && _key == p.endDate ? ' · Return this morning' : ''}',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
        const SizedBox(height: 23),
        if (!_wide) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.checklist, size: 17),
                label: Text('Checklist'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.schedule, size: 17),
                label: Text('Timetable'),
              ),
            ],
            selected: {_mobileTimeline},
            showSelectedIcon: false,
            onSelectionChanged:
                (s) => setState(() => _mobileTimeline = s.first),
          ),
          const SizedBox(height: 16),
          if (_mobileTimeline) timeline else checklist,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: checklist),
              const SizedBox(width: 24),
              Expanded(flex: 5, child: timeline),
            ],
          ),
      ],
    );
  }

  Widget _panelTitle(String title, {Widget? trailing}) => Container(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 17),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
  Widget _checklist(List<Plan> items) {
    final groups = [
      ('Morning', Icons.wb_sunny_outlined, 0, 720),
      ('Afternoon', Icons.wb_twilight, 720, 1080),
      ('Evening', Icons.dark_mode_outlined, 1080, 1440),
      ('Any time', Icons.checklist, -1, -1),
    ];
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _panelTitle(
            'Checklist',
            trailing: Text(
              '${items.where((p) => p.isTask && p.status == 'pending').length} remaining',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ),
          ...groups.expand((g) {
            final group =
                items
                    .where(
                      (p) =>
                          g.$3 < 0
                              ? p.allDay && p.isTask
                              : !p.allDay && p.start >= g.$3 && p.start < g.$4,
                    )
                    .toList();
            if (group.isEmpty) return <Widget>[];
            return [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 21, 20, 5),
                child: Row(
                  children: [
                    Icon(g.$2, size: 14, color: muted),
                    const SizedBox(width: 7),
                    Text(
                      g.$1,
                      style: const TextStyle(
                        fontSize: 11,
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ...group.map((p) => _taskRow(p, items)),
            ];
          }),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(25),
              child: Text(
                'No plans for this date.',
                style: TextStyle(color: muted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Add task'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskRow(Plan p, List<Plan> items) {
    final collisions = _schedule.overlaps(p, items),
        done = p.status == 'done',
        skipped = p.status == 'skipped',
        color = categoryColors[p.category]!;
    return Container(
      key: ValueKey('${_key}_${p.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xffece6dc))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (p.isTask)
            SizedBox(
              width: 30,
              height: 40,
              child: Checkbox(
                value: done,
                onChanged: (_) => _status(p, 'done'),
                semanticLabel: 'Complete ${p.title}',
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                activeColor: sage,
              ),
            )
          else
            SizedBox(
              width: 30,
              child: Icon(Icons.event_outlined, size: 18, color: color),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () => _edit(plan: p),
              borderRadius: BorderRadius.circular(5),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: done || skipped ? muted : ink,
                        decoration:
                            done || skipped ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 6,
                      runSpacing: 3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          p.timeLabel,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                        Text(
                          '· ${categories[p.category]}',
                          style: TextStyle(fontSize: 10, color: color),
                        ),
                        if (p.recurring)
                          const Icon(Icons.repeat, size: 11, color: muted),
                        if (skipped)
                          const Text(
                            'Skipped',
                            style: TextStyle(fontSize: 10, color: muted),
                          ),
                      ],
                    ),
                    if (p.shifted) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Moved earlier to avoid a clash',
                        style: TextStyle(fontSize: 10, color: sage),
                      ),
                    ],
                    if (collisions.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Overlaps: ${collisions.map((p) => p.title).join(', ')}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xffa65d37),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Options for ${p.title}',
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_horiz, size: 20, color: muted),
            onSelected: (v) {
              switch (v) {
                case 'move':
                  _move(p);
                case 'skip':
                  _status(p, 'skipped');
                case 'edit':
                  _edit(plan: p);
              }
            },
            itemBuilder:
                (_) => [
                  if (!p.allDay)
                    const PopupMenuItem(
                      value: 'move',
                      child: Text('Move time'),
                    ),
                  if (p.isTask)
                    PopupMenuItem(
                      value: 'skip',
                      child: Text(skipped ? 'Undo skip' : 'Skip today'),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                ],
          ),
        ],
      ),
    );
  }

  Widget _timeline(List<Plan> items) {
    final timed = items.where((p) => !p.allDay).toList(),
        startHour = timed.fold<int>(6, (n, p) => math.min(n, p.start ~/ 60)),
        endHour = timed.fold<int>(
          23,
          (n, p) => math.max(n, (p.end / 60).ceil()),
        ),
        height = (endHour - startHour) * 60.0;
    final lanes = <String, (int, int)>{};
    var group = <Plan>[], groupEnd = -1;
    void finish() {
      final ends = <int>[], indices = <String, int>{};
      for (final p in group) {
        var lane = ends.indexWhere((n) => n <= p.start);
        if (lane < 0) {
          lane = ends.length;
          ends.add(p.end);
        } else {
          ends[lane] = p.end;
        }
        indices[p.id] = lane;
      }
      for (final p in group) {
        lanes[p.id] = (indices[p.id]!, ends.length);
      }
      group = [];
    }

    for (final p in timed) {
      if (p.start >= groupEnd) {
        finish();
        groupEnd = -1;
      }
      group.add(p);
      groupEnd = math.max(groupEnd, p.end);
    }
    finish();
    return Surface(
      child: Column(
        children: [
          _panelTitle(
            'Timetable',
            trailing: const Tooltip(
              message: 'Drag an activity to a time slot, or tap to move.',
              child: Icon(Icons.drag_indicator, size: 18, color: muted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 23, 16, 24),
            child: LayoutBuilder(
              builder:
                  (context, c) => SizedBox(
                    height: height + 12,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ...List.generate(
                          endHour - startHour + 1,
                          (n) => Positioned(
                            top: n * 60.0,
                            left: 0,
                            right: 0,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    timeText((startHour + n) * 60),
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: muted,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider(height: 1)),
                              ],
                            ),
                          ),
                        ),
                        ...List.generate(
                          (endHour - startHour) * 4,
                          (n) => Positioned(
                            top: n * 15.0,
                            left: 42,
                            right: 0,
                            height: 15,
                            child: DragTarget<Plan>(
                              onAcceptWithDetails:
                                  (details) => _drop(
                                    details.data,
                                    startHour * 60 + n * 15,
                                  ),
                              builder:
                                  (context, candidates, rejected) => Container(
                                    color:
                                        candidates.isEmpty
                                            ? Colors.transparent
                                            : terracotta.withValues(alpha: .2),
                                    child:
                                        candidates.isEmpty
                                            ? null
                                            : Text(
                                              timeText(startHour * 60 + n * 15),
                                              style: const TextStyle(
                                                fontSize: 9,
                                                color: terracotta,
                                              ),
                                            ),
                                  ),
                            ),
                          ),
                        ),
                        ...timed.map((p) {
                          final (lane, count) = lanes[p.id]!;
                          final width = (c.maxWidth - 44) / count - 5,
                              h = math.max(21.0, p.end - p.start - 3.0),
                              color = categoryColors[p.category]!,
                              card = Container(
                                width: width,
                                height: h,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(
                                    alpha: p.status == 'pending' ? 0.14 : 0.07,
                                  ),
                                  border: Border(
                                    left: BorderSide(color: color, width: 2),
                                  ),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: ClipRect(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        p.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color:
                                              p.status == 'pending'
                                                  ? ink
                                                  : muted,
                                          fontWeight: FontWeight.w500,
                                          height: 1.25,
                                        ),
                                      ),
                                      if (h >= 35) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          '${timeText(p.start)} – ${timeText(p.end)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: color,
                                            height: 1.2,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                          return Positioned(
                            top: (p.start - startHour * 60).toDouble(),
                            left: 44 + lane * (c.maxWidth - 44) / count,
                            width: width,
                            height: h,
                            child: Draggable<Plan>(
                              data: p,
                              feedback: Material(
                                color: Colors.transparent,
                                child: Opacity(opacity: .85, child: card),
                              ),
                              childWhenDragging: Opacity(
                                opacity: .3,
                                child: card,
                              ),
                              child: Tooltip(
                                message:
                                    '${p.title}: ${p.timeLabel}. Tap to move.',
                                child: InkWell(
                                  onTap: () => _move(p),
                                  child: card,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _monthly() {
    final dates = _calendarDates(_month);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Surface(
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 600, cellHeight = 132.0;
              return Column(
                children: [
                  Container(
                    color: sidebar,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Row(
                      children:
                          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                              .map(
                                (d) => Expanded(
                                  child: Center(
                                    child: Text(
                                      d,
                                      style: TextStyle(
                                        fontSize: compact ? 10 : 11,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  ...List.generate(
                    dates.length ~/ 7,
                    (row) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(7, (col) {
                        final date = dates[row * 7 + col],
                            key = dateKey(date),
                            items =
                                _schedule
                                    .on(key)
                                    .where(
                                      (p) => !p.isTask || p.repeat == 'weekly',
                                    )
                                    .toList(),
                            isToday = key == dateKey(southAfricaToday());
                        return Expanded(
                          child: Container(
                            height: cellHeight,
                            decoration: BoxDecoration(
                              color:
                                  key == _key
                                      ? const Color(0xfff0e2d2)
                                      : date.month != _month.month
                                      ? const Color(0xfff0ede6)
                                      : panel,
                              border: Border(
                                top: const BorderSide(color: line),
                                right:
                                    col < 6
                                        ? const BorderSide(color: line)
                                        : BorderSide.none,
                              ),
                            ),
                            child: InkWell(
                              onTap: () => _selectDay(date),
                              child: Padding(
                                padding: EdgeInsets.all(compact ? 4 : 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color:
                                              isToday
                                                  ? terracotta
                                                  : Colors.transparent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${date.day}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color:
                                                isToday
                                                    ? panel
                                                    : date.month != _month.month
                                                    ? muted
                                                    : ink,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ...items
                                        .take(3)
                                        .map(
                                          (p) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 3,
                                            ),
                                            child: Tooltip(
                                              message:
                                                  '${p.title} · ${p.timeLabel}',
                                              child: InkWell(
                                                onTap: () {
                                                  _selectDay(date);
                                                  _edit(plan: p, day: date);
                                                },
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 3,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: categoryColors[p
                                                            .category]!
                                                        .withValues(alpha: .12),
                                                    border: Border(
                                                      left: BorderSide(
                                                        color:
                                                            categoryColors[p
                                                                .category]!,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          3,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${p.title}${p.allDay ? '' : ' ${timeText(p.start)}'}',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize:
                                                          compact ? 8 : 10,
                                                      color:
                                                          categoryColors[p
                                                              .category],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    if (items.length > 3)
                                      Text(
                                        '+${items.length - 3} more',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          color: muted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Events in ${monthNames[_month.month - 1]}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        ..._monthlyEvents(),
      ],
    );
  }

  List<Widget> _monthlyEvents() {
    final seen = <String>{}, widgets = <Widget>[];
    final count = DateTime(_month.year, _month.month + 1, 0).day;
    for (var n = 0; n < count; n++) {
      final date = _month.add(Duration(days: n));
      for (final p in _schedule.on(dateKey(date)).where((p) => !p.isTask)) {
        if (!seen.add(p.id)) continue;
        widgets.add(
          InkWell(
            onTap: () {
              _selectDay(date);
              _edit(plan: p, day: date);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: line)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 77,
                    child: Text(
                      '${date.day} ${monthNames[date.month - 1].substring(0, 3)}',
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: categoryColors[p.category],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(p.title, style: const TextStyle(fontSize: 12)),
                  ),
                  if (MediaQuery.sizeOf(context).width > 650) ...[
                    const SizedBox(width: 12),
                    Text(
                      p.timeLabel,
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                  const SizedBox(width: 12),
                  const Icon(Icons.chevron_right, size: 17, color: muted),
                ],
              ),
            ),
          ),
        );
      }
    }
    return widgets.isEmpty
        ? [
          const Text(
            'No events this month.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
        ]
        : widgets;
  }
}

class MoveDialog extends StatefulWidget {
  const MoveDialog({super.key, required this.plan, required this.day});
  final Plan plan;
  final DateTime day;
  @override
  State<MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<MoveDialog> {
  late int start, end;
  String? error;
  @override
  void initState() {
    super.initState();
    start = widget.plan.start;
    end = widget.plan.end;
  }

  Future<void> pick(bool isEnd) async {
    final n = isEnd ? end : start;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: n ~/ 60, minute: n % 60),
    );
    if (t == null || !mounted) return;
    setState(() {
      if (isEnd) {
        end = t.hour * 60 + t.minute;
      } else {
        final duration = end - start;
        start = t.hour * 60 + t.minute;
        end = math.min(1439, start + duration);
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Move time'),
    content: SizedBox(
      width: 350,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.plan.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            dateLabel(widget.day),
            style: const TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => pick(false),
                  child: Text('Start ${timeText(start)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => pick(true),
                  child: Text('End ${timeText(end)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Changes only this day.',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (end <= start) {
            setState(() => error = 'End time must be later than start time.');
          } else {
            Navigator.pop(context, (start, end));
          }
        },
        child: const Text('Move'),
      ),
    ],
  );
}
