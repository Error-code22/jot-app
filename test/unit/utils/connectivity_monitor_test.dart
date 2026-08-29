import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:jot_app/utils/connectivity_monitor.dart';
import 'package:jot_app/utils/i_connectivity_monitor.dart';
import 'connectivity_monitor_test.mocks.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([Connectivity])

void main() {
  group('ConnectivityMonitor - Task 11.1', () {
    late MockConnectivity mockConnectivity;
    late IConnectivityMonitor monitor;
    late StreamController<ConnectivityResult> connectivityController;
    late ConnectivityResult currentResult;

    setUp(() {
      mockConnectivity = MockConnectivity();
      monitor = ConnectivityMonitor(connectivity: mockConnectivity);

      connectivityController = StreamController<ConnectivityResult>.broadcast();
      currentResult = ConnectivityResult.wifi;

      when(mockConnectivity.onConnectivityChanged).thenAnswer((_) => connectivityController.stream);
      when(mockConnectivity.checkConnectivity()).thenAnswer((_) async => currentResult);
    });

    tearDown(() {
      monitor.dispose();
      connectivityController.close();
    });

    group('isOnline() - Requirements 4.1', () {
      test('should return true when connected to wifi', () async {
        currentResult = ConnectivityResult.wifi;
        
        final isOnline = await monitor.isOnline();
        
        expect(isOnline, isTrue);
      });

      test('should return true when connected to mobile data', () async {
        currentResult = ConnectivityResult.mobile;
        
        final isOnline = await monitor.isOnline();
        
        expect(isOnline, isTrue);
      });

      test('should return true when connected to ethernet', () async {
        currentResult = ConnectivityResult.ethernet;
        
        final isOnline = await monitor.isOnline();
        
        expect(isOnline, isTrue);
      });

      test('should return false when no connectivity', () async {
        currentResult = ConnectivityResult.none;
        
        final isOnline = await monitor.isOnline();
        
        expect(isOnline, isFalse);
      });

      // connectivity_plus reports a single active connectivity type.
    });

    group('connectivityStream - Requirements 4.1, 4.7', () {
      test('should emit true when initially online', () async {
        currentResult = ConnectivityResult.wifi;
        
        final states = <bool>[];
        final subscription = monitor.connectivityStream.listen(states.add);
        
        // Wait for initial state
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(states, isNotEmpty);
        expect(states.last, isTrue);
        
        await subscription.cancel();
      });

      test('should emit false when initially offline', () async {
        currentResult = ConnectivityResult.none;
        
        final states = <bool>[];
        final subscription = monitor.connectivityStream.listen(states.add);
        
        // Wait for initial state
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(states, isNotEmpty);
        expect(states.last, isFalse);
        
        await subscription.cancel();
      });

      test('should emit false when connectivity is lost', () async {
        currentResult = ConnectivityResult.wifi;
        
        final states = <bool>[];
        final subscription = monitor.connectivityStream.listen(states.add);
        
        // Wait for initial state
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Lose connectivity
        currentResult = ConnectivityResult.none;
        connectivityController.add(ConnectivityResult.none);
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(states.length, greaterThanOrEqualTo(2));
        expect(states.first, isTrue);
        expect(states.last, isFalse);
        
        await subscription.cancel();
      });

      test('should emit true when connectivity is restored', () async {
        currentResult = ConnectivityResult.none;
        
        final states = <bool>[];
        final subscription = monitor.connectivityStream.listen(states.add);
        
        // Wait for initial state
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Restore connectivity
        currentResult = ConnectivityResult.wifi;
        connectivityController.add(ConnectivityResult.wifi);
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(states.length, greaterThanOrEqualTo(2));
        expect(states.first, isFalse);
        expect(states.last, isTrue);
        
        await subscription.cancel();
      });

      test('should emit multiple state changes', () async {
        currentResult = ConnectivityResult.wifi;
        
        final states = <bool>[];
        final subscription = monitor.connectivityStream.listen(states.add);
        
        // Wait for initial state
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Go offline
        currentResult = ConnectivityResult.none;
        connectivityController.add(ConnectivityResult.none);
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Go back online
        currentResult = ConnectivityResult.mobile;
        connectivityController.add(ConnectivityResult.mobile);
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Go offline again
        currentResult = ConnectivityResult.none;
        connectivityController.add(ConnectivityResult.none);
        await Future.delayed(const Duration(milliseconds: 100));
        
        expect(states.length, greaterThanOrEqualTo(4));
        expect(states[0], isTrue);  // Initial wifi
        expect(states[1], isFalse); // Lost connectivity
        expect(states[2], isTrue);  // Mobile restored
        expect(states[3], isFalse); // Lost again
        
        await subscription.cancel();
      });

      test('should support multiple listeners', () async {
        currentResult = ConnectivityResult.wifi;
        
        final states1 = <bool>[];
        final states2 = <bool>[];
        
        final subscription1 = monitor.connectivityStream.listen(states1.add);
        final subscription2 = monitor.connectivityStream.listen(states2.add);
        
        // Wait for initial state
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Change connectivity
        currentResult = ConnectivityResult.none;
        connectivityController.add(ConnectivityResult.none);
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Both listeners should receive updates
        expect(states1.length, greaterThanOrEqualTo(2));
        expect(states2.length, greaterThanOrEqualTo(2));
        expect(states1.last, isFalse);
        expect(states2.last, isFalse);
        
        await subscription1.cancel();
        await subscription2.cancel();
      });
    });

    group('Error handling', () {
      test('should handle connectivity check errors gracefully', () async {
        final errorConnectivity = MockConnectivity();
        when(errorConnectivity.checkConnectivity()).thenAnswer((_) async {
          throw Exception('Connectivity check failed');
        });
        when(errorConnectivity.onConnectivityChanged).thenAnswer((_) => const Stream.empty());

        final errorMonitor = ConnectivityMonitor(connectivity: errorConnectivity);
        
        // Should not throw, should return false (assume offline)
        final isOnline = await errorMonitor.isOnline();
        expect(isOnline, isFalse);
        
        errorMonitor.dispose();
      });

      test('should handle stream errors gracefully', () async {
        final errorConnectivity = MockConnectivity();
        final controller = StreamController<ConnectivityResult>.broadcast();
        when(errorConnectivity.onConnectivityChanged).thenAnswer((_) => controller.stream);
        when(errorConnectivity.checkConnectivity()).thenAnswer((_) async {
          throw Exception('Connectivity check failed');
        });

        final errorMonitor = ConnectivityMonitor(connectivity: errorConnectivity);
        
        final states = <bool>[];
        final subscription = errorMonitor.connectivityStream.listen(states.add);
        
        // Wait for initial state (should be false due to error)
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Trigger stream error
        controller.addError(Exception('Stream error'));
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should receive false state on error
        expect(states, isNotEmpty);
        expect(states.last, isFalse);
        
        await subscription.cancel();
        errorMonitor.dispose();
        await controller.close();
      });
    });

    group('Resource management', () {
      test('should clean up resources on dispose', () async {
        currentResult = ConnectivityResult.wifi;
        
        final states = <bool>[];
        final subscription = monitor.connectivityStream.listen(states.add);
        
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Dispose monitor
        monitor.dispose();
        
        // Change connectivity after dispose
        currentResult = ConnectivityResult.none;
        connectivityController.add(ConnectivityResult.none);
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Should not receive new updates after dispose
        final statesAfterDispose = states.length;
        await Future.delayed(const Duration(milliseconds: 100));
        expect(states.length, equals(statesAfterDispose));
        
        await subscription.cancel();
      });
    });
  });
}
