import '../../models/leaderboard_entry.dart';

abstract class LeaderboardEvent {}

class AddEntryEvent extends LeaderboardEvent {
  final LeaderboardEntry entry;
  AddEntryEvent(this.entry);
}

class ValidateEntryEvent extends LeaderboardEvent {
  final String entryId;
  final bool isValid;
  final String? notes;
  ValidateEntryEvent({required this.entryId, required this.isValid, this.notes});
}

class DeleteEntryEvent extends LeaderboardEvent {
  final String entryId;
  DeleteEntryEvent(this.entryId);
}
