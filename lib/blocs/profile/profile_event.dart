import '../../models/athlete_profile.dart';

abstract class ProfileEvent {}

class SaveProfileEvent extends ProfileEvent {
  final AthleteProfile profile;
  SaveProfileEvent(this.profile);
}

class UpdateDeviceModeEvent extends ProfileEvent {
  final String deviceMode; // 'phone' or BT address
  UpdateDeviceModeEvent(this.deviceMode);
}
