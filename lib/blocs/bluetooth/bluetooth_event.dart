import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bt;

abstract class BluetoothEvent {}

class ScanDevicesEvent extends BluetoothEvent {}

class ConnectToDeviceEvent extends BluetoothEvent {
  final bt.BluetoothDevice device;
  ConnectToDeviceEvent(this.device);
}

class SendCommandEvent extends BluetoothEvent {
  final String command;
  SendCommandEvent(this.command);
}

class DisconnectEvent extends BluetoothEvent {}

class ListenForMessagesEvent extends BluetoothEvent {}

class AdapterOnEvent extends BluetoothEvent {}

class AdapterOffEvent extends BluetoothEvent {}
