import 'dart:convert';

const categories = <String, String>{
  'catholic': 'Catholic',
  'uni': 'Uni',
  'family': 'Family',
  'friends': 'Friends',
  'exercise': 'Exercise',
  'home': 'Home',
  'work': 'Work',
  'personal': 'Personal',
};
String normalizeActivityType(String value, {String? planId}) => switch (value) {
  'prayer' => 'catholic',
  'wellbeing' => 'exercise',
  'learning' => planId == 'gianna' ? 'family' : 'uni',
  _ => value,
};
const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const weekNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
String dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
DateTime parseDate(String s) => DateTime.parse('${s}T12:00:00');
DateTime southAfricaToday() {
  final n = DateTime.now().toUtc().add(const Duration(hours: 2));
  return DateTime(n.year, n.month, n.day, 12);
}

String dateLabel(DateTime d) => '${d.day} ${monthNames[d.month - 1]} ${d.year}';
String timeText(int n) {
  final h = (n ~/ 60) % 24, m = n % 60;
  return '${h % 12 == 0 ? 12 : h % 12}${m == 0 ? '' : ':${m.toString().padLeft(2, '0')}'}${h < 12 ? 'am' : 'pm'}';
}

String timeKey(int n) =>
    '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
int parseTime(String s) {
  if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s)) {
    throw const FormatException('Invalid time');
  }
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

class Plan {
  const Plan({
    required this.id,
    required this.title,
    required this.date,
    this.endDate,
    this.kind = 'task',
    this.category = 'personal',
    this.repeat = 'none',
    this.weekdays = const [],
    this.until,
    this.start = 540,
    this.end = 600,
    this.allDay = false,
    this.timeTbc = false,
    this.notes = '',
    this.autoJog = false,
    this.status = 'pending',
    this.shifted = false,
  });
  final String id, title, date, kind, category, repeat, notes, status;
  final String? endDate, until;
  final List<int> weekdays;
  final int start, end;
  final bool allDay, timeTbc, autoJog, shifted;
  bool get isTask => kind == 'task';
  bool get recurring => repeat != 'none';
  String get timeLabel =>
      timeTbc
          ? 'Time to confirm'
          : allDay
          ? 'All day'
          : '${timeText(start)} – ${timeText(end)}';
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date,
    'endDate': endDate ?? date,
    'kind': kind,
    'category': category,
    'repeat': repeat,
    'weekdays': weekdays,
    'until': until,
    'start': timeKey(start),
    'end': timeKey(end),
    'allDay': allDay,
    'timeTbc': timeTbc,
    'notes': notes,
    'autoJog': autoJog,
  };
  factory Plan.fromJson(Map<String, dynamic> j) {
    final p = Plan(
      id: j['id'] as String,
      title: j['title'] as String,
      date: j['date'] as String,
      endDate: j['endDate'] as String?,
      kind: j['kind'] as String,
      category: normalizeActivityType(
        j['category'] as String,
        planId: j['id'] as String,
      ),
      repeat: j['repeat'] as String,
      weekdays: (j['weekdays'] as List).cast<int>(),
      until: j['until'] as String?,
      start: j['start'] == null ? 540 : parseTime(j['start'] as String),
      end: j['end'] == null ? 600 : parseTime(j['end'] as String),
      allDay: j['allDay'] == true,
      timeTbc: j['timeTbc'] == true,
      notes: (j['notes'] ?? '') as String,
      autoJog: j['autoJog'] == true,
      status: (j['status'] ?? 'pending') as String,
    );
    bool validDate(String s) {
      try {
        return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) &&
            dateKey(parseDate(s)) == s;
      } catch (_) {
        return false;
      }
    }

    if (p.id.isEmpty ||
        p.title.trim().isEmpty ||
        p.title.length > 160 ||
        !validDate(p.date) ||
        (p.endDate != null &&
            (!validDate(p.endDate!) || p.endDate!.compareTo(p.date) < 0)) ||
        (p.until != null &&
            p.until!.isNotEmpty &&
            (!validDate(p.until!) || p.until!.compareTo(p.date) < 0)) ||
        !['task', 'event'].contains(p.kind) ||
        !categories.containsKey(p.category) ||
        !['none', 'daily', 'weekly'].contains(p.repeat) ||
        p.weekdays.any((n) => n < 0 || n > 6) ||
        (p.repeat == 'weekly' && p.weekdays.isEmpty) ||
        (!p.allDay && p.end <= p.start) ||
        !['pending', 'done', 'skipped'].contains(p.status)) {
      throw const FormatException('Invalid plan');
    }
    return p;
  }
  Plan withChanges(Map<String, dynamic> patch, {bool shifted = false}) {
    final j = {...toJson(), ...patch};
    final p = Plan.fromJson(j);
    return Plan(
      id: p.id,
      title: p.title,
      date: p.date,
      endDate: p.endDate,
      kind: p.kind,
      category: p.category,
      repeat: p.repeat,
      weekdays: p.weekdays,
      until: p.until,
      start: p.start,
      end: p.end,
      allDay: p.allDay,
      timeTbc: p.timeTbc,
      notes: p.notes,
      autoJog: p.autoJog,
      status: (patch['status'] ?? status) as String,
      shifted: shifted,
    );
  }

  bool occurs(String day) {
    if (day.compareTo(date) < 0 ||
        (until != null && until!.isNotEmpty && day.compareTo(until!) > 0)) {
      return false;
    }
    if (repeat == 'daily') return true;
    if (repeat == 'weekly') {
      return weekdays.contains(parseDate(day).weekday % 7);
    }
    return day.compareTo(endDate ?? date) <= 0;
  }
}

class Schedule {
  Schedule(this.items, [Map<String, Map<String, dynamic>>? overrides])
    : overrides = overrides ?? {};
  final List<Plan> items;
  final Map<String, Map<String, dynamic>> overrides;
  final Set<String> appliedEventUpdates = {};
  bool showRecurringEventsInMonth = true;
  void applyEventUpdates() {
    const briefDetails =
        'Prepare project briefs for EV/energy MSc vacation work and the go-kart project.\nInclude project scope and a bill of materials (BOM) sourced only from Wits vendors.\nCover the FHS exhibition and Science Forum go-kart demonstrations.\nInclude MSc research support and managing/supervising students during vacation work; vacation-work dates are not confirmed.\nBriefs, scope and BOM are needed by Thursday 19 November 2026.';
    const updates = [
      Plan(
        id: 'community-service-camp-2026',
        title: 'Community service camp',
        date: '2026-11-25',
        endDate: '2026-11-29',
        kind: 'event',
        category: 'catholic',
        allDay: true,
        notes:
            'Gingindlovu, KwaZulu-Natal.\nRefurbishing and painting a parish church.\nR800, including meals and accommodation.\nOrganisers: Brookside Hall and Westridge Study Centre.',
      ),
      Plan(
        id: 'vall-friends-2026-11-19',
        title: 'Vall with friends',
        date: '2026-11-19',
        endDate: '2026-11-22',
        kind: 'event',
        category: 'friends',
        allDay: true,
        notes:
            'Planned trip with friends, Thursday–Sunday. Travel times to confirm.',
      ),
      Plan(
        id: 'project-briefs-work-2026-11-18',
        title: 'Prepare EV/go-kart project briefs',
        date: '2026-11-18',
        category: 'uni',
        start: 900,
        end: 1020,
        notes: briefDetails,
      ),
      Plan(
        id: 'project-briefs-due-2026-11-19',
        title: 'Project briefs, scope & BOM due',
        date: '2026-11-19',
        kind: 'event',
        category: 'uni',
        allDay: true,
        notes: briefDetails,
      ),
      Plan(
        id: 'fhs-exhibition-2026-11-24',
        title: 'FHS go-kart exhibition (provisional)',
        date: '2026-11-24',
        kind: 'event',
        category: 'uni',
        allDay: true,
        timeTbc: true,
        notes:
            'Go-kart exhibition. Provisional date: Tuesday 24 November 2026. Confirm date, times and venue.',
      ),
    ];
    for (final plan in updates) {
      if (appliedEventUpdates.add(plan.id) &&
          !items.any((p) => p.id == plan.id)) {
        items.add(plan);
      }
    }
    if (appliedEventUpdates.add('sfsa-2026-details-v1')) {
      const forumDetails =
          'Science Forum South Africa 2026 (SFSA 2026), 1–4 December 2026.\nVenue: CSIR International Convention Centre, Pretoria, South Africa.\nTheme: Igniting Conversations about Science – From Research to Impact.\nCo-hosts: Department of Science, Technology and Innovation (DSTI) and Science Diplomacy Capital for Africa (SDCfA).\nFocus: STI financing, innovation and entrepreneurship, science diplomacy, emerging technologies, and the science-society nexus.\nGo-kart exhibition at the Science Forum.';
      const forumUpdates = {
        'ev-opening': (
          title: 'Science Forum: opening',
          notes: 'Ministerial Opening Plenary: 1 December, 16:00–18:30.',
        ),
        'ev-reception': (
          title: 'Science Forum: reception',
          notes: 'Welcome Reception: 1 December, 18:30–21:30.',
        ),
        'ev-days': (
          title: 'Science Forum: sessions & exhibition',
          notes:
              '2–3 December: parallel sessions, plenaries, exhibitions and networking. Exact times to confirm.',
        ),
        'ev-close': (
          title: 'Science Forum: closing by 2pm',
          notes:
              '4 December: closing sessions finish by 14:00. Start time to confirm.',
        ),
      };
      for (final entry in forumUpdates.entries) {
        final index = items.indexWhere((p) => p.id == entry.key);
        if (index < 0) continue;
        final current = items[index];
        final defaultTitle =
            current.title.startsWith('EV presentation') ||
            current.title == 'EV reception';
        final details = '$forumDetails\n${entry.value.notes}';
        items[index] = current.withChanges({
          'title': defaultTitle ? entry.value.title : current.title,
          'category': current.category == 'work' ? 'uni' : current.category,
          'notes':
              current.notes.trim().isEmpty
                  ? details
                  : '${current.notes.trim()}\n\n$details',
        });
      }
    }
  }

  void changeDay(String date, String id, Map<String, dynamic> patch) {
    final key = '$date|$id';
    overrides[key] = {...?overrides[key], ...patch};
  }

  List<Plan> on(String date) {
    final result = <Plan>[];
    for (final item in items.where((p) => p.occurs(date))) {
      final patch = overrides['$date|${item.id}'] ?? {};
      if (patch['deleted'] == true) continue;
      var plan = item.withChanges(patch);
      if (item.id == 'development' &&
          parseDate(date).weekday == DateTime.friday &&
          patch['start'] == null &&
          item.start == 840) {
        plan = plan.withChanges({'start': '13:30', 'end': '14:30'});
      }
      result.add(plan);
    }
    final jogIndex = result.indexWhere(
      (p) => p.autoJog && overrides['$date|${p.id}']?['start'] == null,
    );
    if (jogIndex >= 0) {
      final jog = result[jogIndex];
      var end = 1050, start = 1020;
      final busy =
          result
              .where(
                (p) => p.id != jog.id && !p.allDay && p.status != 'skipped',
              )
              .toList();
      for (var n = 0; n <= busy.length; n++) {
        final collisions =
            busy.where((p) => p.start < end && p.end > start).toList();
        if (collisions.isEmpty) break;
        end = collisions.map((p) => p.start).reduce((a, b) => a < b ? a : b);
        start = end - 30;
      }
      if (start >= 0) {
        result[jogIndex] = jog.withChanges({
          'start': timeKey(start),
          'end': timeKey(end),
        }, shifted: start != 1020);
      }
    }
    result.sort((a, b) {
      if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
      if (!a.allDay && a.start != b.start) return a.start.compareTo(b.start);
      return a.title.compareTo(b.title);
    });
    return result;
  }

  List<Plan> overlaps(Plan plan, List<Plan> day) =>
      plan.allDay || plan.status == 'skipped'
          ? []
          : day
              .where(
                (p) =>
                    p.id != plan.id &&
                    !p.allDay &&
                    p.status != 'skipped' &&
                    p.start < plan.end &&
                    p.end > plan.start,
              )
              .toList();
  Map<String, dynamic> toJson() => {
    'version': 1,
    'items': items.map((p) => p.toJson()).toList(),
    'overrides': overrides,
    'settings': {'showRecurringEventsInMonth': showRecurringEventsInMonth},
    'appliedEventUpdates': appliedEventUpdates.toList(),
  };
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
  factory Schedule.decode(String text) {
    if (text.length > 5000000) {
      throw const FormatException('Backup exceeds 5 MB');
    }
    final j = jsonDecode(text) as Map<String, dynamic>;
    if (j['version'] != 1) throw const FormatException('Unsupported backup');
    final items =
        (j['items'] as List)
            .map((p) => Plan.fromJson((p as Map).cast<String, dynamic>()))
            .toList();
    if (items.length > 10000 ||
        items.map((p) => p.id).toSet().length != items.length) {
      throw const FormatException('Invalid plans');
    }
    final patches = (j['overrides'] as Map).map(
      (k, v) => MapEntry(k as String, (v as Map).cast<String, dynamic>()),
    );
    const allowed = {
      'start',
      'end',
      'title',
      'category',
      'notes',
      'status',
      'deleted',
      'allDay',
      'timeTbc',
      'autoJog',
    };
    for (final entry in patches.entries) {
      if (entry.key.length < 12 ||
          entry.key[10] != '|' ||
          dateKey(parseDate(entry.key.substring(0, 10))) !=
              entry.key.substring(0, 10) ||
          !entry.value.keys.every(allowed.contains)) {
        throw const FormatException('Invalid day changes');
      }
      final plan =
          items.where((p) => p.id == entry.key.substring(11)).firstOrNull;
      if (plan != null) {
        final normalized = plan.withChanges(entry.value);
        if (entry.value.containsKey('category')) {
          entry.value['category'] = normalized.category;
        }
      }
    }
    final settings = j['settings'];
    if (settings != null &&
        (settings is! Map ||
            (settings['showRecurringEventsInMonth'] != null &&
                settings['showRecurringEventsInMonth'] is! bool))) {
      throw const FormatException('Invalid settings');
    }
    final appliedUpdates = j['appliedEventUpdates'] ?? <String>[];
    if (appliedUpdates is! List ||
        appliedUpdates.any((value) => value is! String)) {
      throw const FormatException('Invalid event updates');
    }
    return Schedule(items, patches)
      ..showRecurringEventsInMonth =
          (settings?['showRecurringEventsInMonth'] as bool?) ?? true
      ..appliedEventUpdates.addAll(appliedUpdates.cast<String>())
      ..applyEventUpdates();
  }
  factory Schedule.seed() {
    Plan routine(
      String id,
      String title,
      int start,
      int end,
      String category, {
      String repeat = 'daily',
      List<int> days = const [],
      bool jog = false,
    }) => Plan(
      id: id,
      title: title,
      date: '2026-11-17',
      start: start,
      end: end,
      category: category,
      repeat: repeat,
      weekdays: days,
      autoJog: jog,
    );
    Plan event(
      String id,
      String title,
      String date, {
      String? through,
      String category = 'personal',
      int start = 540,
      int end = 600,
      bool allDay = true,
      bool tbc = false,
      String notes = '',
    }) => Plan(
      id: id,
      title: title,
      date: date,
      endDate: through ?? date,
      kind: 'event',
      category: category,
      start: start,
      end: end,
      allDay: allDay,
      timeTbc: tbc,
      notes: notes,
    );
    return Schedule([
      routine('morning', 'Morning prayers', 360, 375, 'catholic'),
      routine('mass', 'Mass', 390, 420, 'catholic'),
      routine('house', 'Organize the house', 540, 600, 'home'),
      routine('basement', 'Organize the basement', 600, 660, 'home'),
      routine('gianna', 'Teach Gianna', 660, 720, 'family'),
      routine('angelus', 'Angelus', 720, 725, 'catholic'),
      routine('development', 'App development', 840, 900, 'work'),
      routine('jog', 'Jog', 1020, 1050, 'exercise', jog: true),
      routine('rosary', 'Rosary', 1110, 1140, 'catholic'),
      routine('evening', 'Evening prayers', 1230, 1245, 'catholic'),
      routine(
        'adoration-wed',
        'Adoration',
        1050,
        1110,
        'catholic',
        repeat: 'weekly',
        days: [3],
      ),
      routine(
        'direction',
        'Spiritual direction',
        870,
        930,
        'catholic',
        repeat: 'weekly',
        days: [5],
      ),
      routine(
        'adoration-fri',
        'Adoration',
        960,
        1020,
        'catholic',
        repeat: 'weekly',
        days: [5],
      ),
      event(
        'sister-trip',
        'Trip with my sister',
        '2026-11-28',
        through: '2026-12-01',
        category: 'family',
        notes: 'Return on the morning of 1 December. Travel times to confirm.',
      ),
      event(
        'grandparents',
        'Grandparents arrive from Ireland',
        '2026-12-01',
        category: 'family',
        tbc: true,
        notes: 'Arrival in South Africa. Time to confirm.',
      ),
      event(
        'ev-opening',
        'EV presentation: opening',
        '2026-12-01',
        category: 'work',
        allDay: false,
        start: 960,
        end: 1110,
      ),
      event(
        'ev-reception',
        'EV reception',
        '2026-12-01',
        category: 'work',
        allDay: false,
        start: 1110,
        end: 1290,
      ),
      event(
        'ev-days',
        'EV presentation',
        '2026-12-02',
        through: '2026-12-03',
        category: 'work',
        tbc: true,
        notes: 'Times for 2 and 3 December to confirm.',
      ),
      event(
        'ev-close',
        'EV presentation: closes 2pm',
        '2026-12-04',
        category: 'work',
        tbc: true,
        notes: 'Closes at 14:00. Start time to confirm.',
      ),
      event(
        'confirmation',
        'Confirmation (evening)',
        '2026-12-04',
        category: 'catholic',
        tbc: true,
        notes: 'Evening; exact time to confirm.',
      ),
    ])..applyEventUpdates();
  }
}
