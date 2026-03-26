import 'package:flutter_test/flutter_test.dart';
import 'package:sw_ble/sw_ble.dart';
import 'package:sw_ble/sw_ble_platform_interface.dart';
import 'package:sw_ble/sw_ble_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockSwBlePlatform
    with MockPlatformInterfaceMixin
    implements SwBlePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final SwBlePlatform initialPlatform = SwBlePlatform.instance;

  test('$MethodChannelSwBle is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelSwBle>());
  });

  test('getPlatformVersion', () async {
    SwBle swBlePlugin = SwBle();
    MockSwBlePlatform fakePlatform = MockSwBlePlatform();
    SwBlePlatform.instance = fakePlatform;

    expect(await swBlePlugin.getPlatformVersion(), '42');
  });
}
