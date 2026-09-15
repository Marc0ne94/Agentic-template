import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/github_repository/github_repository.dart';
import '../../../features/sample_action/sample_action.dart';
import '../../../shared/shared.dart';

/// Optimized, glanceable smartwatch interface designed for circular Wear OS displays.
class WearableHomeView extends ConsumerWidget {
  const WearableHomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counterState = ref.watch(counterProvider);
    final controller = ref.read(counterProvider.notifier);
    final palette = AppPalette.of(context);

    final circularPadding = WearableUtils.getSafeCircularPadding(context);

    return Scaffold(
      backgroundColor: palette.canvas,
      body: Center(
        child: Padding(
          padding: circularPadding,
          // Keep touch targets readable while scrolling inside the circular inset.
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Watch Glanceable Header
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Icon(
                      Icons.watch_rounded,
                      size: 14,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'WATCH VIEW',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Large Glanceable Counter Digit
                Text(
                  '${counterState.count}',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: palette.textPrimary,
                    height: 1.0,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Taps recorded',
                  style: TextStyle(
                    fontSize: 10,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),

                // Watch Quick Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      iconSize: 28,
                      color: palette.textSecondary,
                      onPressed:
                          counterState.count > 0 ? controller.decrement : null,
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      customBorder: const CircleBorder(),
                      onTap: controller.increment,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: palette.actionBg,
                          boxShadow: AppTokens.floatingShadow,
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          size: 24,
                          color: palette.actionFg,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.spaceMd),
                const GithubRepositoryCard(compact: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
