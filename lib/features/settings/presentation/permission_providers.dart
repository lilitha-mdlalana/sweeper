import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart' as pm;

enum PermissionState { unknown, granted, denied, permanentlyDenied }

class PermissionStatusNotifier extends AsyncNotifier<PermissionState> {
  @override
  Future<PermissionState> build() async {
    final status = await pm.PhotoManager.requestPermissionExtend();
    return _map(status);
  }

  /// photo_manager owns the actual image+video (+partial access) permission
  /// grant; requesting through it directly — instead of permission_handler's
  /// Permission.photos, which on Android 13+ only ever covers images — is
  /// what makes video access actually get asked for and granted.
  Future<void> request() async {
    final status = await pm.PhotoManager.requestPermissionExtend();
    state = AsyncData(await _mapWithPermanentDenialCheck(status));
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  PermissionState _map(pm.PermissionState status) => switch (status) {
        pm.PermissionState.authorized || pm.PermissionState.limited => PermissionState.granted,
        _ => PermissionState.denied,
      };

  /// photo_manager's PermissionState has no "permanently denied" concept, so
  /// that check still goes through permission_handler.
  Future<PermissionState> _mapWithPermanentDenialCheck(pm.PermissionState status) async {
    final mapped = _map(status);
    if (mapped == PermissionState.denied && await Permission.photos.isPermanentlyDenied) {
      return PermissionState.permanentlyDenied;
    }
    return mapped;
  }
}

final permissionStatusProvider =
    AsyncNotifierProvider<PermissionStatusNotifier, PermissionState>(
  PermissionStatusNotifier.new,
);
