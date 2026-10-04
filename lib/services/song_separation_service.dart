import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:musiq_learning/models/song_track.dart';

abstract interface class SongSeparationService {
  Future<SeparatedSong> separate(SongFile original);
}

class FastApiSongSeparationService implements SongSeparationService {
  const FastApiSongSeparationService();

  static const Duration _separationRequestTimeout = Duration(minutes: 30);
  static const Duration _responseHeaderTimeout = Duration(seconds: 60);
  static const Duration _responseInactivityTimeout = Duration(seconds: 90);

  /// Set this once when launching Flutter:
  /// --dart-define=song_backend_url=http://MAC_LAN_IP:8000
  /// Do not use localhost or 127.0.0.1 for a physical Android phone.
  static const String backendBaseUrl = String.fromEnvironment(
    'song_backend_url',
    defaultValue: 'http://192.168.0.12:8000',
  );

  @override
  Future<SeparatedSong> separate(SongFile original) async {
    final baseUrl = backendBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (baseUrl.isEmpty) {
      throw const SongIntegrationUnavailable(
        'Set song_backend_url to the Mac LAN address, for example http://192.168.1.20:8000.',
      );
    }

    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null ||
        !baseUri.hasAuthority ||
        (baseUri.scheme != 'http' && baseUri.scheme != 'https') ||
        _isLoopback(baseUri.host)) {
      throw const SongIntegrationUnavailable(
        'song_backend_url must use the Mac LAN IP, for example http://192.168.1.20:8000.',
      );
    }
    final source = File(original.path);
    debugPrint('SEPARATION: source file existence check started');
    final sourceExists = await source.exists();
    debugPrint('SEPARATION: source file exists=$sourceExists');
    if (!sourceExists) {
      throw const SongIntegrationUnavailable(
        'The selected song file is missing or empty on this device.',
      );
    }
    debugPrint('SEPARATION: source file length check started');
    final sourceLength = await source.length();
    debugPrint('SEPARATION: source file length=$sourceLength');
    if (sourceLength == 0) {
      throw const SongIntegrationUnavailable(
        'The selected song file is missing or empty on this device.',
      );
    }

    final client = http.Client();
    Directory? outputDirectory;
    try {
      final endpoint = baseUri.replace(
        path: '${baseUri.path.replaceFirst(RegExp(r'/+$'), '')}/separate',
        query: null,
        fragment: null,
      );
      final request = http.MultipartRequest('POST', endpoint);
      debugPrint('SEPARATION: multipart file preparation started');
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          original.path,
          filename: original.fileName,
        ),
      );
      debugPrint('SEPARATION: multipart file preparation completed');
      debugPrint('SEPARATION: request started ($endpoint)');
      final streamedResponse = await client
          .send(request)
          .timeout(_separationRequestTimeout);
      debugPrint(
        'SEPARATION: /separate returned HTTP ${streamedResponse.statusCode}',
      );
      debugPrint('SEPARATION: /separate response body read started');
      final responseBody = await utf8.decoder
          .bind(streamedResponse.stream.timeout(_responseInactivityTimeout))
          .join();
      debugPrint('SEPARATION: /separate response body read completed');
      if (streamedResponse.statusCode < 200 ||
          streamedResponse.statusCode >= 300) {
        throw SongIntegrationUnavailable(
          _responseError(responseBody, streamedResponse.statusCode),
        );
      }

      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic> || decoded['success'] != true) {
        throw const SongIntegrationUnavailable(
          'The backend response did not confirm successful stem separation.',
        );
      }
      final vocalUri = _validatedOutputUri(decoded['vocal_url']);
      final instrumentalUri = _validatedOutputUri(decoded['instrumental_url']);
      if (vocalUri == instrumentalUri) {
        throw const SongIntegrationUnavailable(
          'The backend returned the same URL for both audio stems.',
        );
      }

      debugPrint('SEPARATION: temporary output directory creation started');
      outputDirectory = await Directory.systemTemp.createTemp(
        'musiq_learning_stems_',
      );
      debugPrint(
        'SEPARATION: temporary output directory created at ${outputDirectory.path}',
      );
      debugPrint('SEPARATION: vocal download started');
      final vocalFile = await _downloadOutput(
        client,
        vocalUri,
        outputDirectory,
        'vocal_stem.mp3',
      );
      debugPrint('SEPARATION: vocal download completed (${vocalFile.path})');
      debugPrint('SEPARATION: instrumental download started');
      final instrumentalFile = await _downloadOutput(
        client,
        instrumentalUri,
        outputDirectory,
        'instrumental.mp3',
      );
      debugPrint(
        'SEPARATION: instrumental download completed (${instrumentalFile.path})',
      );
      final files = [vocalFile, instrumentalFile];
      if (files[0].path == files[1].path) {
        throw const SongIntegrationUnavailable(
          'The backend returned the same file for both audio stems.',
        );
      }
      debugPrint('SEPARATION: service returning success');
      return SeparatedSong(
        vocalStem: VocalStem(
          path: files[0].path,
          duration: original.duration,
          analysisUrl: vocalUri.toString(),
        ),
        instrumental: InstrumentalTrack(
          path: files[1].path,
          duration: original.duration,
        ),
      );
    } catch (error) {
      debugPrint('SEPARATION: service failed: $error');
      debugPrint('SEPARATION: temporary output cleanup check started');
      final outputDirectoryExists =
          outputDirectory != null && await outputDirectory.exists();
      debugPrint(
        'SEPARATION: temporary output cleanup check completed; exists=$outputDirectoryExists',
      );
      if (outputDirectory != null && outputDirectoryExists) {
        try {
          debugPrint('SEPARATION: temporary output cleanup started');
          await outputDirectory.delete(recursive: true);
          debugPrint('SEPARATION: temporary output cleanup completed');
        } on FileSystemException {
          // Preserve the original separation/download error.
        }
      }
      if (error is SongIntegrationUnavailable) rethrow;
      if (error is TimeoutException) {
        throw SongIntegrationUnavailable(
          'Stem separation or transfer timed out. Check the Wi-Fi connection and retry. ($error)',
        );
      }
      if (error is SocketException || error is http.ClientException) {
        throw SongIntegrationUnavailable(
          'Could not reach the separation backend at $baseUrl. Make sure the Mac server is running and both devices are on the same Wi-Fi. ($error)',
        );
      }
      throw SongIntegrationUnavailable('Stem separation failed: $error');
    } finally {
      client.close();
    }
  }

  Future<File> _downloadOutput(
    http.Client client,
    Uri uri,
    Directory directory,
    String filename,
  ) async {
    debugPrint('SEPARATION: $filename HTTP request started ($uri)');
    final response = await client
        .send(http.Request('GET', uri))
        .timeout(_responseHeaderTimeout);
    debugPrint(
      'SEPARATION: $filename HTTP response ${response.statusCode}; contentLength=${response.contentLength}',
    );
    if (response.statusCode != HttpStatus.ok) {
      debugPrint('SEPARATION: $filename error response body read started');
      final body = await utf8.decoder
          .bind(response.stream.timeout(_responseInactivityTimeout))
          .join();
      debugPrint('SEPARATION: $filename error response body read completed');
      throw SongIntegrationUnavailable(
        'The backend could not serve $filename (${response.statusCode}): $body',
      );
    }

    final output = File('${directory.path}/$filename');
    debugPrint('SEPARATION: $filename output file open started');
    final sink = output.openWrite();
    debugPrint('SEPARATION: $filename output file open completed');
    try {
      debugPrint('SEPARATION: $filename response stream write started');
      await sink.addStream(response.stream.timeout(_responseInactivityTimeout));
      debugPrint('SEPARATION: $filename response stream write completed');
    } finally {
      debugPrint('SEPARATION: $filename output file close started');
      await sink.close();
      debugPrint('SEPARATION: $filename output file close completed');
    }
    debugPrint('SEPARATION: $filename local existence check started');
    final outputExists = await output.exists();
    debugPrint('SEPARATION: $filename local exists=$outputExists');
    if (!outputExists) {
      throw SongIntegrationUnavailable(
        'The downloaded $filename file is missing or empty.',
      );
    }
    debugPrint('SEPARATION: $filename local length check started');
    final outputLength = await output.length();
    debugPrint('SEPARATION: $filename local length=$outputLength');
    if (outputLength == 0) {
      throw SongIntegrationUnavailable(
        'The downloaded $filename file is missing or empty.',
      );
    }
    return output;
  }

  Uri _validatedOutputUri(Object? value) {
    if (value is! String) {
      throw const SongIntegrationUnavailable(
        'The backend did not return both separated audio URLs.',
      );
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        _isLoopback(uri.host)) {
      throw SongIntegrationUnavailable(
        'The backend returned an unusable audio URL: $value',
      );
    }
    return uri;
  }

  bool _isLoopback(String host) {
    final normalizedHost = host.toLowerCase();
    if (normalizedHost == 'localhost') return true;
    final address = InternetAddress.tryParse(normalizedHost);
    return address?.isLoopback ?? false;
  }

  String _responseError(String body, int statusCode) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        return 'Separation backend returned $statusCode: ${decoded['detail']}';
      }
    } on FormatException {
      // Keep the original body below when an error is not JSON.
    }
    return 'Separation backend returned $statusCode: $body';
  }
}

class SongIntegrationUnavailable implements Exception {
  final String message;

  const SongIntegrationUnavailable(this.message);

  @override
  String toString() => message;
}
