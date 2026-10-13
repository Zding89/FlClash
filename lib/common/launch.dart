import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import 'constant.dart';
import 'system.dart';

class AutoLaunch {
  static AutoLaunch? _instance;

  AutoLaunch._internal() {
    launchAtStartup.setup(
      appName: platformAppName,
      appPath: Platform.resolvedExecutable,
    );
  }

  factory AutoLaunch() {
    _instance ??= AutoLaunch._internal();
    return _instance!;
  }

  Future<bool> get isEnable async {
    return launchAtStartup.isEnabled();
  }

  Future<bool> enable() async {
    return launchAtStartup.enable();
  }

  Future<bool> disable() async {
    return launchAtStartup.disable();
  }

  Future<void> updateStatus(bool isAutoLaunch) async {
    if (kDebugMode) {
      return;
    }
    if (await isEnable == isAutoLaunch) return;
    if (isAutoLaunch == true) {
      if (!await enable()) throw StateError('autolaunch_failed');
    } else {
      if (!await disable()) throw StateError('autolaunch_failed');
    }
  }
}

final autoLaunch = system.isDesktop ? AutoLaunch() : null;
