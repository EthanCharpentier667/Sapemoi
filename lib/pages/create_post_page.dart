import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../models.dart';
import '../db_manager.dart';
import '../auth_manager.dart';
import '../network_manager.dart';

class CreatePostPage extends StatefulWidget {
  final List<Clothing> outfitItems;

  const CreatePostPage({super.key, required this.outfitItems});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  File? _imageFile;
  final TextEditingController _descriptionController = TextEditingController();
  bool _isUploading = false;
  bool _useGeneratedImage = false;
  final GlobalKey _outfitPreviewKey = GlobalKey();

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _publishPost() async {
    if (_imageFile == null && !_useGeneratedImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a photo or use generated outfit image')),
      );
      return;
    }

    if (widget.outfitItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No outfit items selected')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final userModel = await AuthManager().getLocalUser();
      if (userModel == null) {
        throw Exception('User not authenticated');
      }

      String? imageUrl;

      if (_useGeneratedImage) {
        imageUrl = await _generateOutfitImage();
        if (imageUrl == null) {
          throw Exception('Failed to generate outfit image');
        }
      } else {
        final bytes = await _imageFile!.readAsBytes();
        final base64Image = base64Encode(bytes);
        imageUrl = await NetworkManager().uploadImage(base64Image, 'outfit_posts');

        if (imageUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      final itemsList = widget.outfitItems
          .map((item) => '${item.brand} - ${item.name}')
          .join('\n');
      
      final userDescription = _descriptionController.text.trim();
      final fullDescription = userDescription.isEmpty
          ? itemsList
          : '$userDescription\n\n$itemsList';
      
      final clothingIds = widget.outfitItems.map((c) => c.id).toList();
      final postId = await DBManager().createOutfitPost(
        userId: userModel.uid,
        imageUrl: imageUrl,
        description: fullDescription,
        clothingIds: clothingIds,
      );

      if (postId != null && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✨ Outfit posted!')),
        );
      } else {
        throw Exception('Failed to create post');
      }
    } catch (e) {
      print('Error publishing post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<String?> _generateOutfitImage() async {
    try {
      final boundary = _outfitPreviewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      final base64Image = base64Encode(bytes);

      return await NetworkManager().uploadImage(base64Image, 'outfit_posts');
    } catch (e) {
      print('Error generating outfit image: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Your Outfit'),
        actions: [
          if (_isUploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _publishPost,
              child: const Text(
                'Post',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_imageFile != null || _useGeneratedImage)
              GestureDetector(
                onTap: _isUploading ? null : () => _showImageOptionsDialog(),
                child: Container(
                  width: double.infinity,
                  height: 400,
                  color: Colors.grey[200],
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : _buildGeneratedOutfitPreview(),
                ),
              )
            else
              _buildImageSelectionOptions(),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      hintText: 'Add a caption... (optional)',
                      border: InputBorder.none,
                    ),
                    maxLines: 3,
                    enabled: !_isUploading,
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Items in this outfit:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...widget.outfitItems.map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              item.imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  item.brand,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.type,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.purple[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelectionOptions() {
    return Container(
      width: double.infinity,
      height: 400,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.purple[50]!,
            Colors.purple[100]!,
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.collections,
                size: 48,
                color: Colors.purple[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Choose how to share',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple[900],
                ),
              ),
              const SizedBox(height: 20),
              
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt, size: 20),
                label: const Text('Take a Photo'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  textStyle: const TextStyle(fontSize: 15),
                ),
              ),
              
              const SizedBox(height: 12),
              
              ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library, size: 20),
                label: const Text('Choose from Gallery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  textStyle: const TextStyle(fontSize: 15),
                ),
              ),
              
              const SizedBox(height: 16),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _useGeneratedImage = true;
                    _imageFile = null;
                  });
                },
                icon: const Icon(Icons.auto_awesome, size: 20),
                label: const Text('Use Outfit Collage'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.purple,
                  side: const BorderSide(color: Colors.purple, width: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  textStyle: const TextStyle(fontSize: 15),
                ),
              ),
              
              const SizedBox(height: 6),
              Text(
                'No photo of you needed!',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGeneratedOutfitPreview() {
    final sortedItems = List<Clothing>.from(widget.outfitItems)
      ..sort((a, b) => a.layer.compareTo(b.layer));

    return RepaintBoundary(
      key: _outfitPreviewKey,
      child: Container(
        color: Colors.white,
        child: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: sortedItems.length <= 2 ? 2 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.0,
          ),
          itemCount: sortedItems.length,
          itemBuilder: (context, index) {
            final item = sortedItems[index];
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
              ),
            );
          },
        ),
      ),
    );
  }

  void _showImageOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change image?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _useGeneratedImage = false;
                });
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _useGeneratedImage = false;
                });
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Use Outfit Collage'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _useGeneratedImage = true;
                  _imageFile = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
