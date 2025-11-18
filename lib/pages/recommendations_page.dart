import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../models.dart';
import '../recommendation_engine.dart';
import 'package:url_launcher/url_launcher.dart';

class RecommendationsPage extends StatefulWidget {
  final List<Clothing> clothes;
  final VoidCallback onUpdate;

  const RecommendationsPage({
    super.key,
    required this.clothes,
    required this.onUpdate,
  });

  @override
  State<RecommendationsPage> createState() => _RecommendationsPageState();
}

class _RecommendationsPageState extends State<RecommendationsPage> {
  List<MissingPieceRecommendation> recommendations = [];
  bool isGenerating = false;
  StyleProfile? userStyle;

  @override
  void initState() {
    super.initState();
    _generateRecommendations();
  }

  void _generateRecommendations() {
    if (widget.clothes.length < 3) {
      return;
    }

    setState(() => isGenerating = true);

    // Analyser le style de l'utilisateur
    userStyle = StyleProfile.fromClothes(widget.clothes);

    // Générer les recommandations
    final recs = RecommendationEngine.generateRecommendations(
      widget.clothes,
      userStyle!,
      maxRecommendations: 5,
      boldMode: false,
    );

    setState(() {
      recommendations = recs;
      isGenerating = false;
    });
  }

  Future<void> _openSearchLink(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open link: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Recommendations'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateRecommendations,
          ),
        ],
      ),
      body: widget.clothes.length < 3
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Add at least 3 items to get personalized recommendations',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            )
          : isGenerating
              ? const Center(child: CircularProgressIndicator())
              : recommendations.isEmpty
                  ? const Center(
                      child: Text(
                        'No recommendations found.\nTry adding more varied items!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: [
                        if (userStyle != null) _buildStyleHeader(),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: recommendations.length,
                            itemBuilder: (context, index) {
                              return _buildRecommendationCard(recommendations[index]);
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildStyleHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple.shade400, Colors.purple.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'Your Style: ${_capitalizeFirst(userStyle!.styleType)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (userStyle!.topBrands.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Favorite brands: ${userStyle!.topBrands.map((b) => _capitalizeFirst(b)).join(", ")}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(MissingPieceRecommendation rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec score
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.deepOrange.shade600],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _capitalizeFirst(rec.specificType),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${rec.currentScore.toInt()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.arrow_forward, color: Colors.white70, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '${rec.potentialScore.toInt()}%',
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '+${(rec.potentialScore - rec.currentScore).toInt()}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Couleur cible
                Row(
                  children: [
                    const Text(
                      'Target color:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(
                          rec.targetColor.r,
                          rec.targetColor.g,
                          rec.targetColor.b,
                          1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300, width: 2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'RGB(${rec.targetColor.r}, ${rec.targetColor.g}, ${rec.targetColor.b})',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Raison
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          rec.reason,
                          style: TextStyle(
                            color: Colors.blue.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Suggested brands
                if (rec.suggestedBrands.isNotEmpty) ...[
                  const Text(
                    'Suggested brands:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rec.suggestedBrands.map((brand) {
                      return Chip(
                        label: Text(_capitalizeFirst(brand)),
                        backgroundColor: Colors.purple.shade50,
                        labelStyle: TextStyle(color: Colors.purple.shade700),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Outfit existant (aperçu)
                const Text(
                  'With this outfit:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: rec.existingOutfit.length,
                    itemBuilder: (context, index) {
                      final item = rec.existingOutfit[index];
                      return Container(
                        width: 70,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: item.imageBase64 != null
                              ? Image.memory(
                                  base64Decode(item.imageBase64!),
                                  fit: BoxFit.cover,
                                )
                              : Image.file(
                                  File(item.imagePath),
                                  fit: BoxFit.cover,
                                ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Liens de recherche
                const Text(
                  'Where to buy:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildSearchButton(
                      'Vinted',
                      Icons.shopping_bag,
                      Colors.teal,
                      () => _openSearchLink(_generateVintedUrl(rec)),
                    ),
                    _buildSearchButton(
                      'Google',
                      Icons.search,
                      Colors.blue,
                      () => _openSearchLink(_generateGoogleUrl(rec)),
                    ),
                    _buildSearchButton(
                      'eBay',
                      Icons.store,
                      Colors.red,
                      () => _openSearchLink(_generateEbayUrl(rec)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  String _generateVintedUrl(MissingPieceRecommendation rec) {
    final query = rec.searchKeywords.isNotEmpty
        ? rec.searchKeywords.first
        : '${rec.suggestedBrands.isNotEmpty ? rec.suggestedBrands.first : ''} ${rec.specificType}';
    return 'https://www.vinted.fr/catalog?search_text=${Uri.encodeComponent(query)}';
  }

  String _generateGoogleUrl(MissingPieceRecommendation rec) {
    final query = rec.searchKeywords.isNotEmpty
        ? rec.searchKeywords.first
        : '${rec.suggestedBrands.isNotEmpty ? rec.suggestedBrands.first : ''} ${rec.specificType}';
    return 'https://www.google.com/search?tbm=shop&q=${Uri.encodeComponent(query)}';
  }

  String _generateEbayUrl(MissingPieceRecommendation rec) {
    final query = rec.searchKeywords.isNotEmpty
        ? rec.searchKeywords.first
        : '${rec.suggestedBrands.isNotEmpty ? rec.suggestedBrands.first : ''} ${rec.specificType}';
    return 'https://www.ebay.fr/sch/i.html?_nkw=${Uri.encodeComponent(query)}';
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}
