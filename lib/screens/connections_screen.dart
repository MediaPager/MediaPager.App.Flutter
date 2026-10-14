import 'package:flutter/material.dart';

import '../models/server_connection.dart';
import '../services/server_store.dart';
import 'server_form_screen.dart';
import 'server_webview_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key, required this.store});

  final ServerStore store;

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  bool _openedDefaultOnLaunch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openDefaultOnLaunch());
  }

  void _openDefaultOnLaunch() {
    if (!mounted || _openedDefaultOnLaunch) return;
    final server = widget.store.defaultServer;
    if (server == null) return;
    _openedDefaultOnLaunch = true;
    _connect(server);
  }

  Future<void> _connect(ServerConnection server) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            ServerWebViewScreen(store: widget.store, server: server),
      ),
    );
  }

  Future<void> _edit([ServerConnection? server]) async {
    final savedServer = await Navigator.of(context).push<ServerConnection>(
      MaterialPageRoute<ServerConnection>(
        builder: (_) => ServerFormScreen(store: widget.store, server: server),
      ),
    );
    if (savedServer != null && mounted) await _connect(savedServer);
  }

  Future<void> _remove(ServerConnection server) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove server?'),
        content: Text(
          '“${server.nickname}” and its saved credentials will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.store.removeServer(server);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MediaPager servers'),
        actions: [
          IconButton(
            tooltip: 'Add server',
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: widget.store,
        builder: (context, _) {
          final servers = widget.store.servers;
          if (servers.isEmpty) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.dns_outlined, size: 52),
                      const SizedBox(height: 16),
                      Text(
                        'Connect to a MediaPager server',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Save one or more servers. Your default server opens automatically when the app starts.',
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () => _edit(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add server'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: servers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final server = servers[index];
              final isDefault = server.id == widget.store.defaultServerId;
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => _connect(server),
                  leading: CircleAvatar(
                    child: Icon(isDefault ? Icons.star : Icons.dns_outlined),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          server.nickname,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text('Default'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${server.username}\n${server.url}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Server settings',
                    onSelected: (action) {
                      switch (action) {
                        case 'default':
                          widget.store.setDefaultServer(server.id);
                        case 'edit':
                          _edit(server);
                        case 'remove':
                          _remove(server);
                      }
                    },
                    itemBuilder: (context) => [
                      if (!isDefault)
                        const PopupMenuItem(
                          value: 'default',
                          child: Text('Set as default'),
                        ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit connection'),
                      ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove connection'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: widget.store.servers.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add server'),
            ),
    );
  }
}
