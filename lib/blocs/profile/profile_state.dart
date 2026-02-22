import '../../models/athlete_profile.dart';

abstract class ProfileState {}

class ProfileEmpty extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final AthleteProfile profile;
  ProfileLoaded(this.profile);
}
