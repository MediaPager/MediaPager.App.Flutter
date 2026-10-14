import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/server_connection.dart';
import '../services/server_store.dart';

class ServerFormScreen extends StatefulWidget {
  const ServerFormScreen({super.key, required this.store, this.server});

  final ServerStore store;
  final ServerConnection? server;

  @override
  State<ServerFormScreen> createState() => _ServerFormScreenState();
}

class _ServerFormScreenState extends State<ServerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final TextEditingController _urlController;
  late final TextEditingController _usernameController;
  final _passwordController = TextEditingController();
  bool _saving = false;
  bool _hidePassword = true;
  String? _error;

  bool get _editing => widget.server != null;

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(
      text: widget.server?.nickname ?? '',
    );
    _urlController = TextEditingController(text: widget.server?.url ?? '');
    _usernameController = TextEditingController(
      text: widget.server?.username ?? '',
    );
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    try {
      normalizeServerUrl(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final savedServer = await widget.store.saveServer(
        id: widget.server?.id ?? const Uuid().v4(),
        nickname: _nicknameController.text,
        url: _urlController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );
      if (mounted) Navigator.of(context).pop(savedServer);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit server' : 'Connect to a server'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Text(
                  _editing ? 'Update connection' : 'Add a MediaPager server',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  MaterialBanner(
                    content: Text(_error!),
                    actions: [
                      TextButton(
                        onPressed: () => setState(() => _error = null),
                        child: const Text('Dismiss'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nicknameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Server nickname',
                    hintText: 'Home, Work, Living room',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter a nickname.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Server URL',
                    hintText: 'https://media.example.com',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: _validateUrl,
                ),
                if (_urlController.text.trim().toLowerCase().startsWith(
                  'http://',
                ))
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'HTTP is allowed for IP addresses and local server names. Use HTTPS for public domain names.',
                      style: TextStyle(color: Colors.amber),
                    ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _usernameController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Username or email',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Enter your username or email.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _hidePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: _editing
                        ? 'Server password (leave blank to keep saved session)'
                        : 'Server password',
                    suffixIcon: IconButton(
                      tooltip: _hidePassword
                          ? 'Show password'
                          : 'Hide password',
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                      icon: Icon(
                        _hidePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: (value) =>
                      !_editing && (value == null || value.isEmpty)
                      ? 'Enter your password.'
                      : null,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_editing ? 'Save connection' : 'Save server'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
