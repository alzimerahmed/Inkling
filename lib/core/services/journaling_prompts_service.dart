/// Curated journaling prompts with a deterministic daily rotation.
///
/// Pure Dart so it is trivially testable: the prompt for a given date is
/// stable across app restarts and devices (day-of-year modulo list length).
/// The list is intentionally short and evergreen — quality over quantity.
class JournalingPromptsService {
  static const List<String> _prompts = [
    'What made you smile today?',
    'What is one thing you learned today?',
    'Describe a moment you want to remember from today.',
    'What are you grateful for right now?',
    'What challenged you today, and how did you respond?',
    'If today had a title, what would it be?',
    'What would you like to remember about this week a year from now?',
    'Who made a difference in your day today?',
    'What is something you did today that your future self will thank you for?',
    'What is on your mind tonight?',
    'Describe today using only three words — then explain why.',
    'What small win did you have today?',
    'What drained your energy today? What restored it?',
    'If you could redo one moment from today, which would it be?',
    'What are you looking forward to?',
    'What is a thought you keep coming back to lately?',
    'How did you take care of yourself today?',
    'What surprised you today?',
    'What is something you avoided today? Why?',
    'Write a note to yourself to read in one year.',
    'What was the best part of your day, and the hardest part?',
    'What did you notice today that you usually overlook?',
    'If your mood were weather today, what would the forecast be?',
    'What is one thing you want to do differently tomorrow?',
    'What is a memory this time of year always brings back?',
    'Who would you love to catch up with, and why?',
    'What did you create, help, or improve today?',
    'What are you proud of this week?',
    'What is something kind you witnessed recently?',
    'Where did your mind wander today?',
    'What is a decision you made today, big or small?',
    'What would make tomorrow a good day?',
  ];

  /// The prompt for [date] (same date → same prompt, forever).
  static String promptFor(DateTime date) {
    final int dayOfYear = date.difference(DateTime(date.year)).inDays;
    return _prompts[dayOfYear % _prompts.length];
  }

  static String todayPrompt() => promptFor(DateTime.now());

  static List<String> get all => _prompts;
}
