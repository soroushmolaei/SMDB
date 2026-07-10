import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Thrown when a TMDB request fails.
class TmdbException implements Exception {
  final String message;
  TmdbException(this.message);
  @override
  String toString() => 'TmdbException: $message';
}

class TmdbMovieResult {
  final int id;
  final String title;
  final String? originalTitle;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? releaseDate;
  final double? voteAverage;

  TmdbMovieResult({
    required this.id,
    required this.title,
    this.originalTitle,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    this.voteAverage,
  });

  factory TmdbMovieResult.fromJson(Map<String, dynamic> json) {
    return TmdbMovieResult(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? '',
      originalTitle: json['original_title'] as String?,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      releaseDate: json['release_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
    );
  }

  int? get year {
    if (releaseDate == null || releaseDate!.length < 4) return null;
    return int.tryParse(releaseDate!.substring(0, 4));
  }
}

class TmdbShowResult {
  final int id;
  final String name;
  final String? originalName;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final String? firstAirDate;
  final double? voteAverage;

  TmdbShowResult({
    required this.id,
    required this.name,
    this.originalName,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.firstAirDate,
    this.voteAverage,
  });

  factory TmdbShowResult.fromJson(Map<String, dynamic> json) {
    return TmdbShowResult(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      originalName: json['original_name'] as String?,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      firstAirDate: json['first_air_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
    );
  }
}

/// Thin client for the TMDB (themoviedb.org) v3 REST API.
///
/// If [proxyHost]/[proxyPort] are supplied, requests are routed through that
/// HTTP proxy. This is useful on networks where api.themoviedb.org is
/// filtered and a local proxy (e.g. from a VPN client) is available.
class TmdbService {
  static const String _baseUrl = 'https://api.themoviedb.org/3';
  static const String imageBaseUrl = 'https://image.tmdb.org/t/p';

  final String apiKey;
  final String? proxyHost;
  final int? proxyPort;
  final String language;

  TmdbService({
    required this.apiKey,
    this.proxyHost,
    this.proxyPort,
    this.language = 'en-US',
  });

  http.Client _buildClient() {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 10);

    // Prefer IPv4 when connecting. If a browser can reach a host instantly
    // but dart:io hangs until timeout, it is almost always a broken/
    // blackholed IPv6 route: browsers fall back to IPv4 quickly (Happy
    // Eyeballs), dart:io does not do this as reliably. Resolving manually
    // and connecting to an IPv4 address directly avoids that hang.
    httpClient.connectionFactory = (uri, proxyHost, proxyPort) async {
      final targetHost = proxyHost ?? uri.host;
      final targetPort = proxyPort ?? uri.port;
      final addresses = await InternetAddress.lookup(targetHost);
      final ipv4 = addresses.where((a) => a.type == InternetAddressType.IPv4);
      final target = ipv4.isNotEmpty ? ipv4.first : addresses.first;
      return Socket.startConnect(target, targetPort);
    };

    if (proxyHost != null &&
        proxyHost!.isNotEmpty &&
        proxyPort != null &&
        proxyPort != 0) {
      httpClient.findProxy = (uri) => 'PROXY $proxyHost:$proxyPort';
      httpClient.badCertificateCallback = (cert, host, port) => false;
    }
    return IOClient(httpClient);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> query,
  ) async {
    final client = _buildClient();
    try {
      final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: {
        'api_key': apiKey,
        'language': language,
        ...query,
      });
      final response = await client.get(uri).timeout(
            const Duration(seconds: 20),
          );
      if (response.statusCode != 200) {
        throw TmdbException(
          'TMDB request failed (${response.statusCode}) for $path',
        );
      }
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on SocketException {
      throw TmdbException(
        'Could not reach TMDB (connection failed). If you are on a '
        'filtered network, set a proxy in Settings.',
      );
    } on TimeoutException {
      throw TmdbException(
        'TMDB took too long to respond (20s timeout). If this keeps '
        'happening, try setting a proxy in Settings.',
      );
    } finally {
      client.close();
    }
  }

  Future<List<TmdbMovieResult>> searchMovie(String query, {int? year}) async {
    final data = await _get('/search/movie', {
      'query': query,
      if (year != null) 'year': '$year',
    });
    final results = (data['results'] as List<dynamic>? ?? []);
    return results
        .map((r) => TmdbMovieResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getMovieDetails(int tmdbId) {
    return _get('/movie/$tmdbId', {'append_to_response': 'credits'});
  }

  Future<List<TmdbShowResult>> searchTvShow(String query) async {
    final data = await _get('/search/tv', {'query': query});
    final results = (data['results'] as List<dynamic>? ?? []);
    return results
        .map((r) => TmdbShowResult.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getShowDetails(int tmdbId) {
    return _get('/tv/$tmdbId', {});
  }

  Future<Map<String, dynamic>> getSeasonDetails(
    int tmdbId,
    int seasonNumber,
  ) {
    return _get('/tv/$tmdbId/season/$seasonNumber', {});
  }

  static String? imageUrl(String? path, {String size = 'w500'}) {
    if (path == null || path.isEmpty) return null;
    return '$imageBaseUrl/$size$path';
  }
}
