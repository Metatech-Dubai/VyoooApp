import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local story draft (image stories only). Files live under app documents.
class StoryDraftStorage {
  StoryDraftStorage._();

  static const _prefsKey = 'story_draft_manifest_v1';
  static const _draftSubdir = 'story_drafts/current';

  static Future<Directory> _draftDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/$_draftSubdir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<bool> hasDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return false;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final n = (map['imageCount'] as num?)?.toInt() ?? 0;
      if (n <= 0) return false;
      final dir = await _draftDir();
      for (var i = 0; i < n; i++) {
        final f = File('${dir.path}/$i.jpg');
        if (!await f.exists()) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> loadManifest() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Copies [imageFiles] into draft storage and persists [editsJson] + [caption].
  /// Uses a staging directory first so sources inside the draft folder are not deleted before copy.
  static Future<void> saveDraft({
    required List<File> imageFiles,
    required String caption,
    required List<Map<String, dynamic>> editsJson,
  }) async {
    if (imageFiles.isEmpty) return;
    final root = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${root.path}/$_draftSubdir');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final staging = Directory('${root.path}/story_drafts/_staging_$stamp');
    await staging.create(recursive: true);
    try {
      for (var i = 0; i < imageFiles.length; i++) {
        final src = imageFiles[i];
        if (!await src.exists()) continue;
        await src.copy('${staging.path}/$i.jpg');
      }
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await staging.rename(targetDir.path);
    } catch (e, st) {
      debugPrint('StoryDraftStorage.saveDraft: $e $st');
      if (await staging.exists()) {
        try {
          await staging.delete(recursive: true);
        } catch (_) {}
      }
      rethrow;
    }
    final prefs = await SharedPreferences.getInstance();
    final manifest = <String, dynamic>{
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'caption': caption,
      'imageCount': imageFiles.length,
      'edits': editsJson,
    };
    await prefs.setString(_prefsKey, jsonEncode(manifest));
  }

  static Future<StoryDraftRestore?> loadDraft() async {
    final manifest = await loadManifest();
    if (manifest == null) return null;
    final n = (manifest['imageCount'] as num?)?.toInt() ?? 0;
    if (n <= 0) return null;
    final dir = await _draftDir();
    final files = <File>[];
    for (var i = 0; i < n; i++) {
      final f = File('${dir.path}/$i.jpg');
      if (!await f.exists()) {
        await clearDraft();
        return null;
      }
      files.add(f);
    }
    final edits = (manifest['edits'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    return StoryDraftRestore(
      imageFiles: files,
      caption: (manifest['caption'] as String?) ?? '',
      editsJson: edits,
    );
  }

  static Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    try {
      final dir = await _draftDir();
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('StoryDraftStorage.clearDraft: $e');
    }
  }
}

class StoryDraftRestore {
  StoryDraftRestore({
    required this.imageFiles,
    required this.caption,
    required this.editsJson,
  });

  final List<File> imageFiles;
  final String caption;
  final List<Map<String, dynamic>> editsJson;
}
