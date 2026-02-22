import 'package:hydrated_bloc/hydrated_bloc.dart';
import '../../models/athlete_profile.dart';
import 'profile_event.dart';
import 'profile_state.dart';

class ProfileBloc extends HydratedBloc<ProfileEvent, ProfileState> {
  ProfileBloc() : super(ProfileEmpty()) {
    on<SaveProfileEvent>(_onSave);
    on<UpdateDeviceModeEvent>(_onUpdateDeviceMode);
  }

  void _onSave(SaveProfileEvent event, Emitter<ProfileState> emit) {
    emit(ProfileLoaded(event.profile));
  }

  void _onUpdateDeviceMode(
      UpdateDeviceModeEvent event, Emitter<ProfileState> emit) {
    if (state is ProfileLoaded) {
      final profile = (state as ProfileLoaded).profile;
      emit(ProfileLoaded(profile.copyWith(deviceMode: event.deviceMode)));
    }
  }

  @override
  ProfileState? fromJson(Map<String, dynamic> json) {
    try {
      if (json['profile'] == null) return ProfileEmpty();
      return ProfileLoaded(
          AthleteProfile.fromJson(json['profile'] as Map<String, dynamic>));
    } catch (_) {
      return ProfileEmpty();
    }
  }

  @override
  Map<String, dynamic>? toJson(ProfileState state) {
    if (state is ProfileLoaded) {
      return {'profile': state.profile.toJson()};
    }
    return {'profile': null};
  }
}
