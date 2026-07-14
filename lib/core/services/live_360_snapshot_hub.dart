import 'dart:async';

/// Routes Agora [RtcEngine.takeSnapshot] callbacks to the active 360° panorama
/// viewer. Broadcast scrub snapshots use a separate pending-elapsed path.
class Live360SnapshotHub {
  Live360SnapshotHub._();

  static final Live360SnapshotHub instance = Live360SnapshotHub._();

  final Set<String> _armedPaths = <String>{};
  Future<void> Function(String path, int errCode)? _listener;

  void bind(Future<void> Function(String path, int errCode) listener) {
    _listener = listener;
  }

  void unbind(Future<void> Function(String path, int errCode) listener) {
    if (identical(_listener, listener)) {
      _listener = null;
    }
    _armedPaths.clear();
  }

  void arm(String path) {
    _armedPaths.add(path);
  }

  /// Returns true when this snapshot was requested by the 360° panorama viewer.
  Future<bool> deliver(String filePath, int errCode) async {
    if (!_armedPaths.remove(filePath)) return false;
    final listener = _listener;
    if (listener != null) {
      await listener(filePath, errCode);
    }
    return true;
  }
}
