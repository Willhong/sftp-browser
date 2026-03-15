import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../services/server_store.dart';
import '../services/sftp_repository.dart';
import '../theme/app_theme.dart';
import 'file_browser_screen.dart';
import 'server_connection_screen.dart';
import 'server_list_screen.dart';

class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, this.serverStore, this.repository});

  final ServerStore? serverStore;
  final SftpRepository? repository;

  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late final ServerStore _serverStore = widget.serverStore ?? ServerStore();
  late final SftpRepository _repository = widget.repository ?? SftpRepository();

  final List<ServerProfile> _openProfiles = <ServerProfile>[];
  String? _selectedProfileId;

  int get _selectedContentIndex {
    final selectedProfileId = _selectedProfileId;
    if (selectedProfileId == null) {
      return 0;
    }

    final profileIndex = _openProfiles.indexWhere(
      (profile) => profile.id == selectedProfileId,
    );
    return profileIndex < 0 ? 0 : profileIndex + 1;
  }

  void _selectServersTab() {
    if (_selectedProfileId == null) {
      return;
    }

    setState(() {
      _selectedProfileId = null;
    });
  }

  void _openServerTab(ServerProfile profile) {
    final existingIndex = _openProfiles.indexWhere(
      (item) => item.id == profile.id,
    );

    setState(() {
      if (existingIndex < 0) {
        _openProfiles.add(profile);
      }
      _selectedProfileId = profile.id;
    });
  }

  void _closeServerTab(String profileId) {
    final closingIndex = _openProfiles.indexWhere(
      (profile) => profile.id == profileId,
    );
    if (closingIndex < 0) {
      return;
    }

    setState(() {
      final isSelected = _selectedProfileId == profileId;
      _openProfiles.removeAt(closingIndex);
      if (!isSelected) {
        return;
      }

      if (_openProfiles.isEmpty) {
        _selectedProfileId = null;
        return;
      }

      final nextIndex = closingIndex.clamp(0, _openProfiles.length - 1);
      _selectedProfileId = _openProfiles[nextIndex].id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _WorkspaceTabStrip(
              selectedProfileId: _selectedProfileId,
              openProfiles: _openProfiles,
              onSelectServers: _selectServersTab,
              onSelectProfile: (profileId) {
                setState(() {
                  _selectedProfileId = profileId;
                });
              },
              onCloseProfile: _closeServerTab,
            ),
            Divider(height: 1, color: AppTheme.separatorColor(theme)),
            Expanded(
              child: IndexedStack(
                index: _selectedContentIndex,
                children: [
                  ServerListScreen(
                    serverStore: _serverStore,
                    repository: _repository,
                    onOpenProfile: _openServerTab,
                  ),
                  for (final profile in _openProfiles)
                    KeyedSubtree(
                      key: ValueKey<String>('workspace-tab-${profile.id}'),
                      child: ServerConnectionScreen(
                        key: PageStorageKey<String>(
                          'server-connection-${profile.id}',
                        ),
                        profile: profile,
                        repository: _repository,
                        autoNavigate: false,
                        inlineBrowserBuilder:
                            (context, profile, session, initialState) =>
                                FileBrowserScreen(
                                  key: PageStorageKey<String>(
                                    'file-browser-${profile.id}',
                                  ),
                                  profile: profile,
                                  session: session,
                                  initialState: initialState,
                                  closeSessionOnDispose: false,
                                ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceTabStrip extends StatelessWidget {
  const _WorkspaceTabStrip({
    required this.selectedProfileId,
    required this.openProfiles,
    required this.onSelectServers,
    required this.onSelectProfile,
    required this.onCloseProfile,
  });

  final String? selectedProfileId;
  final List<ServerProfile> openProfiles;
  final VoidCallback onSelectServers;
  final ValueChanged<String> onSelectProfile;
  final ValueChanged<String> onCloseProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppTheme.chromeColor(theme),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              _WorkspaceTabChip(
                key: const ValueKey<String>('workspace-home-tab'),
                label: 'Servers',
                icon: Icons.dns_outlined,
                isSelected: selectedProfileId == null,
                onPressed: onSelectServers,
              ),
              for (final profile in openProfiles) ...[
                const SizedBox(width: 8),
                _WorkspaceTabChip(
                  key: ValueKey<String>('workspace-tab-chip-${profile.id}'),
                  label: profile.title,
                  icon: Icons.folder_open_outlined,
                  isSelected: selectedProfileId == profile.id,
                  onPressed: () => onSelectProfile(profile.id),
                  onClose: () => onCloseProfile(profile.id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTabChip extends StatelessWidget {
  const _WorkspaceTabChip({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onPressed,
    this.onClose,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onPressed;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor =
        isSelected
            ? colorScheme.primary.withValues(alpha: 0.12)
            : AppTheme.mutedSurfaceColor(
              theme,
              lightAlpha: 0.48,
              darkAlpha: 0.3,
            );
    final borderColor =
        isSelected
            ? colorScheme.primary.withValues(alpha: 0.28)
            : AppTheme.outlineSide(
              theme,
              lightAlpha: 0.56,
              darkAlpha: 0.28,
            ).color;
    final foregroundColor =
        isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.inputRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: foregroundColor),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color:
                          isSelected
                              ? colorScheme.onSurface
                              : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (onClose != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Tooltip(
                        message: 'Close $label',
                        child: Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: foregroundColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
