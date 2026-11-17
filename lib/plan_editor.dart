import 'package:flutter/material.dart';
import 'schedule.dart';
import 'theme.dart';

class PlanEdit {
  PlanEdit(this.plan, {this.onlyDay = false, this.remove = false});
  final Plan plan;
  final bool onlyDay, remove;
}

class PlanEditor extends StatefulWidget {
  const PlanEditor({
    super.key,
    required this.day,
    this.original,
    this.occurrence,
    this.event = false,
  });
  final DateTime day;
  final Plan? original, occurrence;
  final bool event;
  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _notes;
  late DateTime _date, _endDate;
  DateTime? _until;
  late String _kind, _category, _repeat;
  late Set<int> _weekdays;
  late int _start, _end;
  late bool _allDay, _tbc;
  bool _onlyDay = true;
  String? _error;
  bool get _editing => widget.original != null;
  bool get _recurring => widget.original?.recurring ?? false;
  bool get _occurrence => _recurring && _onlyDay;
  @override
  void initState() {
    super.initState();
    final p = widget.occurrence ?? widget.original;
    _title = TextEditingController(text: p?.title ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _date = _recurring ? widget.day : parseDate(p?.date ?? dateKey(widget.day));
    _endDate = parseDate(p?.endDate ?? dateKey(_date));
    _kind = p?.kind ?? (widget.event ? 'event' : 'task');
    _category = p?.category ?? (widget.event ? 'personal' : 'home');
    _repeat = p?.repeat ?? 'none';
    _weekdays = (p?.weekdays ?? [widget.day.weekday % 7]).toSet();
    _start = p?.start ?? 540;
    _end = p?.end ?? 600;
    _tbc = p?.timeTbc ?? false;
    _allDay = (p?.allDay ?? false) && !_tbc;
    _until = p?.until == null || p!.until!.isEmpty ? null : parseDate(p.until!);
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool end) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: end ? _endDate : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (end) {
        _endDate = chosen;
      } else {
        _date = chosen;
        if (_endDate.isBefore(_date)) _endDate = _date;
      }
    });
  }

  Future<void> _pickTime(bool end) async {
    final n = end ? _end : _start;
    final chosen = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: n ~/ 60, minute: n % 60),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      if (end) {
        _end = chosen.hour * 60 + chosen.minute;
      } else {
        final duration = _end - _start;
        _start = chosen.hour * 60 + chosen.minute;
        _end = (_start + duration).clamp(_start + 1, 1439);
      }
    });
  }

  Widget _label(String title, Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 12, color: muted)),
      const SizedBox(height: 7),
      child,
    ],
  );
  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String>? onChanged,
  ) => DropdownButtonFormField<String>(
    value: value,
    decoration: InputDecoration(labelText: label),
    isExpanded: true,
    items:
        options.entries
            .map(
              (e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
    onChanged: onChanged == null ? null : (v) => onChanged(v!),
  );
  void _save() {
    if (!_form.currentState!.validate()) return;
    final allDay = _allDay || (_kind == 'event' && _tbc);
    String? error;
    if (!allDay && _end <= _start) {
      error = 'End time must be later than start time.';
    }
    if (_kind == 'event' && _repeat == 'none' && _endDate.isBefore(_date)) {
      error = 'End date must be on or after start date.';
    }
    if (_repeat == 'weekly' && _weekdays.isEmpty) {
      error = 'Select at least one weekday.';
    }
    if (_repeat != 'none' &&
        _until != null &&
        dateKey(_until!).compareTo(dateKey(_date)) < 0) {
      error = 'Repeat end date must be on or after start date.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final p = Plan(
      id:
          widget.original?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      date: dateKey(_date),
      endDate:
          _kind == 'event' && _repeat == 'none'
              ? dateKey(_endDate)
              : dateKey(_date),
      kind: _kind,
      category: _category,
      repeat: _repeat,
      weekdays: _weekdays.toList(),
      until: _until == null ? null : dateKey(_until!),
      start: _start,
      end: _end,
      allDay: allDay,
      timeTbc: _kind == 'event' && _tbc,
      notes: _notes.text.trim(),
      autoJog:
          (widget.original?.autoJog ?? false) &&
          (_occurrence || _start == 1020),
    );
    Navigator.pop(context, PlanEdit(p, onlyDay: _occurrence));
  }

  Future<void> _remove() async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (c) => AlertDialog(
            title: const Text('Remove plan?'),
            content: Text(
              _occurrence
                  ? 'Remove only on ${dateLabel(widget.day)}?'
                  : 'Remove this plan${_recurring ? ' and all recurring occurrences' : ''}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Remove'),
              ),
            ],
          ),
    );
    if (yes == true && mounted) {
      Navigator.pop(
        context,
        PlanEdit(widget.original!, onlyDay: _occurrence, remove: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? 'Edit plan' : 'Add plan',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'task',
                    label: Text('Checklist item'),
                    icon: Icon(Icons.check_box_outlined, size: 17),
                  ),
                  ButtonSegment(
                    value: 'event',
                    label: Text('Event'),
                    icon: Icon(Icons.event_outlined, size: 17),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged:
                    _occurrence ? null : (v) => setState(() => _kind = v.first),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _title,
                autofocus: !_editing,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  counterText: '',
                ),
                validator:
                    (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a title.' : null,
              ),
              const SizedBox(height: 18),
              if (_recurring) ...[
                _select(
                  'Apply to',
                  _onlyDay ? 'day' : 'series',
                  const {'day': 'This day only', 'series': 'Entire routine'},
                  (v) => setState(() {
                    _onlyDay = v == 'day';
                    _date =
                        _onlyDay
                            ? widget.day
                            : parseDate(widget.original!.date);
                  }),
                ),
                const SizedBox(height: 18),
              ],
              Row(
                children: [
                  Expanded(
                    child: _label(
                      'Date',
                      OutlinedButton.icon(
                        onPressed:
                            _occurrence ||
                                    (_editing &&
                                        !_recurring &&
                                        widget.original!.date ==
                                            (widget.original!.endDate ??
                                                widget.original!.date))
                                ? null
                                : () => _pickDate(false),
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                        label: Text(
                          dateLabel(_date),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                  if (_kind == 'event' && _repeat == 'none') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: _label(
                        'End date',
                        OutlinedButton(
                          onPressed: () => _pickDate(true),
                          child: Text(
                            dateLabel(_endDate),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              _select(
                'Category',
                _category,
                categories,
                (v) => setState(() => _category = v),
              ),
              const SizedBox(height: 18),
              _select(
                'Repeat',
                _repeat,
                const {
                  'none': 'Does not repeat',
                  'daily': 'Daily',
                  'weekly': 'Weekly',
                },
                _occurrence ? null : (v) => setState(() => _repeat = v),
              ),
              if (_repeat == 'weekly' && !_occurrence) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: List.generate(7, (n) {
                    final day = (n + 1) % 7;
                    return FilterChip(
                      label: Text(
                        ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day],
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _weekdays.contains(day),
                      onSelected:
                          (yes) => setState(
                            () =>
                                yes
                                    ? _weekdays.add(day)
                                    : _weekdays.remove(day),
                          ),
                      showCheckmark: false,
                    );
                  }),
                ),
              ],
              if (_repeat != 'none' && !_occurrence) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _until ?? _date,
                            firstDate: _date,
                            lastDate: DateTime(2100),
                          );
                          if (d != null && mounted) setState(() => _until = d);
                        },
                        icon: const Icon(Icons.event_repeat, size: 17),
                        label: Text(
                          _until == null
                              ? 'No repeat end date'
                              : 'Until ${dateLabel(_until!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    if (_until != null)
                      IconButton(
                        tooltip: 'Remove repeat end date',
                        onPressed: () => setState(() => _until = null),
                        icon: const Icon(Icons.close, size: 18),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text(
                  'All day / no fixed time',
                  style: TextStyle(fontSize: 13),
                ),
                value: _allDay,
                onChanged:
                    (v) => setState(() {
                      _allDay = v!;
                      if (_allDay) _tbc = false;
                    }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
              if (_kind == 'event')
                CheckboxListTile(
                  title: const Text(
                    'Time to confirm',
                    style: TextStyle(fontSize: 13),
                  ),
                  value: _tbc,
                  onChanged:
                      (v) => setState(() {
                        _tbc = v!;
                        if (_tbc) _allDay = false;
                      }),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                ),
              if (!_allDay && !(_kind == 'event' && _tbc)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _label(
                        'Start time',
                        OutlinedButton(
                          onPressed: () => _pickTime(false),
                          child: Text(timeText(_start)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _label(
                        'End time',
                        OutlinedButton(
                          onPressed: () => _pickTime(true),
                          child: Text(timeText(_end)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              TextFormField(
                controller: _notes,
                maxLines: 3,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  counterText: '',
                ),
              ),
              if (_occurrence) ...[
                const SizedBox(height: 12),
                const Text(
                  'Changes apply only to this day.',
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
              const SizedBox(height: 22),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_editing)
                    TextButton(
                      onPressed: _remove,
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: Color(0xffa04936)),
                      ),
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(onPressed: _save, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
