class OpenAiOption {
  Character character;
  List<String> guidance;

  OpenAiOption({
    required this.character,
    required this.guidance,
  });
}

enum Character {
  house('Respond like House in the famous tv series'),
  funny('Answer in funny way'),
  ;

  final String characterPrompt;

  const Character(this.characterPrompt);
}
