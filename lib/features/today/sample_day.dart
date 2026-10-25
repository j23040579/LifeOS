/// Synthetic fixtures only. These are not imported personal records.
enum DayPreview { ready, loading, empty, error }

class SamplePriority {
  const SamplePriority(this.id, this.title, this.detail, this.category);

  final String id;
  final String title;
  final String detail;
  final String category;
}

class SampleBlock {
  const SampleBlock(this.time, this.title, this.detail, {this.priorityId});

  final String time;
  final String title;
  final String detail;
  final String? priorityId;
  bool get isFixed => priorityId == null;
}

abstract final class SampleDay {
  static const date = 'Monday, 26 October 2026';
  static const priorities = [
    SamplePriority('assignment', 'Finish the assignment outline',
        '90 min · Due Tue, 27 Oct', 'Study'),
    SamplePriority('revision', 'Practise linked lists',
        '60 min · Recall, trace, then code', 'Learn'),
    SamplePriority('training', 'Make time for strength',
        '60 min · Flexible training block', 'Wellbeing'),
  ];

  static const blocks = [
    SampleBlock('08:30–10:00', 'Assignment outline', 'Study · Flexible',
        priorityId: 'assignment'),
    SampleBlock('10:30–11:30', 'Data structures lecture', 'University · Fixed'),
    SampleBlock('12:00–13:00', 'Lunch with a friend', 'Personal · Fixed'),
    SampleBlock('14:00–15:00', 'Linked-list practice', 'Learn · Flexible',
        priorityId: 'revision'),
    SampleBlock('17:00–18:00', 'Strength session', 'Wellbeing · Flexible',
        priorityId: 'training'),
  ];
}
