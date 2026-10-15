import 'package:fl_clash/common/system.dart';
import 'package:proxy/proxy.dart';

Proxy? proxy = system.isDesktop ? Proxy() : null;
