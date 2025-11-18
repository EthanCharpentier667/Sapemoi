import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import '../auth_manager.dart';
import '../db_manager.dart';
import '../network_manager.dart';
import '../models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Clothing> _clothes = [];
  double? _wardrobeValue;
  bool _loadingValue = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final clothes = await DBManager().getAllClothes(user.uid);
    final total = await DBManager().getTotalWardrobeValue(user.uid);
    
    setState(() {
      _clothes = clothes;
      if (total > 0) {
        _wardrobeValue = total;
      }
    });
  }

  Future<void> _estimateWardrobeValue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _loadingValue = true);

    try {
      final unvaluedIds = await DBManager().getUnvaluedClothingIds(user.uid);
      
      if (unvaluedIds.isNotEmpty) {
        final unvaluedItems = _clothes.where((c) => unvaluedIds.contains(c.id)).map((c) => {
          'id': c.id,
          'brand': c.brand,
          'product': c.productName,
          'type': c.type,
          'specificType': c.specificType,
        }).toList();

        final result = await NetworkManager().estimateWardrobeValue(unvaluedItems);
        final breakdown = result['breakdown'] as List<dynamic>;
        
        for (var i = 0; i < breakdown.length; i++) {
          final item = breakdown[i] as Map<String, dynamic>;
          final estimatedValue = (item['estimatedValue'] as num).toDouble();
          final clothingId = unvaluedItems[i]['id'] as int;
          await DBManager().updateEstimatedValue(clothingId, estimatedValue);
        }
      }
      
      final total = await DBManager().getTotalWardrobeValue(user.uid);
      await _loadData();
      
      setState(() {
        _wardrobeValue = total;
        _loadingValue = false;
      });
    } catch (e) {
      setState(() => _loadingValue = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error estimating value: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('No user logged in')),
      );
    }

    final mostWorn = [..._clothes]..sort((a, b) => b.wearCount.compareTo(a.wearCount));
    final leastWorn = [..._clothes]..sort((a, b) => a.wearCount.compareTo(b.wearCount));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              user.displayName ?? 'Anonymous',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.email ?? '',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.attach_money, color: Colors.green, size: 32),
                        const SizedBox(width: 12),
                        const Text(
                          'Wardrobe Value',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _loadingValue ? null : _estimateWardrobeValue,
                          child: _loadingValue
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(_wardrobeValue == null ? 'Estimate' : 'Re-estimate'),
                        ),
                      ],
                    ),
                    if (_wardrobeValue != null) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Text(
                          '\$${_wardrobeValue!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          'Based on ${_clothes.length} items',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 32),
                        SizedBox(width: 12),
                        Text(
                          'Most Worn Items',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (mostWorn.isEmpty)
                      const Center(
                        child: Text('No items worn yet'),
                      )
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: mostWorn.take(5).length,
                          itemBuilder: (context, index) {
                            final item = mostWorn[index];
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.amber, width: 2),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
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
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.wearCount}x worn',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.shopping_bag_outlined, color: Colors.orange, size: 32),
                        SizedBox(width: 12),
                        Text(
                          'Least Worn Items',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Consider selling these items',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (leastWorn.isEmpty)
                      const Center(
                        child: Text('No items to show'),
                      )
                    else
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: leastWorn.take(5).length,
                          itemBuilder: (context, index) {
                            final item = leastWorn[index];
                            return Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.orange, width: 2),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
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
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.wearCount == 0 ? 'Never worn' : '${item.wearCount}x worn',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildInfoRow(
                      icon: Icons.email,
                      label: 'Email',
                      value: user.email ?? 'N/A',
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(
                      icon: Icons.badge,
                      label: 'User ID',
                      value: user.uid.substring(0, 12) + '...',
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(
                      icon: Icons.verified_user,
                      label: 'Email Verified',
                      value: user.emailVerified ? 'Yes' : 'No',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                await AuthManager().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.purple),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
