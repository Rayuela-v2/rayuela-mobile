import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// File the [ImageStore] writes when persisting an attachment.
class StoredImage {
  const StoredImage({
    required this.path,
    required this.byteSize,
    required this.mimeType,
  });

  /// Absolute path inside the app's private support directory.
  final String path;
  final int byteSize;
  final String mimeType;
}

/// Strategy for shrinking a source image before persisting it.
///
/// We isolate compression behind an interface so:
///   * tests can run without the platform plugin (they use the
///     [PassthroughImageCompressor] below);
///   * we can swap the encoder if we ever need WebP, AVIF, or per-device
///     quality tuning.
abstract class ImageCompressor {
  Future<Uint8List> compressToJpeg(
    String sourcePath, {
    int maxLongEdge = 1600,
    int quality = 80,
  });
}

class FlutterImageCompressorImpl implements ImageCompressor {
  const FlutterImageCompressorImpl();

  @override
  Future<Uint8List> compressToJpeg(
    String sourcePath, {
    int maxLongEdge = 1600,
    int quality = 80,
  }) async {
    final bytes = await FlutterImageCompress.compressWithFile(
      sourcePath,
      minWidth: maxLongEdge,
      minHeight: maxLongEdge,
      quality: quality,
    );
    if (bytes == null) {
      // Fallback: ship the original bytes uncompressed. Better to upload
      // a heavier image than to drop the user's check-in.
      return File(sourcePath).readAsBytes();
    }
    return Uint8List.fromList(bytes);
  }
}

/// Test-only [ImageCompressor] that simply reads the source bytes
/// unchanged. Available in production code so it can also be used as a
/// safety fallback in environments where flutter_image_compress isn't
/// available (e.g. the analyzer running snapshot-style tests).
class PassthroughImageCompressor implements ImageCompressor {
  const PassthroughImageCompressor();

  @override
  Future<Uint8List> compressToJpeg(
    String sourcePath, {
    int maxLongEdge = 1600,
    int quality = 80,
  }) async {
    return File(sourcePath).readAsBytes();
  }
}

/// Persists check-in attachments to a stable directory inside the app
/// sandbox so they survive between the moment the volunteer captures
/// them and the moment the outbox drainer finally uploads them.
///
/// Layout:
/// ```
/// <baseDir>/                 # passed in (`outbox/` under app support)
///   <outboxId>/              # one folder per queued check-in
///     0.jpg
///     1.jpg
///     2.jpg
/// ```
///
/// All operations are filesystem-only — they don't talk to SQLite. The
/// outbox DAO is the source of truth for which folders are still
/// referenced; [sweepOrphans] consults that list to clean up.
class ImageStore {
  ImageStore({
    required this.baseDir,
    ImageCompressor? compressor,
  }) : compressor = compressor ?? const FlutterImageCompressorImpl();

  /// Root folder where per-outbox subdirectories live. Must exist or be
  /// creatable by the caller.
  final Directory baseDir;
  final ImageCompressor compressor;

  /// Default factory: resolves the platform-private support directory
  /// and prepares the `outbox/` folder. Production code should call this
  /// once at bootstrap and reuse the returned instance.
  static Future<ImageStore> createDefault({
    ImageCompressor? compressor,
  }) async {
    final support = await getApplicationSupportDirectory();
    final base = Directory(p.join(support.path, 'outbox'));
    if (!await base.exists()) {
      await base.create(recursive: true);
    }
    return ImageStore(baseDir: base, compressor: compressor);
  }

  /// Compresses each source file and writes it to
  /// `<baseDir>/<outboxId>/<position>.jpg`.
  ///
  /// Throws if [sourcePaths] is empty: a check-in must have at least one
  /// photo. On any I/O error mid-loop we roll back the partial write so
  /// the caller can retry without ending up with mixed state.
  Future<List<StoredImage>> persist({
    required String outboxId,
    required List<String> sourcePaths,
    int maxLongEdge = 1600,
    int quality = 80,
  }) async {
    if (sourcePaths.isEmpty) {
      throw ArgumentError.value(sourcePaths, 'sourcePaths', 'Must not be empty');
    }
    final dir = Directory(p.join(baseDir.path, outboxId));
    await dir.create(recursive: true);

    final result = <StoredImage>[];
    try {
      for (var i = 0; i < sourcePaths.length; i++) {
        final bytes = await compressor.compressToJpeg(
          sourcePaths[i],
          maxLongEdge: maxLongEdge,
          quality: quality,
        );
        final dest = File(p.join(dir.path, '$i.jpg'));
        await dest.writeAsBytes(bytes, flush: true);
        result.add(
          StoredImage(
            path: dest.path,
            byteSize: bytes.length,
            mimeType: 'image/jpeg',
          ),
        );
      }
      return result;
    } catch (e) {
      // Best-effort rollback so we don't leave an orphan half-folder
      // referenced by no SQLite row.
      try {
        await dir.delete(recursive: true);
      } catch (_) {/* swallow — orphan sweep will catch it later */}
      rethrow;
    }
  }

  /// Removes the on-disk folder for [outboxId]. Idempotent: missing
  /// folders are silently ignored.
  Future<void> deleteForOutbox(String outboxId) async {
    final dir = Directory(p.join(baseDir.path, outboxId));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Deletes per-outbox folders whose id is NOT in [knownIds] AND whose
  /// most-recently modified file is older than [minAge]. Returns the
  /// number of folders removed.
  ///
  /// Two safeguards combined: [knownIds] protects rows in flight in
  /// SQLite, [minAge] protects the case where the SQLite write is
  /// in-progress while we sweep (we don't want to race against an
  /// `enqueue`).
  Future<int> sweepOrphans({
    required Set<String> knownIds,
    Duration minAge = const Duration(hours: 1),
  }) async {
    if (!await baseDir.exists()) return 0;
    final cutoff = DateTime.now().subtract(minAge);
    var removed = 0;
    await for (final entity in baseDir.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = p.basename(entity.path);
      if (knownIds.contains(id)) continue;

      // Check the latest modified file in the directory to determine its age
      DateTime latestModified = DateTime(1970);
      try {
        await for (final file in entity.list(followLinks: false)) {
          final fileStat = await file.stat();
          if (fileStat.modified.isAfter(latestModified)) {
            latestModified = fileStat.modified;
          }
        }
      } catch (_) {
        // Ignore read errors inside the directory
      }

      // If the directory is empty, we fall back to the directory's own stat
      if (latestModified == DateTime(1970)) {
        final dirStat = await entity.stat();
        latestModified = dirStat.modified;
      }

      if (latestModified.isAfter(cutoff)) continue;
      try {
        await entity.delete(recursive: true);
        removed++;
      } catch (_) {
        // Don't let a single locked file abort the whole sweep.
      }
    }
    return removed;
  }

  /// Sum of bytes used by the outbox tree. Useful for the "Pending data"
  /// settings screen and the future low-disk warning (§9 of the plan).
  Future<int> totalBytesUsed() async {
    if (!await baseDir.exists()) return 0;
    var total = 0;
    await for (final e in baseDir.list(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {/* ignore racing deletions */}
      }
    }
    return total;
  }
}
