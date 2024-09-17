import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

class BLEChatPage extends StatefulWidget {
  @override
  _BLEChatPageState createState() => _BLEChatPageState();
}

class _BLEChatPageState extends State<BLEChatPage> {
  FlutterBluePlus flutterBlue = FlutterBluePlus();
  final List<BluetoothDevice> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnecting = false;
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initializeBLE();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _disconnectFromDevice();
    super.dispose();
  }

  Future<void> _initializeBLE() async {
    await _checkPermissions();
    await _enableLocationServices();
    await _checkBluetoothAvailability();
    _startScan();
  }

  Future<void> _checkPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan] != PermissionStatus.granted ||
        statuses[Permission.bluetoothConnect] != PermissionStatus.granted ||
        statuses[Permission.location] != PermissionStatus.granted) {
      print("Required permissions not granted");
    }
  }

  Future<void> _enableLocationServices() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      bool opened = await Geolocator.openLocationSettings();
      if (!opened) {
        print("Location services not enabled");
      }
    }
  }

  Future<void> _checkBluetoothAvailability() async {
    bool isAvailable = await FlutterBluePlus.isSupported;

    final adapterState = FlutterBluePlus.adapterState;

    if (!isAvailable) {
      print("Bluetooth is not available on this device");
      return;
    }

    if (adapterState.first == BluetoothAdapterState.on) {
      print("Bluetooth is turned off. Please turn it on.");
    }
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
      _discoveredDevices.clear();
    });

    // Start listening to bluetooth scan results
    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (ScanResult result in results) {
          String deviceName = result.device.platformName.isNotEmpty
              ? result.device.platformName
              : 'Unknown Device';
          print('Found device: $deviceName, ID: ${result.device.remoteId}');
          if (!_discoveredDevices.contains(result.device)) {
            setState(() {
              _discoveredDevices.add(result.device);
            });
          }
        }
      },
      onError: (error) {
        print('Scan failed with error: $error');
        _stopScan();
      },
      onDone: () {
        _stopScan();
      },
    );

    try {
      // Start the scan with a 20-second timeout
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));
    } catch (e) {
      print('Failed to start scan: $e');
      _stopScan();
    }
  }

  void _stopScan() async {
    await FlutterBluePlus.stopScan(); // Ensure the scan is stopped
    _scanSubscription?.cancel(); // Cancel the stream subscription
    setState(() {
      _isScanning = false; // Update ui to stop showing the loader
    });
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _isConnecting = true;
    });

    try {
      await device.connect(autoConnect: false);
      setState(() {
        _connectedDevice = device;
        _isConnecting = false;
      });
    } catch (e) {
      print('Failed to connect: $e');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  void _disconnectFromDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
        setState(() {
          _connectedDevice = null;
        });
      } catch (e) {
        print('Failed to disconnect: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Bluetooth Chat App'),
          actions: [
            _isScanning
                ? IconButton(
                    icon: const Icon(Icons.stop),
                    onPressed: _stopScan,
                  )
                : IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _startScan,
                  ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                _connectedDevice != null
                    ? 'Connected to: ${_connectedDevice!.platformName}'
                    : 'No device connected',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              if (_isConnecting) const CircularProgressIndicator(),
              if (_connectedDevice == null) ...[
                if (_isScanning)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                Expanded(
                  child: _discoveredDevices.isEmpty
                      ? const Center(child: Text('No devices found'))
                      : ListView.builder(
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            BluetoothDevice device = _discoveredDevices[index];
                            String deviceName = device.platformName.isNotEmpty
                                ? device.platformName
                                : 'Unknown Device';
                            return ListTile(
                              title: Text(deviceName),
                              subtitle: Text(device.remoteId.toString()),
                              trailing: const Icon(
                                  Icons.mobile_screen_share_outlined),
                              onTap: () => _connectToDevice(device),
                            );
                          },
                        ),
                ),
              ] else
                ElevatedButton(
                  onPressed: _disconnectFromDevice,
                  child: const Text('Disconnect'),
                ),
            ],
          ),
        ));
  }
}
