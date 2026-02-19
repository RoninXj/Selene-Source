import 'package:flutter/material.dart';

import '../utils/device_utils.dart';
import 'home_screen.dart';
import 'tv_home_screen.dart';

class RootHomeScreen extends StatefulWidget {
  const RootHomeScreen({super.key});

  @override
  State<RootHomeScreen> createState() => _RootHomeScreenState();
}

class _RootHomeScreenState extends State<RootHomeScreen> {
  bool? _isAndroidTv;

  @override
  void initState() {
    super.initState();
    _resolveDeviceType();
  }

  Future<void> _resolveDeviceType() async {
    final isTv = await DeviceUtils.isAndroidTV();
    if (!mounted) return;
    setState(() {
      _isAndroidTv = isTv;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isAndroidTv == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isAndroidTv! ? const TvHomeScreen() : const HomeScreen();
  }
}
