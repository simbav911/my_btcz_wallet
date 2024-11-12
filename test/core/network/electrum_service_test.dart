import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:my_btcz_wallet/core/network/connection_status.dart';
import 'package:my_btcz_wallet/core/network/electrum_service.dart';

import 'electrum_service_test.mocks.dart';

@GenerateMocks([], customMocks: [
  MockSpec<SecureSocket>(
    as: #MockSecureSocket,
  ),
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ElectrumService electrumService;
  late MockSecureSocket mockSocket;
  late StreamController<Uint8List> socketController;

  setUp(() {
    mockSocket = MockSecureSocket();
    socketController = StreamController<Uint8List>();
    when(mockSocket.listen(any)).thenAnswer((invocation) {
      final onData = invocation.positionalArguments[0] as Function;
      return socketController.stream.listen((data) => onData(data));
    });
    electrumService = ElectrumService();
  });

  tearDown(() async {
    await socketController.close();
  });

  group('ElectrumService', () {
    test('initial state should be disconnected', () {
      expect(electrumService.status, equals(ConnectionStatus.disconnected));
    });

    test('should negotiate protocol version correctly', () async {
      // Arrange
      final response = {
        'jsonrpc': '2.0',
        'id': 0,
        'result': ['BitcoinZ Electrum', '1.4']
      };

      // Act & Assert
      expect(electrumService.protocolVersion, isNull);

      // Simulate successful version negotiation response
      socketController.add(Uint8List.fromList(utf8.encode(json.encode(response) + '\n')));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(electrumService.protocolVersion, equals('1.4'));
    });

    test('should handle connection errors gracefully', () async {
      // Arrange
      when(mockSocket.listen(any)).thenThrow(const SocketException('Connection refused'));

      // Act & Assert
      expect(electrumService.status, equals(ConnectionStatus.disconnected));
      await electrumService.connect();
      expect(electrumService.status, equals(ConnectionStatus.disconnected));
    });

    test('should handle server errors gracefully', () async {
      // Arrange
      final response = {
        'jsonrpc': '2.0',
        'id': 0,
        'error': {'code': -32601, 'message': 'Method not found'}
      };

      // Act & Assert
      socketController.add(Uint8List.fromList(utf8.encode(json.encode(response) + '\n')));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(electrumService.status, equals(ConnectionStatus.disconnected));
    });

    test('should reconnect on connection loss', () async {
      // Arrange
      final completer = Completer<void>();
      when(mockSocket.listen(any)).thenAnswer((invocation) {
        final onDone = invocation.namedArguments[#onDone] as void Function()?;
        return socketController.stream.listen(
          (data) {},
          onDone: () {
            onDone?.call();
            completer.complete();
          },
        );
      });

      // Act
      await electrumService.connect();
      await socketController.close();
      await completer.future;

      // Assert
      expect(electrumService.status, equals(ConnectionStatus.disconnected));
    });

    test('should maintain connection status', () async {
      final statuses = <ConnectionStatus>[];
      final subscription = electrumService.statusStream.listen((status) {
        statuses.add(status);
      });

      await electrumService.connect();
      await Future.delayed(const Duration(milliseconds: 100));
      await electrumService.disconnect();

      await subscription.cancel();

      expect(statuses, containsAllInOrder([
        ConnectionStatus.connecting,
        ConnectionStatus.disconnected,
      ]));
    });

    test('should handle protocol version negotiation failure', () async {
      // Arrange
      final response = {
        'jsonrpc': '2.0',
        'id': 0,
        'error': {'code': -32600, 'message': 'Unsupported protocol version'}
      };

      // Act & Assert
      socketController.add(Uint8List.fromList(utf8.encode(json.encode(response) + '\n')));

      await Future.delayed(const Duration(milliseconds: 100));
      expect(electrumService.status, equals(ConnectionStatus.disconnected));
      expect(electrumService.protocolVersion, isNull);
    });

    test('should handle ping timeouts', () async {
      // Arrange
      final controller = StreamController<Uint8List>();
      when(mockSocket.listen(any)).thenAnswer((invocation) {
        final onData = invocation.positionalArguments[0] as Function;
        return controller.stream.listen((data) => onData(data));
      });

      // Act & Assert
      await electrumService.connect();
      
      // Wait for ping timeout (should be less than the actual timeout)
      await Future.delayed(const Duration(seconds: 2));
      
      // Should still be connected as timeout hasn't occurred
      expect(electrumService.status, equals(ConnectionStatus.connected));

      await controller.close();
    });
  });
}
