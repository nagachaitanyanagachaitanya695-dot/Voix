import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/backend_config.dart';
import '../models/song.dart';

/// Why importing a song did not work, in words a learner can act on.
enum SongImportError {
  none,
  cancelled,
  unreadable,
  tooLarge,
  notConfigured,
  budgetExceeded,
  network,
}

/// The outcome of an import: a song, or a reason there isn't one.
@immutable
class SongImport {
  const SongImport.success(this.song) : error = SongImportError.none;
  const SongImport.failure(this.error) : song = null;

  final Song? song;
  final SongImportError error;

  bool get ok => song != null;
}

/// Brings a song into the app and works out when each word is sung.
///
/// The audio file is never copied or uploaded anywhere permanent. It stays
/// where the learner chose it and the app remembers only the path; the bytes
/// travel to the backend once, to be read, and are not stored there either.
class SongService {
  SongService({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Matches the Worker's own cap. Checked here too so a large file is
  /// refused before it is uploaded over mobile data.
  static const maxBytes = 20 * 1024 * 1024;

  /// Transcribing a whole song is slow — minutes of audio, read end to end.
  static const _timeout = Duration(seconds: 120);

  /// Asks for a file, then reads its lyrics.
  ///
  /// Returns a song with empty lyrics rather than failing when the backend is
  /// unavailable: the learner can still type the words in themselves, and
  /// losing the import over it would be worse.
  Future<SongImport> importSong({required String deviceId}) async {
    final FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: false,
      );
    } catch (e) {
      debugPrint('SongService: picker failed ($e)');
      return const SongImport.failure(SongImportError.unreadable);
    }

    final file = picked?.files.singleOrNull;
    final path = file?.path;
    if (file == null || path == null) {
      return const SongImport.failure(SongImportError.cancelled);
    }
    if (file.size > maxBytes) {
      return const SongImport.failure(SongImportError.tooLarge);
    }

    final title = _titleFrom(file.name);
    final id = DateTime.now().microsecondsSinceEpoch.toString();

    final words = await _transcribe(File(path), deviceId: deviceId);
    return SongImport.success(
      Song(
        id: id,
        title: title,
        filePath: path,
        lines: LyricLine.group(words),
      ),
    );
  }

  /// Reads the lyrics of [file]. Returns an empty list if it cannot.
  Future<List<LyricWord>> _transcribe(
    File file, {
    required String deviceId,
  }) async {
    if (!BackendConfig.isConfigured) return const [];

    try {
      final bytes = await file.readAsBytes();
      final response = await _http
          .post(
            BackendConfig.transcribeUrl,
            headers: {
              'Content-Type': 'application/octet-stream',
              'x-voix-audio-type': _mimeFor(file.path),
              'x-voix-app-token': BackendConfig.appToken,
              'x-voix-device': deviceId,
            },
            body: bytes,
          )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        debugPrint('SongService: transcribe ${response.statusCode}');
        return const [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ((data['words'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(LyricWord.fromJson)
          .where((w) => w.text.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('SongService: transcribe failed ($e)');
      return const [];
    }
  }

  /// A readable title from a filename.
  ///
  /// Music files are named every possible way — "03 - Artist - Title.mp3",
  /// "artist_title_official_audio.mp3" — and showing that raw looks broken.
  /// This does not try to be clever: it strips the extension, the track
  /// number, and the noise downloaders append, then tidies the separators.
  static String _titleFrom(String fileName) {
    var name = fileName;
    // >= 0, not > 0: a file called ".mp3" is all extension and no name, and
    // showing ".mp3" as a song title looks like the import half-failed.
    final dot = name.lastIndexOf('.');
    if (dot >= 0) name = name.substring(0, dot);

    name = name.replaceAll(RegExp(r'[_]+'), ' ');
    name = name.replaceFirst(RegExp(r'^\s*\d{1,3}\s*[-.)]\s*'), '');
    name = name.replaceAll(
      RegExp(
        r'\s*[\(\[]?\s*(official|lyrics?|audio|video|hd|hq|full song|'
        r'with lyrics|music video)\s*[\)\]]?\s*',
        caseSensitive: false,
      ),
      ' ',
    );
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name.isEmpty ? 'Untitled song' : name;
  }

  static String _mimeFor(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.m4a') || p.endsWith('.mp4')) return 'audio/mp4';
    if (p.endsWith('.wav')) return 'audio/wav';
    if (p.endsWith('.ogg') || p.endsWith('.opus')) return 'audio/ogg';
    if (p.endsWith('.flac')) return 'audio/flac';
    if (p.endsWith('.aac')) return 'audio/aac';
    return 'audio/mpeg';
  }

  @visibleForTesting
  static String titleFrom(String fileName) => _titleFrom(fileName);

  void dispose() => _http.close();
}
