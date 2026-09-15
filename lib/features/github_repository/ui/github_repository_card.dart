import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/shared.dart';
import '../api/github_repository_client.dart';
import '../state/github_repository_provider.dart';

/// One public repository, with explicit loading, recovery and manual refresh.
class GithubRepositoryCard extends ConsumerWidget {
  const GithubRepositoryCard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = AppPalette.of(context);
    final repository = ref.watch(githubRepositoryProvider);
    final gap = compact ? AppTokens.spaceXs : AppTokens.spaceMd;

    return AppCard(
      padding: EdgeInsets.all(compact ? AppTokens.spaceSm : AppTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!compact) ...[
                Icon(Icons.code_rounded, color: palette.accent, size: 24),
                const SizedBox(width: AppTokens.spaceSm),
              ],
              Expanded(
                child: Text(
                  'GitHub project',
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: compact ? 12 : 16,
                    height: compact ? 1.2 : null,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: gap),
          repository.when(
            skipLoadingOnRefresh: false,
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  color: palette.accent,
                  backgroundColor: palette.surface,
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  'Loading repository…',
                  style: TextStyle(color: palette.textSecondary),
                ),
              ],
            ),
            error: (error, _) => Semantics(
              liveRegion: true,
              child: Text(
                error is GithubRepositoryException
                    ? error.message
                    : 'Could not load the repository. Please try again.',
                style: TextStyle(color: palette.errorFg, height: 1.4),
              ),
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  compact ? data.fullName.split('/').last : data.fullName,
                  semanticsLabel: data.fullName,
                  maxLines: compact ? 1 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: TextStyle(
                    fontSize: compact ? 12 : 20,
                    height: compact ? 1.2 : null,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                  ),
                ),
                if (!compact && data.description?.isNotEmpty == true) ...[
                  const SizedBox(height: AppTokens.spaceSm),
                  Text(
                    data.description!,
                    style: TextStyle(color: palette.textSecondary, height: 1.4),
                  ),
                ],
                SizedBox(height: gap),
                Wrap(
                  spacing: AppTokens.spaceSm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!compact)
                      Icon(Icons.star_rounded, color: palette.accent, size: 18),
                    Text(
                      '${data.stars} ${data.stars == 1 ? 'star' : 'stars'}',
                      style: TextStyle(
                        fontSize: compact ? 12 : null,
                        height: compact ? 1.2 : null,
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (!compact && data.pushedAt != null) ...[
                  const SizedBox(height: AppTokens.spaceSm),
                  Text(
                    'Last push · ${DateHelpers.formatShortDate(data.pushedAt!)}',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: gap),
          OutlinedButton(
            onPressed: repository.isLoading
                ? null
                : () => ref.invalidate(githubRepositoryProvider),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.textPrimary,
              side: BorderSide(color: palette.border),
              minimumSize: const Size(44, 44),
              padding: const EdgeInsets.all(AppTokens.spaceSm),
              shape: RoundedRectangleBorder(borderRadius: AppTokens.radiusMd),
            ),
            child: Text(repository.hasError ? 'Retry' : 'Refresh'),
          ),
        ],
      ),
    );
  }
}
