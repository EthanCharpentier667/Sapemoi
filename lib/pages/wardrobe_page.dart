import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import '../models.dart';

class WardrobePage extends StatelessWidget {
  final List<Clothing> clothes;
  final String searchText;
  final Function(String) onSearchChanged;
  final VoidCallback onAddPressed;
  final Function(Clothing) onClothingTap;

  const WardrobePage({
    super.key,
    required this.clothes,
    required this.searchText,
    required this.onSearchChanged,
    required this.onAddPressed,
    required this.onClothingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text(
                        'Sapemoi',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.add_circle, size: 32),
                        onPressed: onAddPressed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search clothing...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildClothesGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClothesGrid() {
    final filtered = searchText.isEmpty
        ? clothes
        : clothes.where((c) {
            final query = searchText.toLowerCase();
            return c.name.toLowerCase().contains(query) ||
                   c.type.toLowerCase().contains(query) ||
                   c.brand.toLowerCase().contains(query) ||
                   c.productName.toLowerCase().contains(query);
          }).toList();

    if (filtered.isEmpty) {
      return const Center(
        child: Text('No clothing items found'),
      );
    }

    final grouped = <String, List<Clothing>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.type, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: grouped.keys.length,
      itemBuilder: (context, index) {
        final type = grouped.keys.elementAt(index);
        final items = grouped[type]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Text(
                    type.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} item${items.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                return ClothingCard(
                  clothing: items[i],
                  onTap: () => onClothingTap(items[i]),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class ClothingCard extends StatelessWidget {
  final Clothing clothing;
  final VoidCallback onTap;

  const ClothingCard({
    super.key,
    required this.clothing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: clothing.imageBase64 != null
                    ? Image.memory(
                        base64Decode(clothing.imageBase64!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Image.file(
                        File(clothing.imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stack) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image, size: 48),
                          );
                        },
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clothing.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    clothing.brand,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
