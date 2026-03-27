import 'package:http/http.dart' as http;
import 'package:webfeed_plus/webfeed_plus.dart';
import 'package:html/parser.dart';
import '../models/article_model.dart';

class RssService {
  static const String feedUrl = 'https://feeds.bbci.co.uk/news/world/rss.xml'; // Using BBC News as VOA might be blocked in some regions

  Future<List<Article>> fetchArticles() async {
    try {
      final response = await http.get(Uri.parse(feedUrl));

      if (response.statusCode == 200) {
        final rssFeed = RssFeed.parse(response.body);
        
        return rssFeed.items?.map((item) {
          // Strip HTML from description for a cleaner preview
          final document = parse(item.description ?? '');
          final plainDescription = parse(document.body?.text ?? '').documentElement?.text ?? '';
          
          // Using description as content if full content is not consistently available
          final fullContent = item.description ?? '';
          final contentDocument = parse(fullContent);
          final plainContent = parse(contentDocument.body?.text ?? '').documentElement?.text ?? '';

          return Article(
            title: item.title ?? 'No Title',
            description: plainDescription,
            pubDate: item.pubDate?.toString() ?? 'Unknown date',
            link: item.link ?? '',
            content: plainContent,
          );
        }).toList() ?? [];
      } else {
        throw Exception('Failed to load RSS feed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching RSS feed: $e');
    }
  }
}
