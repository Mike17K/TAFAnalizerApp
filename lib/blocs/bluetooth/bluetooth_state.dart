import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bt;

abstract class BluetoothState {}

class BluetoothInitial extends BluetoothState {}

class BluetoothScanning extends BluetoothState {}

class BluetoothDevicesFound extends BluetoothState {
  final List<bt.BluetoothDevice> devices;
  BluetoothDevicesFound(this.devices);
}

class BluetoothConnecting extends BluetoothState {}

class BluetoothConnected extends BluetoothState {
  final bt.BluetoothDevice device;
  BluetoothConnected(this.device);
}

class BluetoothDisconnected extends BluetoothState {}

class BluetoothError extends BluetoothState {
  final String message;
  BluetoothError(this.message);
}

class BluetoothNotEnabled extends BluetoothState {}

class BluetoothMessagesReceived extends BluetoothState {
  final List<String> messages;
  BluetoothMessagesReceived(this.messages);
}
