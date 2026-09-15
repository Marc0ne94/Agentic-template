import 'package:flutter/material.dart';
import '../../../features/device_simulator/device_simulator.dart';
import '../../../features/theme_toggle/theme_toggle.dart';
import '../../../shared/shared.dart';

class NavigationDestinationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavigationDestinationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Adaptive layout scaffold that seamlessly renders:
/// - A BottomNavigationBar on compact smartphones
/// - A NavigationRail on foldables, tablets, and desktop/web
/// - Header controls featuring the theme toggle and device simulator picker.
class AdaptiveScaffold extends StatefulWidget {
  final String title;
  final List<NavigationDestinationItem> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

  @override
  State<AdaptiveScaffold> createState() => _AdaptiveScaffoldState();
}

class _AdaptiveScaffoldState extends State<AdaptiveScaffold> {
  @override
  Widget build(BuildContext context) {
    final tier = Breakpoints.getTier(context);
    final isCompact = tier == ScreenTier.compact || tier == ScreenTier.wearable;
    final palette = AppPalette.of(context);

    // Compact layout (Phone / Fold-folded)
    if (isCompact) {
      return Scaffold(
        backgroundColor: palette.canvas,
        appBar: AppBar(
          backgroundColor: palette.surface,
          elevation: 0,
          title: Text(
            widget.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          actions: [
            const DeviceSimulatorPicker(compact: true),
            const SizedBox(width: 4),
            const ThemeToggleButton(showMenu: true),
            if (widget.actions != null) ...widget.actions!,
            const SizedBox(width: 8),
          ],
        ),
        body: widget.body,
        bottomNavigationBar: widget.destinations.length > 1
            ? NavigationBar(
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: widget.onDestinationSelected,
                backgroundColor: palette.surface,
                indicatorColor: palette.navIndicator,
                destinations: widget.destinations.map((d) {
                  return NavigationDestination(
                    icon: Icon(d.icon, size: 20),
                    selectedIcon: Icon(d.selectedIcon, size: 20),
                    label: d.label,
                  );
                }).toList(),
              )
            : null,
        floatingActionButton: widget.floatingActionButton,
      );
    }

    // Wide layout (Foldable unfolded, Tablet, Desktop, Web)
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(left: false, right: false, child: Row(
        children: [
          // Navigation Rail
          if (widget.destinations.length > 1)
            Container(
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(
                  right: BorderSide(color: palette.border, width: 1.0),
                ),
              ),
              child: NavigationRail(
                selectedIndex: widget.selectedIndex,
                onDestinationSelected: widget.onDestinationSelected,
                backgroundColor: Colors.transparent,
                labelType: NavigationRailLabelType.all,
                indicatorColor: palette.navIndicator,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppTokens.spaceMd),
                  child: Text(
                    widget.title.isNotEmpty ? widget.title[0] : 'A',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: palette.accent,
                    ),
                  ),
                ),
                destinations: widget.destinations.map((d) {
                  return NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(
                      d.label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Main Workspace Column
          Expanded(
            child: Column(
              children: [
                // Top Header Bar
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.spaceLg,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    border: Border(
                      bottom: BorderSide(color: palette.border, width: 1.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Bounded so a long title truncates instead of squeezing
                      // the header controls.
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.spaceMd),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // The chip row needs desktop width; foldables
                                // and tablets use the popup picker.
                                DeviceSimulatorPicker(
                                  compact: tier != ScreenTier.desktopWeb,
                                ),
                                const SizedBox(width: AppTokens.spaceSm),
                                const ThemeToggleButton(),
                                if (widget.actions != null) ...[
                                  const SizedBox(width: AppTokens.spaceSm),
                                  ...widget.actions!,
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Viewport
                Expanded(child: widget.body),
              ],
            ),
          ),
        ],
      )),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
