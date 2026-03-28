import 'package:http/http.dart' as http;
import 'package:webfeed_plus/webfeed_plus.dart';
import 'package:html/parser.dart';

import '../models/article_model.dart';

/// Fetches and parses articles from a real English-language RSS feed.
/// The BBC World News feed is used as the default source because it is
/// reliably accessible and returns rich media metadata.
class RssService {
  static const String _feedUrl =
      'https://feeds.bbci.co.uk/news/world/rss.xml';

  /// Primary entry point used by the News screen.
  /// Returns a list of [Article] objects parsed from the RSS XML.
  Future<List<Article>> fetchNews() => _fetch(_feedUrl);

  /// Backward-compatible alias kept for widgets that already call this.
  Future<List<Article>> fetchArticles() => _fetch(_feedUrl);

  // ── Internal implementation ──────────────────────────────────────────────

  Future<List<Article>> _fetch(String url) async {
    final http.Response response;

    try {
      response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw Exception('Network error while fetching RSS feed: $e');
    }

    if (response.statusCode != 200) {
      throw Exception(
          'RSS feed returned HTTP ${response.statusCode}');
    }

    final RssFeed rssFeed;
    try {
      rssFeed = RssFeed.parse(response.body);
    } catch (e) {
      throw Exception('Failed to parse RSS XML: $e');
    }

    final List<RssItem> items = rssFeed.items ?? [];
    if (items.isEmpty) return [];

    final String feedTitle = rssFeed.title ?? 'RSS Feed';

    return items.map((item) => _mapItem(item, feedTitle)).toList();
  }

  Article _mapItem(RssItem item, String feedTitle) {
    // Strip HTML tags from description for a clean text preview.
    final String rawDescription = item.description ?? '';
    final String plainDescription =
        parse(parse(rawDescription).body?.text ?? '').documentElement?.text ??
            '';

    final String title = item.title ?? 'No Title';
    final String link = item.link?.toString() ?? '';
    final String articleId =
        item.guid ?? (link.isNotEmpty ? link : title);

    // BBC attaches images via <media:content>; fall back to null if absent.
    String? imageUrl;
    final media = item.media;
    if (media != null &&
        media.contents != null &&
        media.contents!.isNotEmpty) {
      imageUrl = media.contents!.first.url;
    }

    return Article(
      articleId: articleId,
      title: title,
      source: feedTitle,
      link: link,
      pubDate: item.pubDate ?? DateTime.now(),
      imageUrl: imageUrl,
      description: plainDescription,
    );
  }
}
