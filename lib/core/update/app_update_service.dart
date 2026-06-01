import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/elecom/data/elecom_mobile_api.dart';

class AppUpdateService {
  AppUpdateService._();

  static final ElecomMobileApi _api = ElecomMobileApi();
  static bool _checkedThisRun = false;

  static Future<void> checkOnce(BuildContext context) async {
    if (_checkedThisRun) return;
    _checkedThisRun = true;

    Map<String, dynamic> info;
    PackageInfo packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
      info = await _api.getAppUpdateInfo();
    } catch (_) {
      return;
    }

    final latestBuild = _intValue(info['latest_build']);
    final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
    final apkUrl = (info['apk_url'] ?? '').toString().trim();
    if (latestBuild <= currentBuild || apkUrl.isEmpty || !context.mounted) {
      return;
    }

    final latestVersion = (info['latest_version'] ?? '').toString().trim();
    final message = (info['message'] ?? '').toString().trim();
    final forceUpdate = info['force_update'] == true;

    await showDialog<void>(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (dialogContext) {
        final title = latestVersion.isEmpty
            ? 'Update available'
            : 'Update $latestVersion available';
        final body = message.isEmpty
            ? 'A new ELECOM app version is ready. Download the latest APK to continue with the newest fixes.'
            : message;

        final content = AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            if (!forceUpdate)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Later'),
              ),
            FilledButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(apkUrl);
                if (uri == null) return;
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download'),
            ),
          ],
        );

        if (!forceUpdate) return content;
        return PopScope(canPop: false, child: content);
      },
    );
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}
