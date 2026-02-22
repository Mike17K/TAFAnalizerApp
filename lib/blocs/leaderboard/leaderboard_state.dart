import '../../models/leaderboard_entry.dart';

class LeaderboardState {
  final List<LeaderboardEntry> entries;

  const LeaderboardState({this.entries = const []});

  LeaderboardState copyWith({List<LeaderboardEntry>? entries}) {
    return LeaderboardState(entries: entries ?? this.entries);
  }

  /// Sorted by peak force descending, validated entries first
  List<LeaderboardEntry> get sorted {
    final list = List<LeaderboardEntry>.from(entries);
    list.sort((a, b) {
      if (a.isValidated != b.isValidated) {
        return a.isValidated ? -1 : 1;
      }
      return b.peakForceKg.compareTo(a.peakForceKg);
    });
    return list;
  }
}
