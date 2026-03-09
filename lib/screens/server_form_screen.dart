import 'package:flutter/material.dart';

import '../models/server_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/section_card.dart';

class ServerFormScreen extends StatefulWidget {
  const ServerFormScreen({
    super.key,
    this.initialProfile,
  });

  final ServerProfile? initialProfile;

  bool get isEditing => initialProfile != null;

  @override
  State<ServerFormScreen> createState() => _ServerFormScreenState();
}

class _ServerFormScreenState extends State<ServerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _privateKeyController;
  late AuthType _authType;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _hostController = TextEditingController(text: profile?.host ?? '');
    _portController = TextEditingController(text: '${profile?.port ?? 22}');
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _passwordController = TextEditingController(text: profile?.password ?? '');
    _privateKeyController = TextEditingController(text: profile?.privateKey ?? '');
    _authType = profile?.authType ?? AuthType.password;
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  void _save() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final profile = ServerProfile(
      id: widget.initialProfile?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 22,
      username: _usernameController.text.trim(),
      authType: _authType,
      password: _authType == AuthType.password ? _passwordController.text : null,
      privateKey: _authType == AuthType.privateKey ? _privateKeyController.text.trim() : null,
    );

    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppPageScaffold(
      title: widget.isEditing ? 'Edit server' : 'Add server',
      maxWidth: AppTheme.formMaxWidth,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined, size: 18),
          label: Text(widget.isEditing ? 'Save changes' : 'Save server'),
        ),
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Connection settings',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Host, port, and account details for this SSH target.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildConnectionFields(context),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.sectionGap),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Authentication',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how this profile signs in.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AuthType>(
                      segments: const [
                        ButtonSegment<AuthType>(
                          value: AuthType.password,
                          label: Text('Password'),
                          icon: Icon(Icons.password),
                        ),
                        ButtonSegment<AuthType>(
                          value: AuthType.privateKey,
                          label: Text('Private key'),
                          icon: Icon(Icons.key_outlined),
                        ),
                      ],
                      selected: {_authType},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        setState(() {
                          _authType = selection.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_authType == AuthType.password)
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline, size: 18),
                      ),
                      validator: (value) {
                        if (_authType == AuthType.password && (value == null || value.isEmpty)) {
                          return 'Enter the SSH password.';
                        }
                        return null;
                      },
                    )
                  else
                    TextFormField(
                      controller: _privateKeyController,
                      minLines: 8,
                      maxLines: 12,
                      decoration: const InputDecoration(
                        labelText: 'Private key (PEM)',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.key, size: 18),
                      ),
                      validator: (value) {
                        if (_authType == AuthType.privateKey &&
                            (value == null || value.trim().isEmpty)) {
                          return 'Paste the PEM private key.';
                        }
                        return null;
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 72),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionFields(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTwoColumns = constraints.maxWidth >= 560;

        if (useTwoColumns) {
          return Column(
            children: [
              TextFormField(
                controller: _hostController,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  prefixIcon: Icon(Icons.dns_outlined, size: 18),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Enter a host name or IP address.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _portController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        prefixIcon: Icon(Icons.settings_ethernet, size: 18),
                      ),
                      validator: (value) {
                        final port = int.tryParse(value ?? '');
                        if (port == null || port < 1 || port > 65535) {
                          return 'Use a valid port.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter a username.';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            TextFormField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host',
                prefixIcon: Icon(Icons.dns_outlined, size: 18),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a host name or IP address.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Port',
                prefixIcon: Icon(Icons.settings_ethernet, size: 18),
              ),
              validator: (value) {
                final port = int.tryParse(value ?? '');
                if (port == null || port < 1 || port > 65535) {
                  return 'Use a valid port.';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person_outline, size: 18),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a username.';
                }
                return null;
              },
            ),
          ],
        );
      },
    );
  }
}
