import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class OmdbException implements Exception {
  final String message;
  OmdbException(this.message);
  @override
  String toString() => 'OmdbException: $message';
}

class _RetryableError implements Exception {
  final String message;
  _RetryableError(this.message);
}

/// Thin client for the OMDb (omdbapi.com) API — an alternative metadata
/// source backed by IMDb data. Useful when TMDB is unreachable, since it's
/// on different hosting and may not be affected by the same network
/// filtering.
class OmdbService {
  static const String _baseUrl = 'https://www.omdbapi.com/';

  final String apiKey;
  final String? proxyHost;
  final int? proxyPort;

  OmdbService({required this.apiKey, this.proxyHost, this.proxyPort});

  void _applyProxy(HttpClient httpClient) {
    if (proxyHost != null &&
        proxyHost!.isNotEmpty &&
        proxyPort != null &&
        proxyPort != 0) {
      httpClient.findProxy = (uri) => 'PROXY $proxyHost:$proxyPort';
      httpClient.badCertificateCallback = (cert, host, port) => false;
    }
  }

  http.Client _buildDefaultClient() {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 6);
    _applyProxy(httpClient);
    return IOClient(httpClient);
  }

  http.Client _buildIPv4Client() {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 6);
    httpClient.connectionFactory = (uri, proxyHost, proxyPort) async {
      final targetHost = proxyHost ?? uri.host;
      final targetPort = proxyPort ?? uri.port;
      final addresses = await InternetAddress.lookup(targetHost);
      final ipv4 =
          addresses.where((a) => a.type == InternetAddressType.IPv4);
      final target = ipv4.isNotEmpty ? ipv4.first : addresses.first;
      return Socket.startConnect(target, targetPort);
    };
    _applyProxy(httpClient);
    return IOClient(httpClient);
  }

  Future<Map<String, dynamic>> _attempt(
    Uri uri,
    http.Client client,
  ) async {
    try {
      final response =
          await client.get(uri).timeout(const Duration(seconds: 7));
      if (response.statusCode != 200) {
        throw OmdbException('OMDb request failed (${response.statusCode})');
      }
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on SocketException catch (e) {
      throw _RetryableError(e.osError?.message ?? e.message);
    } on TimeoutException {
      throw _RetryableError('timed out after 7s');
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _get(Map<String, String> query) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {'apikey': apiKey, ...query},
    );

    final errors = <String>[];

    try {
      return await _attempt(uri, _buildDefaultClient());
    } on _RetryableError catch (e) {
      errors.add('default: ${e.message}');
    }

    try {
      return await _attempt(uri, _buildIPv4Client());
    } on _RetryableError catch (e) {
      errors.add('IPv4-direct: ${e.message}');
    }

    throw OmdbException(
      'Could not reach OMDb after two attempts (${errors.join(" | ")}).',
    );
  }

  /// Looks up a movie by title (and optional year), trying an exact title
  /// match first, then falling back to a fuzzy search. Returns the raw OMDb
  /// JSON object, or null if nothing was found.
  Future<Map<String, dynamic>?> lookupMovie(String title, {int? year}) async {
    final direct = await _get({
      't': title,
      'type': 'movie',
      'plot': 'full',
      if (year != null) 'y': '$year',
    });
    if (direct['Response'] == 'True') return direct;

    final search = await _get({'s': title, 'type': 'movie'});
    if (search['Response'] == 'True') {
      final results = search['Search'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        final imdbId = results.first['imdbID'] as String?;
        if (imdbId != null) {
          final details = await _get({'i': imdbId, 'plot': 'full'});
          if (details['Response'] == 'True') return details;
        }
      }
    }
    return null;
  }

  /// Looks up a TV show by title, same strategy as [lookupMovie].
  Future<Map<String, dynamic>?> lookupShow(String title) async {
    final direct = await _get({'t': title, 'type': 'series', 'plot': 'full'});
    if (direct['Response'] == 'True') return direct;

    final search = await _get({'s': title, 'type': 'series'});
    if (search['Response'] == 'True') {
      final results = search['Search'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        final imdbId = results.first['imdbID'] as String?;
        if (imdbId != null) {
          final details = await _get({'i': imdbId, 'plot': 'full'});
          if (details['Response'] == 'True') return details;
        }
      }
    }
    return null;
  }

  static String? posterUrl(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'N/A') return null;
    return raw;
  }

  static double? parseRating(String? imdbRating) {
    if (imdbRating == null || imdbRating == 'N/A') return null;
    return double.tryParse(imdbRating);
  }

  static int? parseRuntimeMinutes(String? runtime) {
    if (runtime == null || runtime == 'N/A') return null;
    final match = RegExp(r'(\d+)').firstMatch(runtime);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
