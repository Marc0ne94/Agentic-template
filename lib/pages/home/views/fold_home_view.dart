import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/material.dart';
import '../../../features/github_repository/github_repository.dart';
import '../../../features/sample_action/sample_action.dart';
import '../../../shared/shared.dart';

/// Dual-pane master-detail layout optimized for unfolded foldable devices and tablets.
///
/// When the device reports a vertical hinge or fold, the panes are split along
/// it so no content sits underneath; otherwise a 5:6 split is used.
class FoldHomeView extends StatelessWidget {
  const FoldHomeView({super.key});

  static const masterPaneKey = ValueKey('fold-master-pane');

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final hinge = _hingeWithin(context, constraints.maxWidth);

        if (hinge != null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                key: masterPaneKey,
                width: hinge.left,
                child: const _MasterPane(),
              ),
              SizedBox(width: hinge.width),
              const Expanded(child: _DetailPane()),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(
              key: masterPaneKey,
              flex: 5,
              child: _MasterPane(),
            ),
            // Subtle Hinge / Fold Divider Line
            VerticalDivider(
              width: 1.0,
              thickness: 1.0,
              color: palette.border,
            ),
            const Expanded(
              flex: 6,
              child: _DetailPane(),
            ),
          ],
        );
      },
    );
  }

  /// Horizontal position and width of a vertical hinge or fold that crosses
  /// this view, in the view's own coordinates.
  static ({double left, double width})? _hingeWithin(
    BuildContext context,
    double viewWidth,
  ) {
    // The view fills the space to the right of the navigation rail, so its
    // left edge sits at (screen width - view width) in display coordinates.
    final viewLeft = MediaQuery.sizeOf(context).width - viewWidth;

    for (final feature in MediaQuery.displayFeaturesOf(context)) {
      final isSeparator = feature.type == DisplayFeatureType.hinge ||
          feature.type == DisplayFeatureType.fold;
      final bounds = feature.bounds;
      final left = bounds.left - viewLeft;
      if (isSeparator &&
          bounds.height > bounds.width &&
          left > 0 &&
          left + bounds.width < viewWidth) {
        return (left: left, width: bounds.width);
      }
    }
    return null;
  }
}

/// Master / navigation side pane.
class _MasterPane extends StatelessWidget {
  const _MasterPane();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      children: [
        AppCard(
          backgroundColor: palette.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.laptop_chromebook_rounded,
                    color: palette.accent,
                    size: 20,
                  ),
                  const SizedBox(width: AppTokens.spaceSm),
                  Expanded(
                    child: Text(
                      'Foldable Tier (Dual Pane)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                'Optimized for foldable devices when unfolded (600px - 1023px). The screen partitions into master and detail surfaces, split along the hinge when the device reports one.',
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppTokens.spaceMd),

        // Architectural overview
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Architecture',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: AppTokens.spaceSm),
              const StatusBadge(
                label: 'Zero Coupling Across Slices',
                tone: BadgeTone.success,
                icon: Icons.check_circle_rounded,
              ),
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                'Feature slices communicate strictly through entity models or page/widget composition.',
                style: TextStyle(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Detail / action pane.
class _DetailPane extends StatelessWidget {
  const _DetailPane();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      children: const [
        GithubRepositoryCard(),
        SizedBox(height: AppTokens.spaceMd),
        ActionTriggerCard(),
      ],
    );
  }
}
