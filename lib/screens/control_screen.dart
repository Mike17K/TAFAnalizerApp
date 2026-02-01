import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/bluetooth/bluetooth_bloc.dart';
import '../blocs/bluetooth/bluetooth_event.dart';
import '../blocs/bluetooth/bluetooth_state.dart';
import '../widgets/message_display.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  // Button states: 0 = show START, 1 = show STOP, 2 = show DATA
  int _buttonState = 0;

  Future<bool> _onWillPop(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect & Exit?'),
        content: const Text('Going back will disconnect from the device. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              context.read<BluetoothBloc>().add(DisconnectEvent());
              // Reset button state when disconnecting
              setState(() {
                _buttonState = 0;
              });
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showDisconnectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect?'),
        content: const Text('Do you want to disconnect from the device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<BluetoothBloc>().add(DisconnectEvent());
              Navigator.of(context).pop();
              // Reset button state when disconnecting
              setState(() {
                _buttonState = 0;
              });
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }

  void _onStartPressed(BuildContext context) {
    context.read<BluetoothBloc>().add(SendCommandEvent('START'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('START command sent'),
        duration: Duration(seconds: 1),
      ),
    );
    setState(() {
      _buttonState = 1; // Show STOP button
    });
  }

  void _onStopPressed(BuildContext context) {
    context.read<BluetoothBloc>().add(SendCommandEvent('STOP'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('STOP command sent'),
        duration: Duration(seconds: 1),
      ),
    );
    setState(() {
      _buttonState = 2; // Show DATA button
    });
  }

  void _onDataPressed(BuildContext context) {
    context.read<BluetoothBloc>().add(SendCommandEvent('DATA'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('DATA command sent'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop(context);
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Device Control'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back (Disconnect)',
            onPressed: () async {
              if (await _onWillPop(context)) {
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              }
            },
          ),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
                  case 'disconnect':
                    _showDisconnectDialog(context);
                    break;
                  case 'change_device':
                    _onWillPop(context).then((shouldPop) {
                      if (shouldPop && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    });
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'change_device',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz),
                      SizedBox(width: 8),
                      Text('Change Device'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'disconnect',
                  child: Row(
                    children: [
                      Icon(Icons.bluetooth_disabled),
                      SizedBox(width: 8),
                      Text('Disconnect'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
          body: Column(
          children: [
            BlocBuilder<BluetoothBloc, BluetoothState>(
              builder: (context, state) {
                if (state is BluetoothConnected) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                      children: [
                        Icon(
                          Icons.bluetooth_connected,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Connected to ${state.device.name ?? state.device.address}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'ONLINE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'Control Commands',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    ),
                    const SizedBox(height: 16),
                    // Dynamic button based on state
                    if (_buttonState == 0) ...[
                      // Show START button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _onStartPressed(context),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ] else if (_buttonState == 1) ...[
                      // Show STOP button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _onStopPressed(context),
                          icon: const Icon(Icons.stop),
                          label: const Text('Stop'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ] else if (_buttonState == 2) ...[
                      // Show DATA button
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () => _onDataPressed(context),
                              icon: const Icon(Icons.data_usage),
                              label: const Text('Data'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Optional restart button
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _buttonState = 0; // Reset to START
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Ready to start again'),
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Restart Sequence'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.message_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Received Messages',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Latest 1000',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
            const Expanded(
              child: MessageDisplay(),
            ),
          ],
        ),
      ),
    );
  }
}