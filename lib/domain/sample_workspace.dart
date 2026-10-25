import 'clock.dart';
import 'planning.dart';

Map<String, Map<String, dynamic>> sampleWorkspace(ZoneClock clock) {
  final now = clock.now();
  final today = clock.day(now);
  final records = <Map<String, dynamic>>[
    {
      'id': 'settings',
      'kind': 'settings',
      'zone': clock.name,
      'weeklyMinor': 25000,
    },
    {
      'id': 'sample-project',
      'kind': 'project',
      'title': 'A calmer study week',
      'body': 'Fictional example project',
    },
    {
      ...PlanTask(
        id: 'sample-task',
        title: 'Finish the assignment outline',
        minutes: 90,
        deadline: clock.parse(
          '${clock.day(now.add(const Duration(days: 2)))} 17:00',
        ),
        priority: 4,
      ).toJson(),
      'kind': 'task',
      'projectId': 'sample-project',
    },
    {
      ...PlanTask(
        id: 'sample-recall',
        title: 'Practise linked lists',
        minutes: 60,
        deadline: clock.parse(
          '${clock.day(now.add(const Duration(days: 3)))} 17:00',
        ),
      ).toJson(),
      'kind': 'task',
    },
    {
      ...PlanBlock(
        id: 'sample-lecture',
        title: 'Data structures lecture',
        start: clock.parse('$today 10:30'),
        end: clock.parse('$today 11:30'),
        fixed: true,
      ).toJson(),
      'kind': 'block',
    },
    {
      'id': 'sample-habit',
      'kind': 'habit',
      'title': 'Read a little',
      'minutes': 15,
      'weekdays': [1, 2, 3, 4, 5],
      'days': [],
    },
    {
      'id': 'sample-course',
      'kind': 'course',
      'title': 'Data structures',
      'body': 'Synthetic course notes for local testing.',
    },
    {
      'id': 'sample-note',
      'kind': 'note',
      'title': 'Retrieval practice',
      'source': 'Synthetic LifeOS learning fixture',
      'reference': 'Example paragraph, not a quotation from a book',
      'body': 'Close the notes and explain the idea from memory. Compare your explanation with the source, identify missing steps, and review later.',
      'courseId': 'sample-course',
      'reviewDate': today,
    },
    {
      'id': 'sample-food',
      'kind': 'nutrition',
      'date': today,
      'title': 'Example lunch',
      'meal': 'Lunch',
      'calories': 520,
      'protein': 25,
      'carbs': 60,
      'fat': 20,
      'partial': true,
      'source': 'Synthetic fixture',
    },
    {
      'id': 'sample-expense',
      'kind': 'expense',
      'title': 'Example groceries',
      'date': today,
      'minor': 4500,
      'category': 'Food',
      'paid': true,
      'source': 'Synthetic fixture',
    },
    {
      'id': 'sample-measurement',
      'kind': 'measurement',
      'title': 'Weight',
      'date': today,
      'value': 70.0,
      'unit': 'kg',
      'source': 'Synthetic fixture',
    },
    {
      'id': 'sample-measurement-previous',
      'kind': 'measurement',
      'title': 'Weight',
      'date': clock.day(now.subtract(const Duration(days: 1))),
      'value': 70.2,
      'unit': 'kg',
      'source': 'Synthetic fixture',
    },
    {
      'id': 'sample-workout',
      'kind': 'workout',
      'title': 'Example strength session',
      'exercise': 'Example squat',
      'session': 'sample-session',
      'start': clock.parse('$today 17:00').toIso8601String(),
      'end': clock.parse('$today 18:00').toIso8601String(),
      'setType': 'normal',
      'weightKg': 40,
      'reps': 8,
      'rpe': null,
      'source': 'Synthetic fixture',
    },
  ];
  return {
    for (final record in records) record['id']: {...record, 'demo': true},
  };
}
