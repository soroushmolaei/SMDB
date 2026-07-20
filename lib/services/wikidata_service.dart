import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class WikidataAward {
  final String name;
  final String result; // 'Won' or 'Nominated'
  final int? year;
  WikidataAward({required this.name, required this.result, this.year});
}

/// Fetches structured award data from Wikidata, looked up by IMDb id.
///
/// TMDB and OMDb only offer award info as an unstructured summary string
/// (e.g. "Won 4 Oscars. 120 wins & 89 nominations total"), which isn't
/// precise enough to show as a real list. Wikidata models "award received"
/// (P166) and "nominated for" (P1411) as structured statements, keyed off
/// properties like IMDb id (P345), so a SPARQL query against the public
/// Wikidata Query Service can return an actual list of named awards with
/// years and won/nominated status.
///
/// This is intentionally used lazily (only when a detail page is opened),
/// not during bulk scanning — SPARQL queries are heavier than a normal
/// REST call and award data rarely changes.
class WikidataService {
  static const String _endpoint = 'https://query.wikidata.org/sparql';

  final String? proxyHost;
  final int? proxyPort;

  WikidataService({this.proxyHost, this.proxyPort});

  http.Client _buildClient() {
    final httpClient = HttpClient();
    httpClient.connectionTimeout = const Duration(seconds: 8);
    if (proxyHost != null &&
        proxyHost!.isNotEmpty &&
        proxyPort != null &&
        proxyPort != 0) {
      httpClient.findProxy = (uri) => 'PROXY $proxyHost:$proxyPort';
      httpClient.badCertificateCallback = (cert, host, port) => false;
    }
    return IOClient(httpClient);
  }

  /// Looks up awards for the work with the given IMDb id (e.g.
  /// "tt0111161"). Returns an empty list if the item isn't on Wikidata or
  /// has no award statements — this is common and not an error.
  Future<List<WikidataAward>> getAwardsByImdbId(String imdbId) async {
    final query = '''
SELECT ?awardLabel ?result ?year WHERE {
  ?item wdt:P345 "$imdbId" .
  {
    ?item p:P166 ?statement .
    ?statement ps:P166 ?award .
    OPTIONAL { ?statement pq:P585 ?date . }
    BIND("Won" AS ?result)
  } UNION {
    ?item p:P1411 ?statement .
    ?statement ps:P1411 ?award .
    OPTIONAL { ?statement pq:P585 ?date . }
    BIND("Nominated" AS ?result)
  }
  BIND(YEAR(?date) AS ?year)
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en" . }
}
ORDER BY ?result ?year
LIMIT 100
''';

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'query': query,
      'format': 'json',
    });

    final client = _buildClient();
    try {
      final response = await client.get(
        uri,
        headers: {
          // Wikidata's usage policy asks for a descriptive User-Agent on
          // the public query service.
          'User-Agent': 'SMDB/1.0 (personal media library app)',
          'Accept': 'application/sparql-results+json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return [];

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final bindings =
          (data['results']?['bindings'] as List<dynamic>?) ?? [];

      final results = <WikidataAward>[];
      for (final b in bindings) {
        final row = b as Map<String, dynamic>;
        final name = row['awardLabel']?['value'] as String?;
        final result = row['result']?['value'] as String?;
        if (name == null || result == null) continue;
        final yearStr = row['year']?['value'] as String?;
        results.add(WikidataAward(
          name: name,
          result: result,
          year: yearStr != null ? int.tryParse(yearStr) : null,
        ));
      }
      return results;
    } catch (_) {
      // Award data is a nice-to-have; never let a lookup failure break the
      // detail page.
      return [];
    } finally {
      client.close();
    }
  }
}
