import '../models/conversation.dart';

/// Roleplay settings offered on the practice screen.
abstract final class ScenarioCatalog {
  static const standard = <Scenario>[
    Scenario(
      id: 'free_chat',
      title: 'Free Conversation',
      description: 'Talk about anything on your mind',
      emoji: '💬',
      openingLine:
          "Hey! Great to see you again. What's been on your mind today?",
      suggestions: [
        "I want to talk about my day",
        "Let's discuss movies",
        'Ask me anything',
      ],
    ),
    Scenario(
      id: 'restaurant',
      title: 'Ordering Food at a Restaurant',
      description: 'Order, ask questions, handle the bill',
      emoji: '☕',
      openingLine:
          "Good evening, welcome to Spice Garden! Table for one? "
          "Here's the menu — can I get you something to drink first?",
      suggestions: [
        'Just water, please',
        'What do you recommend?',
        'Can I see the menu?',
      ],
    ),
    Scenario(
      id: 'interview',
      title: 'Job Interview Practice',
      description: 'Answer common interview questions',
      emoji: '💼',
      openingLine:
          "Thanks for coming in today. Let's start simple — "
          "tell me a little about yourself.",
      suggestions: [
        "I'm a final-year student",
        'I work as a developer',
        'Where should I start?',
      ],
    ),
    Scenario(
      id: 'weekend',
      title: 'Talking About My Weekend',
      description: 'Practise past tense naturally',
      emoji: '✈️',
      openingLine:
          "Morning! So — how was your weekend? Did you do anything fun?",
      suggestions: [
        'I went to my cousin\'s place',
        'I mostly rested',
        'I watched a great film',
      ],
    ),
    Scenario(
      id: 'shopping',
      title: 'Shopping for Clothes',
      description: 'Sizes, prices, asking for help',
      emoji: '🛍️',
      openingLine:
          "Hi there! Let me know if you need any help finding a size.",
      suggestions: [
        'Do you have this in medium?',
        "I'm just looking, thanks",
        'How much is this?',
      ],
    ),
    Scenario(
      id: 'doctor',
      title: 'At the Doctor',
      description: 'Describe symptoms clearly',
      emoji: '🩺',
      openingLine:
          "Come in, take a seat. So, what seems to be the problem today?",
      suggestions: [
        "I've had a headache for two days",
        'I think I have a fever',
        "My throat hurts",
      ],
    ),
    Scenario(
      id: 'airport',
      title: 'At the Airport',
      description: 'Check-in, security, directions',
      emoji: '🛫',
      openingLine:
          "Good morning! May I see your passport and booking reference, please?",
      proOnly: true,
      suggestions: [
        'Here you go',
        'I have one bag to check in',
        'Is the flight on time?',
      ],
    ),
    Scenario(
      id: 'presentation',
      title: 'Giving a Presentation',
      description: 'Open, explain, handle questions',
      emoji: '📊',
      openingLine:
          "The room's ready when you are. Whenever you'd like to begin — "
          "just introduce yourself and your topic.",
      proOnly: true,
      suggestions: [
        'Good morning everyone',
        'Today I want to talk about…',
        'Can I have a moment?',
      ],
    ),
  ];

  static const genZ = <Scenario>[
    Scenario(
      id: 'gz_group_chat',
      title: 'Group Chat Energy',
      description: 'Keep up with fast, casual texting talk',
      emoji: '📱',
      mode: 'genZ',
      openingLine:
          "yooo finally you're here 😭 we were just talking about that new "
          "series — have you watched it yet or nah?",
      suggestions: ['not yet lol', 'omg yes it slaps', 'wait what series'],
    ),
    Scenario(
      id: 'gz_hype',
      title: 'Hyping Up a Friend',
      description: 'Compliments that sound natural, not cringe',
      emoji: '🔥',
      mode: 'genZ',
      openingLine:
          "ok be honest — does this fit go hard or should I change? 😩",
      suggestions: ['that fit is fire', 'lowkey change the shoes', 'no cap you ate'],
    ),
    Scenario(
      id: 'gz_gaming',
      title: 'Gaming Voice Chat',
      description: 'Callouts, banter, gaming vocabulary',
      emoji: '🎮',
      mode: 'genZ',
      openingLine:
          "bro that last round was rough 💀 you wanna queue one more or "
          "are you done for tonight?",
      suggestions: ['one more', 'im washed today', 'what happened last round'],
    ),
    Scenario(
      id: 'gz_social',
      title: 'Reacting to Posts',
      description: 'Comment like a native, not a bot',
      emoji: '💫',
      mode: 'genZ',
      openingLine:
          "just posted the trip pics!! what should I caption them, "
          "I'm so bad at this 😂",
      suggestions: ['keep it simple', 'something funny', 'let me think'],
    ),
    Scenario(
      id: 'gz_formal_switch',
      title: 'Casual to Formal Switch',
      description: 'Know when to drop the slang',
      emoji: '🎭',
      mode: 'genZ',
      proOnly: true,
      openingLine:
          "Okay, quick challenge: I'll say something casually, and you say it "
          "back the way you'd write it in an email. Ready? "
          "\"ngl this deadline is kinda impossible\"",
      suggestions: ['ready', 'give me a hint', 'ok lets go'],
    ),
  ];

  static List<Scenario> forMode(String mode) =>
      mode == 'genZ' ? genZ : standard;

  static Scenario byId(String id) {
    for (final s in [...standard, ...genZ]) {
      if (s.id == id) return s;
    }
    return standard.first;
  }
}
