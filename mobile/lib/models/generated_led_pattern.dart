class GeneratedLedPattern {
  final String name;
  final String mode;
  final int brightness;
  final int speed;
  final String primaryColor;
  final String secondaryColor;
  final List<List<int>> grid;
  final String description;

  const GeneratedLedPattern({
    required this.name,
    required this.mode,
    required this.brightness,
    required this.speed,
    required this.primaryColor,
    required this.secondaryColor,
    required this.grid,
    required this.description,
  });

  factory GeneratedLedPattern.fromJson(Map<String, dynamic> j) {
    final rawGrid = j['grid'] as List<dynamic>;
    return GeneratedLedPattern(
      name:           j['name']           as String,
      mode:           j['mode']           as String,
      brightness:     j['brightness']     as int,
      speed:          j['speed']          as int,
      primaryColor:   j['primaryColor']   as String,
      secondaryColor: j['secondaryColor'] as String,
      grid: rawGrid.map((row) =>
          (row as List<dynamic>).map((v) => v as int).toList()).toList(),
      description:    j['description']    as String,
    );
  }

  // Payload contract for the SENTIO Hat firmware
  Map<String, dynamic> toHatPayload() => {
    'mode':       mode,
    'brightness': brightness,
    'speed':      speed,
    'colors':     [primaryColor, secondaryColor],
    'pattern':    grid,
  };
}
