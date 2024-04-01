class OpenAiOption {
  Character character;
  List<String> guidance;
  bool log;

  OpenAiOption({
    required this.character,
    required this.guidance,
    required this.log,
  });
}

enum Character {
  house('Respond like House in the famous tv series'),
  funny('Answer in funny way'),
  none('none'),
  ;

  final String characterPrompt;

  const Character(this.characterPrompt);
}
