import 'package:flutter/material.dart';
import 'package:my_btcz_wallet/core/network/connection_status.dart';
import 'package:my_btcz_wallet/core/network/electrum_service.dart';

class ConnectionStatusIndicator extends StatelessWidget {
  final ElectrumService electrumService;

  const ConnectionStatusIndicator({
    super.key,
    required this.electrumService,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionStatus>(
      stream: electrumService.statusStream,
      initialData: electrumService.status,
      builder: (context, snapshot) {
        final status = snapshot.data ?? ConnectionStatus.disconnected;
        return InkWell(
          onTap: () => _showConnectionInfo(context),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusIcon(status),
                const SizedBox(width: 4),
                Text(_getStatusText(status)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return const Icon(
          Icons.cloud_done,
          color: Colors.green,
          size: 20,
        );
      case ConnectionStatus.connecting:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        );
      case ConnectionStatus.disconnected:
        return const Icon(
          Icons.cloud_off,
          color: Colors.red,
          size: 20,
        );
    }
  }

  String _getStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.connecting:
        return 'Connecting';
      case ConnectionStatus.disconnected:
        return 'Disconnected';
    }
  }

  void _showConnectionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: ${_getStatusText(electrumService.status)}'),
            if (electrumService.currentServer != null) ...[
              const SizedBox(height: 8),
              Text('Server: ${electrumService.currentServer}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (electrumService.status != ConnectionStatus.connected) {
                electrumService.connect();
              }
            },
            child: Text(
              electrumService.status == ConnectionStatus.connected
                  ? 'OK'
                  : 'Reconnect',
            ),
          ),
        ],
      ),
    );
  }
}
