import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionState { unknown, granted, denied, permanentlyDenied }

class PermissionStatusNotifier extends AsyncNotifier<PermissionState> {
  @override
  Future<PermissionState> build() async {
    final status = await Permission.photos.status;
    return _map(status);
  }

  Future<void> request() async {
    final status = await Permission.photos.request();
    state = AsyncData(_map(status));
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  PermissionState _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) return PermissionState.granted;
    if (status.isPermanentlyDenied) return PermissionState.permanentlyDenied;
    return PermissionState.denied;
  }
}

final permissionStatusProvider =
    AsyncNotifierProvider<PermissionStatusNotifier, PermissionState>(
  PermissionStatusNotifier.new,
);
