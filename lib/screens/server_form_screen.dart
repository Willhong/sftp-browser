import 'package:flutter/material.dart';

import '../models/server_profile.dart';

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
      id: widget.initialProfile?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 22,
      username: _usernameController.text.trim(),
      authType: _authType,
      password: _authType == AuthType.password
          ? _passwordController.text
          : null,
      privateKey: _authType == AuthType.privateKey
          ? _privateKeyController.text.trim()
          : null,
    );

    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit server' : 'Add server'),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerLowest,
              theme.colorScheme.primaryContainer.withValues(alpha: 0.28),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  color: theme.colorScheme.surface.withValues(alpha: 0.88),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Connection details',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Save reusable SSH profiles for quick reconnects.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host',
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter a host name or IP address.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _portController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Port',
                                  prefixIcon: Icon(Icons.settings_ethernet),
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
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _usernameController,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Icons.person_outline),
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
                        const SizedBox(height: 24),
                        Text(
                          'Authentication',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<AuthType>(
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
                        const SizedBox(height: 16),
                        if (_authType == AuthType.password)
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            validator: (value) {
                              if (_authType == AuthType.password &&
                                  (value == null || value.isEmpty)) {
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
                              prefixIcon: Icon(Icons.key),
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
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(widget.isEditing ? 'Save changes' : 'Save server'),
        ),
      ),
    );
  }
}
