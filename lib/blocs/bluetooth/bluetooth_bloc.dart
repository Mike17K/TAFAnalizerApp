import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as bt;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bluetooth_event.dart';
import 'bluetooth_state.dart';

class BluetoothBloc extends HydratedBloc<BluetoothEvent, BluetoothState> {
  bt.BluetoothConnection? _connection;
  StreamSubscription? _dataSubscription;
  StreamSubscription? _stateSubscription;
  final List<String> _messages = [];
  bt.BluetoothDevice? _connectedDevice;

  BluetoothBloc() : super(BluetoothInitial()) {
    on<ScanDevicesEvent>(_onScanDevices);
    on<ConnectToDeviceEvent>(_onConnectToDevice);
    on<SendCommandEvent>(_onSendCommand);
    on<DisconnectEvent>(_onDisconnect);
    on<ListenForMessagesEvent>(_onListenForMessages);
    on<AdapterOnEvent>(_onAdapterOn);
    on<AdapterOffEvent>(_onAdapterOff);

    // Monitor Bluetooth state
    _stateSubscription = bt.FlutterBluetoothSerial.instance.onStateChanged().listen((state) {
      if (state == bt.BluetoothState.STATE_ON) {
        add(AdapterOnEvent());
      } else if (state == bt.BluetoothState.STATE_OFF) {
        add(AdapterOffEvent());
      }
    });

    // Check initial state
    bt.FlutterBluetoothSerial.instance.isEnabled.then((isEnabled) {
      if (isEnabled != true) {
        add(AdapterOffEvent());
      }
    });
  }

  void _onScanDevices(ScanDevicesEvent event, Emitter<BluetoothState> emit) async {
    // Request permissions
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    var bluetoothScanStatus = await Permission.bluetoothScan.request();
    var locationStatus = await Permission.location.request();

    if (bluetoothConnectStatus.isDenied || bluetoothScanStatus.isDenied) {
      emit(BluetoothError("Bluetooth permissions denied. Please grant permissions in settings."));
      return;
    }
    
    if (locationStatus.isDenied) {
      emit(BluetoothError("Location permission is required for Bluetooth device discovery. Please grant in settings."));
      return;
    }

    // Check if Bluetooth is enabled
    bool? isEnabled = await bt.FlutterBluetoothSerial.instance.isEnabled;
    if (isEnabled != true) {
      emit(BluetoothNotEnabled());
      return;
    }

    emit(BluetoothScanning());
    
    try {
      // Get bonded (paired) devices - Classic Bluetooth
      List<bt.BluetoothDevice> devices = await bt.FlutterBluetoothSerial.instance.getBondedDevices();
      
      if (devices.isEmpty) {
        emit(BluetoothDevicesFound([]));
      } else {
        emit(BluetoothDevicesFound(devices));
      }
    } catch (e) {
      emit(BluetoothError("Scan failed: ${e.toString()}"));
    }
  }

  void _onConnectToDevice(ConnectToDeviceEvent event, Emitter<BluetoothState> emit) async {
    emit(BluetoothConnecting());
    
    try {
      // Close any existing connection
      await _connection?.close();
      await _dataSubscription?.cancel();
      
      // Wait a bit to ensure previous connection is fully closed
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Connect to device with timeout
      _connection = await bt.BluetoothConnection.toAddress(event.device.address)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception("Connection timeout. Please ensure the device is powered on and in range.");
            },
          );
      
      // Verify connection is established
      if (_connection == null || !_connection!.isConnected) {
        throw Exception("Failed to establish connection. Please try again.");
      }
      
      // Clear previous messages
      _messages.clear();
      _connectedDevice = event.device;
      
      emit(BluetoothConnected(event.device, messages: []));
      add(ListenForMessagesEvent());
    } catch (e) {
      String errorMessage = "Connection failed: ";
      
      if (e.toString().contains("timeout")) {
        errorMessage += "Device not responding. Please check if device is on and paired.";
      } else if (e.toString().contains("read failed")) {
        errorMessage += "Device disconnected. Please ensure device is powered on.";
      } else if (e.toString().contains("socket")) {
        errorMessage += "Unable to create connection. Please unpair and pair the device again.";
      } else {
        errorMessage += e.toString().replaceAll("Exception: ", "");
      }
      
      emit(BluetoothError(errorMessage));
    }
  }

  void _onSendCommand(SendCommandEvent event, Emitter<BluetoothState> emit) async {
    if (_connection == null || !_connection!.isConnected) {
      emit(BluetoothError("Not connected to device"));
      return;
    }
    
    try {
      // Send command with newline
      _connection!.output.add(Uint8List.fromList(utf8.encode('${event.command}\n')));
      await _connection!.output.allSent;
    } catch (e) {
      emit(BluetoothError("Send failed: ${e.toString()}"));
    }
  }

  void _onDisconnect(DisconnectEvent event, Emitter<BluetoothState> emit) async {
    await _dataSubscription?.cancel();
    await _connection?.close();
    _connection = null;
    _connectedDevice = null;
    _messages.clear();
    emit(BluetoothDisconnected());
  }

  void _onListenForMessages(ListenForMessagesEvent event, Emitter<BluetoothState> emit) async {
    if (_connection == null || !_connection!.isConnected || _connectedDevice == null) {
      return;
    }

    _dataSubscription = _connection!.input!.listen(
      (Uint8List data) {
        try {
          // Try to decode as UTF-8
          String message = utf8.decode(data);
          
          // Clean up the message (remove null characters, trim whitespace)
          message = message.replaceAll('\x00', '').trim();
          
          // Split by newlines in case multiple messages come at once
          List<String> messageLines = message.split('\n').where((line) => line.trim().isNotEmpty).toList();
          
          if (messageLines.isNotEmpty) {
            _messages.addAll(messageLines);
            
            // Keep only last 1000 messages
            if (_messages.length > 1000) {
              _messages.removeRange(0, _messages.length - 1000);
            }
            
            // Emit BluetoothConnected with updated messages
            emit(BluetoothConnected(_connectedDevice!, messages: List.from(_messages)));
            
            // Debug: print received messages
            print('Received ${messageLines.length} message(s): ${messageLines.join(", ")}');
          }
        } catch (e) {
          // Try alternative decoding if UTF-8 fails
          try {
            // Try Latin-1 decoding as fallback
            String message = latin1.decode(data);
            message = message.replaceAll('\x00', '').trim();
            
            List<String> messageLines = message.split('\n').where((line) => line.trim().isNotEmpty).toList();
            
            if (messageLines.isNotEmpty) {
              _messages.addAll(messageLines);
              
              if (_messages.length > 1000) {
                _messages.removeRange(0, _messages.length - 1000);
              }
              
              emit(BluetoothConnected(_connectedDevice!, messages: List.from(_messages)));
              
              print('Received ${messageLines.length} message(s) with Latin-1: ${messageLines.join(", ")}');
            }
          } catch (e2) {
            // If both decodings fail, log the raw data for debugging
            print('Failed to decode Bluetooth data: ${data.toString()}');
          }
        }
      },
      onDone: () {
        add(DisconnectEvent());
      },
      onError: (error) {
        emit(BluetoothError("Connection error: ${error.toString()}"));
        add(DisconnectEvent());
      },
    );
  }

  void _onAdapterOn(AdapterOnEvent event, Emitter<BluetoothState> emit) {
    if (state is BluetoothNotEnabled) {
      emit(BluetoothInitial());
    }
  }

  void _onAdapterOff(AdapterOffEvent event, Emitter<BluetoothState> emit) {
    emit(BluetoothNotEnabled());
  }

  @override
  BluetoothState? fromJson(Map<String, dynamic> json) {
    return BluetoothInitial();
  }

  @override
  Map<String, dynamic>? toJson(BluetoothState state) {
    return null;
  }

  @override
  Future<void> close() {
    _dataSubscription?.cancel();
    _stateSubscription?.cancel();
    _connection?.close();
    return super.close();
  }
}
