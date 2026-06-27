import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product_model.dart';
import '../providers/products_notifier.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final ProductModel product;

  const EditProductScreen({
    super.key,
    required this.product,
  });

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _thresholdController;

  final ImagePicker _picker = ImagePicker();

  bool _isUploadingImage = false;
  String? _imageUrl;
  String? _localMessage;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.product.name);
    _priceController = TextEditingController(
      text: widget.product.price.toString(),
    );
    _stockController = TextEditingController(
      text: widget.product.stockCount.toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.product.description ?? '',
    );
    _thresholdController = TextEditingController(
      text: widget.product.lowStockThreshold.toString(),
    );

    _imageUrl = widget.product.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _descriptionController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedImage = await _picker.pickImage(
        source: source,
        imageQuality: 75,
      );

      if (pickedImage == null) return;

      setState(() {
        _isUploadingImage = true;
        _localMessage = null;
      });

      final imageUrl = await ref
          .read(productsNotifierProvider.notifier)
          .uploadProductImage(pickedImage.path);

      if (!mounted) return;

      if (imageUrl == null) {
        setState(() {
          _localMessage = 'Image upload failed';
        });
        return;
      }

      setState(() {
        _imageUrl = imageUrl;
        _localMessage = 'Image uploaded successfully';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _localMessage = 'Image upload failed';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    final stockText = _stockController.text.trim();
    final description = _descriptionController.text.trim();
    final thresholdText = _thresholdController.text.trim();

    if (name.isEmpty) {
      setState(() => _localMessage = 'Product name is required');
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      setState(() => _localMessage = 'Enter a valid price');
      return;
    }

    final stock = int.tryParse(stockText);
    if (stock == null || stock < 0) {
      setState(() => _localMessage = 'Enter a valid stock count');
      return;
    }

    final threshold = int.tryParse(thresholdText);
    if (threshold == null || threshold < 0) {
      setState(() => _localMessage = 'Enter a valid low stock threshold');
      return;
    }

    setState(() {
      _localMessage = null;
    });

    await ref.read(productsNotifierProvider.notifier).updateProduct(
          productId: widget.product.id,
          name: name,
          description: description.isEmpty ? null : description,
          price: price,
          stockCount: stock,
          lowStockThreshold: threshold,
          imageUrl: _imageUrl,
        );

    final state = ref.read(productsNotifierProvider);

    if (!mounted) return;

    if (state.status == ProductsStatus.loaded &&
        state.successMessage != null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _localMessage = state.errorMessage ?? 'Product update failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsNotifierProvider);
    final isSubmitting = productsState.isSubmitting;

    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050505),
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'Edit Product',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Update Inventory Item',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Modify product details, stock, price, or product image.',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 24),

            _ImageUploadBox(
              imageUrl: _imageUrl,
              isUploading: _isUploadingImage,
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingImage
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00FFCC),
                      side: BorderSide(
                        color: const Color(0xFF00FFCC).withOpacity(0.35),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingImage
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00FFCC),
                      side: BorderSide(
                        color: const Color(0xFF00FFCC).withOpacity(0.35),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            _InputField(
              controller: _nameController,
              label: 'Product Name',
              hint: 'Product name',
            ),

            const SizedBox(height: 14),

            _InputField(
              controller: _priceController,
              label: 'Price',
              hint: 'Price',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),

            const SizedBox(height: 14),

            _InputField(
              controller: _stockController,
              label: 'Stock Count',
              hint: 'Stock count',
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 14),

            _InputField(
              controller: _thresholdController,
              label: 'Low Stock Threshold',
              hint: 'Example: 5',
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 14),

            _InputField(
              controller: _descriptionController,
              label: 'Description',
              hint: 'Optional product details',
              maxLines: 3,
            ),

            if (_localMessage != null) ...[
              const SizedBox(height: 14),
              Text(
                _localMessage!,
                style: GoogleFonts.inter(
                  color: _localMessage!.contains('successfully')
                      ? const Color(0xFF00FFCC)
                      : Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                    isSubmitting || _isUploadingImage ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        'Save Changes',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageUploadBox extends StatelessWidget {
  final String? imageUrl;
  final bool isUploading;

  const _ImageUploadBox({
    required this.imageUrl,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF101010),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orangeAccent.withOpacity(0.30),
        ),
      ),
      child: isUploading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00FFCC),
              ),
            )
          : imageUrl != null && imageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.image_rounded,
                      color: Colors.orangeAccent,
                      size: 38,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No Product Image',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Choose from gallery or camera',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: Colors.white24,
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFF101010),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 15,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.orangeAccent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}