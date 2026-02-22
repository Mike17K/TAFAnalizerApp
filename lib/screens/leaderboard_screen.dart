import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/leaderboard/leaderboard_bloc.dart';
import '../blocs/leaderboard/leaderboard_event.dart';
import '../blocs/leaderboard/leaderboard_state.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Leaderboard',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) {
          final entries = state.sorted;

          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 80,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No entries yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete a session and submit your result to see it here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: entries.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return _LeaderboardCard(
                entry: entries[index],
                rank: index + 1,
              );
            },
          );
        },
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;

  const _LeaderboardCard({required this.entry, required this.rank});

  Color _rankColor(ColorScheme cs) {
    return switch (rank) {
      1 => const Color(0xFFFFD700), // gold
      2 => const Color(0xFFC0C0C0), // silver
      3 => const Color(0xFFCD7F32), // bronze
      _ => cs.outlineVariant,
    };
  }

  IconData _rankIcon() {
    return switch (rank) {
      1 => Icons.emoji_events,
      2 => Icons.emoji_events,
      3 => Icons.emoji_events,
      _ => Icons.leaderboard,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rColor = _rankColor(cs);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: entry.isValidated ? cs.primary.withOpacity(0.3) : cs.outlineVariant,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rank strip
            Container(
              width: 52,
              color: rColor.withOpacity(0.15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_rankIcon(), color: rColor, size: 22),
                  Text(
                    '#$rank',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: rColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.athleteName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (entry.isValidated)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified,
                                    size: 12, color: Colors.green),
                                const SizedBox(width: 3),
                                Text(
                                  'VALID',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: cs.errorContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'UNVALIDATED',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: cs.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _Chip(
                          icon: Icons.fitness_center,
                          color: cs.primary,
                          label:
                              '${entry.peakForceKg.toStringAsFixed(1)} kg force',
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          icon: Icons.speed,
                          color: cs.secondary,
                          label:
                              '${entry.peakAccelMs2.toStringAsFixed(2)} m/s²',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${entry.athleteWeightKg.toStringAsFixed(1)} kg bodyweight',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        Text(
                          _formatDate(entry.date),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                    if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"${entry.notes}"',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    entry.isValidated ? Icons.check_circle : Icons.check_circle_outline,
                    color: entry.isValidated ? Colors.green : cs.onSurfaceVariant,
                    size: 20,
                  ),
                  tooltip: entry.isValidated ? 'Remove validation' : 'Mark as valid',
                  onPressed: () => context.read<LeaderboardBloc>().add(
                        ValidateEntryEvent(
                          entryId: entry.id,
                          isValid: !entry.isValidated,
                        ),
                      ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: cs.error.withOpacity(0.7), size: 20),
                  tooltip: 'Delete',
                  onPressed: () =>
                      _confirmDelete(context, entry),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, LeaderboardEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text(
            'Remove ${entry.athleteName}\'s ${entry.peakForceKg.toStringAsFixed(1)} kg record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () {
              context
                  .read<LeaderboardBloc>()
                  .add(DeleteEntryEvent(entry.id));
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _Chip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
