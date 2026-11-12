import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../widgets/common.dart';
import 'chat_panel.dart';
import 'library_page.dart';
import 'settings_page.dart';
import 'tools_page.dart';
import 'workspace_page.dart';
import 'info_page.dart';
import 'onboarding_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (!state.onboardingCompleted) return OnboardingPage(state: state);
    if (state.infoPage != null) {
      return InfoPage(title: state.infoPage!, onBack: state.closeInfoPage);
    }
    return Shortcuts(
      shortcuts: <LogicalKeySet, Intent>{
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyO): const _OpenIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const _FindIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyP): const _PrintIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const _SaveIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.equal): const _ZoomInIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.minus): const _ZoomOutIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit0): const _ResetZoomIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const _EscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _OpenIntent: CallbackAction<_OpenIntent>(onInvoke: (_) { state.pickAndImport(); return null; }),
          _FindIntent: CallbackAction<_FindIntent>(onInvoke: (_) { state.readerSearchFocusNode.requestFocus(); return null; }),
          _PrintIntent: CallbackAction<_PrintIntent>(onInvoke: (_) { state.printSelected(); return null; }),
          _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (_) { state.saveLastPage(state.currentPage); return null; }),
          _ZoomInIntent: CallbackAction<_ZoomInIntent>(onInvoke: (_) { state.zoomBy(.1); return null; }),
          _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(onInvoke: (_) { state.zoomBy(-.1); return null; }),
          _ResetZoomIntent: CallbackAction<_ResetZoomIntent>(onInvoke: (_) { state.resetZoom(); return null; }),
          _EscapeIntent: CallbackAction<_EscapeIntent>(onInvoke: (_) { if (state.readerFullScreen) state.toggleReaderFullScreen(); return null; }),
        },
        child: Scaffold(
          body: SafeArea(
            child: state.readerFullScreen
                ? WorkspacePage(state: state)
                : Row(
                    children: [
                      _Sidebar(state: state),
                      Expanded(
                        child: Column(
                          children: [
                            _TopBar(state: state),
                            Expanded(child: _Content(state: state)),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _OpenIntent extends Intent { const _OpenIntent(); }
class _FindIntent extends Intent { const _FindIntent(); }
class _PrintIntent extends Intent { const _PrintIntent(); }
class _SaveIntent extends Intent { const _SaveIntent(); }
class _ZoomInIntent extends Intent { const _ZoomInIntent(); }
class _ZoomOutIntent extends Intent { const _ZoomOutIntent(); }
class _ResetZoomIntent extends Intent { const _ResetZoomIntent(); }
class _EscapeIntent extends Intent { const _EscapeIntent(); }

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final width = state.leftSidebarCollapsed ? 72 : state.leftSidebarWidth;
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          color: Theme.of(context).navigationRailTheme.backgroundColor,
          padding: EdgeInsets.symmetric(horizontal: state.leftSidebarCollapsed ? 10 : 14, vertical: 18),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, size: 19),
              ),
              if (!state.leftSidebarCollapsed) ...[
                const SizedBox(width: 10),
                const Expanded(child: Text('AI PDF Studio', style: TextStyle(fontWeight: FontWeight.w700))),
              ],
              IconButton(
                tooltip: state.leftSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
                onPressed: state.toggleSidebar,
                icon: Icon(state.leftSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _NavButton(icon: Icons.grid_view_rounded, label: 'Library', collapsed: state.leftSidebarCollapsed, selected: state.navigationIndex == 0, onTap: () => state.setNavigation(0)),
          _NavButton(icon: Icons.description_outlined, label: 'Recent', collapsed: state.leftSidebarCollapsed, selected: state.navigationIndex == 1, onTap: () => state.setNavigation(1)),
          _NavButton(icon: Icons.star_outline_rounded, label: 'Favorites', collapsed: state.leftSidebarCollapsed, selected: state.navigationIndex == 2, onTap: () => state.setNavigation(2)),
          _NavButton(icon: Icons.folder_open_outlined, label: 'Workspaces', collapsed: state.leftSidebarCollapsed, selected: state.navigationIndex == 3, onTap: () => state.setNavigation(3)),
          const SizedBox(height: 24),
          if (!state.leftSidebarCollapsed) const SectionLabel('Workspace'),
          if (!state.leftSidebarCollapsed) const SizedBox(height: 8),
          _NavButton(icon: Icons.picture_as_pdf_outlined, label: 'Reader', collapsed: state.leftSidebarCollapsed, selected: state.activeTool == 'Reader', onTap: () => state.setTool('Reader')),
          _NavButton(icon: Icons.auto_awesome_outlined, label: 'AI Assistant', collapsed: state.leftSidebarCollapsed, selected: state.activeTool == 'AI Assistant', onTap: () => state.setTool('AI Assistant')),
          _NavButton(icon: Icons.build_outlined, label: 'PDF Tools', collapsed: state.leftSidebarCollapsed, selected: state.activeTool == 'PDF Tools', onTap: () => state.setTool('PDF Tools')),
          const Spacer(),
          _NavButton(icon: Icons.settings_outlined, label: 'Settings', collapsed: state.leftSidebarCollapsed, selected: state.navigationIndex == 4, onTap: () => state.setNavigation(4)),
          const SizedBox(height: 12),
          if (!state.leftSidebarCollapsed) const Text('v0.1.0  ·  Local-first', style: TextStyle(fontSize: 11, color: Color(0xFF7E899D))),
        ],
      ),
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (details) => state.setSidebarWidth(state.leftSidebarWidth + details.delta.dx),
            child: const SizedBox(width: 5),
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.selected, required this.onTap, this.collapsed = false});

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? Theme.of(context).colorScheme.primary.withOpacity(.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: selected ? Theme.of(context).colorScheme.primary : null),
                if (!collapsed) ...[
                  const SizedBox(width: 11),
                  Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.w400))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: state.searchController,
              decoration: const InputDecoration(
                hintText: 'Search documents, pages, and notes',
                prefixIcon: Icon(Icons.search, size: 19),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Reading', icon: Icon(Icons.menu_book_outlined), label: Text('Reading')),
              ButtonSegment(value: 'AI', icon: Icon(Icons.auto_awesome_outlined), label: Text('AI')),
            ],
            selected: {state.workspaceMode},
            onSelectionChanged: (value) => state.setWorkspaceMode(value.first),
          ),
          const SizedBox(width: 8),
          AppIconButton(icon: Icons.light_mode_outlined, tooltip: 'Toggle theme', onPressed: state.toggleTheme),
          AppIconButton(icon: Icons.notifications_none_rounded, tooltip: 'Notifications', onPressed: () {}),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(.2),
            child: Text('Z', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.navigationIndex == 4) return SettingsPage(state: state);
    if (state.navigationIndex != 0 && state.activeTool == 'Reader') {
      return LibraryPage(state: state, filtered: true);
    }
    if (state.activeTool == 'AI Assistant' || state.workspaceMode == 'AI') return ChatPanel(state: state, fullPage: true);
    if (state.activeTool == 'PDF Tools') return ToolsPage(state: state);
    return state.selectedDocument == null ? LibraryPage(state: state) : WorkspacePage(state: state);
  }
}
