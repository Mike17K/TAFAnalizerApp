class AthleteProfile {
  final String name;
  final double weightKg;
  final String? deviceMode; // 'phone' or bt device address

  const AthleteProfile({
    required this.name,
    required this.weightKg,
    this.deviceMode,
  });

  AthleteProfile copyWith({
    String? name,
    double? weightKg,
    String? deviceMode,
  }) {
    return AthleteProfile(
      name: name ?? this.name,
      weightKg: weightKg ?? this.weightKg,
      deviceMode: deviceMode ?? this.deviceMode,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'weightKg': weightKg,
        'deviceMode': deviceMode,
      };

  factory AthleteProfile.fromJson(Map<String, dynamic> json) => AthleteProfile(
        name: json['name'] as String,
        weightKg: (json['weightKg'] as num).toDouble(),
        deviceMode: json['deviceMode'] as String?,
      );
}
