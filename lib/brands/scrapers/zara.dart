import 'package:http/http.dart' as http;

class ZaraScraper {
  /// Scrape product info from Zara QR deep link
  static Future<String?> getProductName(String productCode) async {
    try {
      final url = 'http://www.zara.com/qr/$productCode';
      print('🌐 Fetching Zara product: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      );
      
      print('📥 Zara response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('⚠️ Failed to fetch Zara page: ${response.statusCode}');
        return null;
      }
      
      final html = response.body;
      print('📄 Response length: ${html.length} chars');
      print('📄 First 500 chars: ${html.substring(0, html.length > 500 ? 500 : html.length)}');
      
      // Try to extract product name from various HTML elements
      String? productName;
      
      // Try meta og:title
      final ogTitleRegex = RegExp(
        r'<meta[^>]*property="og:title"[^>]*content="([^"]+)"',
        caseSensitive: false,
      );
      final ogTitleMatch = ogTitleRegex.firstMatch(html);
      if (ogTitleMatch != null) {
        productName = ogTitleMatch.group(1)?.replaceAll(RegExp(r'\s*\|\s*ZARA.*', caseSensitive: false), '').trim();
        if (productName != null && productName.isNotEmpty) {
          print('✅ Found og:title: "$productName"');
          return productName;
        }
      }
      
      // Try meta twitter:title
      final twitterTitleRegex = RegExp(
        r'<meta[^>]*name="twitter:title"[^>]*content="([^"]+)"',
        caseSensitive: false,
      );
      final twitterTitleMatch = twitterTitleRegex.firstMatch(html);
      if (twitterTitleMatch != null) {
        productName = twitterTitleMatch.group(1)?.replaceAll(RegExp(r'\s*\|\s*ZARA.*', caseSensitive: false), '').trim();
        if (productName != null && productName.isNotEmpty) {
          print('✅ Found twitter:title: "$productName"');
          return productName;
        }
      }
      
      // Try <title> tag
      final titleRegex = RegExp(
        r'<title[^>]*>([^<]+)</title>',
        caseSensitive: false,
      );
      final titleMatch = titleRegex.firstMatch(html);
      if (titleMatch != null) {
        productName = titleMatch.group(1)?.replaceAll(RegExp(r'\s*\|\s*ZARA.*', caseSensitive: false), '').trim();
        if (productName != null && productName.isNotEmpty) {
          print('✅ Found title: "$productName"');
          return productName;
        }
      }
      
      // Try h1 tag with product class
      final h1Regex = RegExp(
        r'<h1[^>]*class="[^"]*product[^"]*"[^>]*>([^<]+)</h1>',
        caseSensitive: false,
      );
      final h1Match = h1Regex.firstMatch(html);
      if (h1Match != null) {
        productName = h1Match.group(1)?.trim();
        if (productName != null && productName.isNotEmpty) {
          print('✅ Found h1: "$productName"');
          return productName;
        }
      }
      
      // Try any h1 tag
      final anyH1Regex = RegExp(
        r'<h1[^>]*>([^<]+)</h1>',
        caseSensitive: false,
      );
      final anyH1Match = anyH1Regex.firstMatch(html);
      if (anyH1Match != null) {
        productName = anyH1Match.group(1)?.trim();
        if (productName != null && productName.isNotEmpty && !productName.toLowerCase().contains('zara')) {
          print('✅ Found h1 (any): "$productName"');
          return productName;
        }
      }
      
      print('⚠️ Could not extract product name from HTML');
      return null;
      
    } catch (e) {
      print('❌ Error fetching Zara product: $e');
      return null;
    }
  }
}
