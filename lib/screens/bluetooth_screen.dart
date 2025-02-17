import 'dart:async';

import 'package:expense_tracker/utils/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothScreen extends StatefulWidget {
  const BluetoothScreen({super.key});

  @override
  BluetoothScreenState createState() => BluetoothScreenState();
}

class BluetoothScreenState extends State<BluetoothScreen> {
  // Using a map to keep track of devices using their remoteId.
  final Map<String, ScanResult> _devices = {};
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  Future<void> _startScan() async {
    // Clear previous results
    _devices.clear();
    setState(() {
      _isScanning = true;
    });

    // Listen to scan results
    _scanSubscription = FlutterBluePlus.onScanResults.listen(
      (List<ScanResult> results) {
        for (final result in results) {
          // Update or add the device info. This ensures real-time updates to RSSI.
          _devices[result.device.remoteId.toString()] = result;
        }
        setState(() {});
      },
      onError: (error) {
        debugPrint('Error while scanning: $error');
      },
    );

    // Start scanning (for example, 20 seconds)
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));

    setState(() {
      _isScanning = false;
    });
    // Cancel the subscription after scan timeout to avoid duplicate listeners.
    await _scanSubscription?.cancel();
    _scanSubscription = null;
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final devicesList = _devices.values.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Bluetooth Devices',
          style: TextStyle(color: AppColors.textDark),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.secondary),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
      backgroundColor: AppColors.dialogBg,
      body:
          devicesList.isEmpty
              ? Center(
                child:
                    _isScanning
                        ? const CircularProgressIndicator()
                        : const Text(
                          'No devices found',
                          style: TextStyle(color: AppColors.textLight),
                        ),
              )
              : ListView.builder(
                itemCount: devicesList.length,
                itemBuilder: (context, index) {
                  final result = devicesList[index];
                  final deviceName =
                      result.advertisementData.advName.isNotEmpty
                          ? result.advertisementData.advName
                          : 'Unknown Device';
                  // Using color coding for signal strength (example: strong if RSSI > -60)
                  final rssiColor =
                      result.rssi > -60
                          ? AppColors.incomeGreen
                          : AppColors.expenseRed;

                  return Card(
                    color: AppColors.primary,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.bluetooth,
                        color: AppColors.secondary,
                      ),
                      title: Text(
                        deviceName,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        result.device.remoteId.toString(),
                        style: const TextStyle(color: AppColors.textLight),
                      ),
                      trailing: Text(
                        '${result.rssi} dBm',
                        style: TextStyle(
                          color: rssiColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () {
                        debugPrint('Tapped on ${result.device.remoteId}');
                      },
                    ),
                  );
                },
              ),
    );
  }
}
