import 'package:flutter/material.dart';
import '../models.dart';
import 'outfit_generator_page.dart';
import 'complex_outfit_page.dart';

class OutfitsTabPage extends StatefulWidget {
  final List<Clothing> clothes;
  final VoidCallback onUpdate;

  const OutfitsTabPage({
    super.key,
    required this.clothes,
    required this.onUpdate,
  });

  @override
  State<OutfitsTabPage> createState() => _OutfitsTabPageState();
}

class _OutfitsTabPageState extends State<OutfitsTabPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outfits'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(
              icon: Icon(Icons.auto_awesome),
              text: 'Quick Generate',
            ),
            Tab(
              icon: Icon(Icons.layers),
              text: 'Custom Builder',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          OutfitGeneratorPage(
            clothes: widget.clothes,
            onUpdate: widget.onUpdate,
            isEmbedded: true,
          ),
          const ComplexOutfitPage(),
        ],
      ),
    );
  }
}
