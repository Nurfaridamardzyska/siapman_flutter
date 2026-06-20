import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  static Future<String> getUniqueId() async {
    try {
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await _deviceInfo.androidInfo;
        // id biasanya berisi unik UUID perangkat android
        return androidInfo.id; 
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await _deviceInfo.iosInfo;
        // identifierForVendor sangat stabil di iOS
        return iosInfo.identifierForVendor ?? "unknown_ios_device";
      } else if (Platform.isMacOS) {
        MacOsDeviceInfo macInfo = await _deviceInfo.macOsInfo;
        return macInfo.systemGUID ?? "unknown_macos";
      }
      return "unknown_platform";
    } catch (e) {
      return "error_getting_device_id";
    }
  }
}
