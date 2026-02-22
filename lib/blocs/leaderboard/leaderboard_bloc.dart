import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../models/leaderboard_entry.dart';
import 'leaderboard_event.dart';
import 'leaderboard_state.dart';

class LeaderboardBloc
    extends HydratedBloc<LeaderboardEvent, LeaderboardState> {
  LeaderboardBloc() : super(const LeaderboardState()) {
    on<AddEntryEvent>(_onAdd);
    on<ValidateEntryEvent>(_onValidate);
    on<DeleteEntryEvent>(_onDelete);
  }

  void _onAdd(AddEntryEvent event, Emitter<LeaderboardState> emit) {
    emit(state.copyWith(entries: [...state.entries, event.entry]));
  }

  void _onValidate(ValidateEntryEvent event, Emitter<LeaderboardState> emit) {
    final updated = state.entries.map((e) {
      if (e.id == event.entryId) {
        return e.copyWith(isValidated: event.isValid, notes: event.notes);
      }
      return e;
    }).toList();
    emit(state.copyWith(entries: updated));
  }

  void _onDelete(DeleteEntryEvent event, Emitter<LeaderboardState> emit) {
    emit(state.copyWith(
        entries: state.entries.where((e) => e.id != event.entryId).toList()));
  }

  @override
  LeaderboardState? fromJson(Map<String, dynamic> json) {
    try {
      final list = (json['entries'] as List? ?? [])
          .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      return LeaderboardState(entries: list);
    } catch (_) {
      return const LeaderboardState();
    }
  }

  @override
  Map<String, dynamic>? toJson(LeaderboardState state) {
    return {'entries': state.entries.map((e) => e.toJson()).toList()};
  }
}
