import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/profile/profile_bloc.dart';
import '../blocs/profile/profile_event.dart';
import '../blocs/profile/profile_state.dart';
import '../models/athlete_profile.dart';
import 'onboarding_screen.dart';
import 'recording_screen.dart';
import 'leaderboard_screen.dart';

class DeviceSelectionScreen extends StatelessWidget {
  const DeviceSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is! ProfileLoaded) {
          return const OnboardingScreen();
        }
        return _HomeScreen(profile: state.profile);
      },
    );
  }
}

class _HomeScreen extends StatelessWidget {
  final AthleteProfile profile;
  const _HomeScreen({required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isPhone = profile.deviceMode == null || profile.deviceMode == 'phone';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'TAF Analyzer',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard_outlined),
            tooltip: 'Leaderboard',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Edit Profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // Athlete card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.secondaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cs.primary,
                      child: Text(
                        profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                          Text(
                            '${profile.weightKg.toStringAsFixed(1)} kg body weight',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onPrimaryContainer.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.directions_run, color: cs.primary, size: 32),
                  ],
                ),
              ),

              const SizedBox(height: 32),
              Text(
                'SELECT INPUT DEVICE',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Phone option
              _DeviceCard(
                icon: Icons.smartphone,
                title: 'This Phone',
                subtitle: 'Use built-in accelerometer & gyroscope',
                selected: isPhone,
                onTap: () => context
                    .read<ProfileBloc>()
                    .add(UpdateDeviceModeEvent('phone')),
              ),
              const SizedBox(height: 12),
              // Bluetooth option
              _DeviceCard(
                icon: Icons.bluetooth,
                title: 'Bluetooth Device',
                subtitle: 'Connect to an external sensor',
                selected: !isPhone,
                badge: 'COMING SOON',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bluetooth device support coming soon. Using phone for now.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              const Spacer(),

              // Big start button
              FilledButton.icon(
                onPressed: isPhone
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => RecordingScreen(profile: profile)),
                        )
                    : null,
                icon: const Icon(Icons.play_circle_outline, size: 28),
                label: const Text('Start Session'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  textStyle: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isPhone
                    ? 'Secure the phone to your chest, then press Start'
                    : 'Select a device above to begin',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _DeviceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withOpacity(0.6)
              : cs.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected ? cs.primary : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: selected ? cs.onPrimary : cs.onSurface, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? cs.onPrimaryContainer
                                : cs.onSurface,
                          )),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onTertiaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      )),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: cs.primary, size: 22),
          ],
        ),
      ),
    );
  }
}
