import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static Future<void> requestForAppUse(BuildContext context) async {
    final permissions = <Permission>[
      Permission.photos,
      Permission.camera,
      Permission.microphone,
      Permission.locationWhenInUse,
      Permission.notification,
    ];

    final results = await permissions.request();

    if (!context.mounted) return;

    final denied = results.entries
        .where((entry) => entry.value.isDenied || entry.value.isPermanentlyDenied)
        .map((entry) => _name(entry.key))
        .toList();

    if (denied.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'يمكنك تفعيل هذه الصلاحيات لاحقاً من إعدادات الهاتف: ${denied.join('، ')}',
          ),
          action: SnackBarAction(
            label: 'الإعدادات',
            onPressed: openAppSettings,
          ),
        ),
      );
    }
  }

  static String _name(Permission permission) {
    if (permission == Permission.photos) return 'الصور';
    if (permission == Permission.camera) return 'الكاميرا';
    if (permission == Permission.microphone) return 'الميكروفون';
    if (permission == Permission.locationWhenInUse) return 'الموقع';
    if (permission == Permission.notification) return 'الإشعارات';
    return 'صلاحية';
  }
}
