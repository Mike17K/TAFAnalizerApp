import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/bluetooth/bluetooth_state.dart';
import '../blocs/bluetooth/bluetooth_bloc.dart';

class MessageDisplay extends StatelessWidget {
  const MessageDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BluetoothBloc, BluetoothState>(
      builder: (context, state) {
        List<String> messages = [];
        if (state is BluetoothMessagesReceived) {
          messages = state.messages;
        }
        
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Waiting for Bluetooth data...',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final isRecent = index >= messages.length - 5;
            return Card(
              elevation: isRecent ? 2 : 0,
              color: isRecent ? null : Theme.of(context).colorScheme.surfaceContainerLow,
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(
                  messages[index],
                  style: TextStyle(
                    fontWeight: isRecent ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
                trailing: isRecent
                    ? Icon(
                        Icons.fiber_new,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }
}