class LeaderboardEntry {
  final String id;
  final String athleteName;
  final double athleteWeightKg;
  final double peakForceKg;
  final double peakAccelMs2;
  final DateTime date;
  final bool isValidated;
  final String? notes;

  const LeaderboardEntry({
    required this.id,
    required this.athleteName,
    required this.athleteWeightKg,
    required this.peakForceKg,
    required this.peakAccelMs2,
    required this.date,
    this.isValidated = false,
    this.notes,
  });

  LeaderboardEntry copyWith({
    String? id,
    String? athleteName,
    double? athleteWeightKg,
    double? peakForceKg,
    double? peakAccelMs2,
    DateTime? date,
    bool? isValidated,
    String? notes,
  }) {
    return LeaderboardEntry(
      id: id ?? this.id,
      athleteName: athleteName ?? this.athleteName,
      athleteWeightKg: athleteWeightKg ?? this.athleteWeightKg,
      peakForceKg: peakForceKg ?? this.peakForceKg,
      peakAccelMs2: peakAccelMs2 ?? this.peakAccelMs2,
      date: date ?? this.date,
      isValidated: isValidated ?? this.isValidated,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'athleteName': athleteName,
        'athleteWeightKg': athleteWeightKg,
        'peakForceKg': peakForceKg,
        'peakAccelMs2': peakAccelMs2,
        'date': date.toIso8601String(),
        'isValidated': isValidated,
        'notes': notes,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        id: json['id'] as String,
        athleteName: json['athleteName'] as String,
        athleteWeightKg: (json['athleteWeightKg'] as num).toDouble(),
        peakForceKg: (json['peakForceKg'] as num).toDouble(),
        peakAccelMs2: (json['peakAccelMs2'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        isValidated: json['isValidated'] as bool? ?? false,
        notes: json['notes'] as String?,
      );
}
