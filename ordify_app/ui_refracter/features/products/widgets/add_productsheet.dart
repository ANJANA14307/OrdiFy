import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/products_notifier.dart';

class AddProductSheet extends ConsumerStatefulWidget {
  const AddProductSheet({super.key});

  @override
  ConsumerState<AddProductSheet> createState() => _AddProductSheetState();
}

class _AddProductSheetState extends ConsumerState<AddProductSheet> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _thresholdController = TextEditingController(text: '5');

  final ImagePicker _picker = ImagePicker();

  bool _isUploadingImage = false;
  String? _imageUrl;
  String? _localMessage;

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

  Future<void> _submitProduct() async {
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

    await ref.read(productsNotifierProvider.notifier).createProduct(
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
      Navigator.pop(context);
    } else {
      setState(() {
        _localMessage = state.errorMessage ?? 'Product creation failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsState = ref.watch(productsNotifierProvider);
    final isSubmitting = productsState.isSubmitting;

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),

            const SizedBox(height: 22),

            Text(
              'Add Product',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Create a product for your OrdiFy inventory.',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 22),

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

            const SizedBox(height: 18),

            _InputField(
              controller: _nameController,
              label: 'Product Name',
              hint: 'Example: Handmade Bracelet',
            ),

            const SizedBox(height: 14),

            _InputField(
              controller: _priceController,
              label: 'Price',
              hint: 'Example: 299',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),

            const SizedBox(height: 14),

            _InputField(
              controller: _stockController,
              label: 'Stock Count',
              hint: 'Example: 10',
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

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed:
                    isSubmitting || _isUploadingImage ? null : _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FFCC),
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
                        'Create Product',
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
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00FFCC).withOpacity(0.22),
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
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_upload_rounded,
                      color: Color(0xFF00FFCC),
                      size: 38,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Upload Product Image',
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
            fillColor: const Color(0xFF050505),
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
                color: Color(0xFF00FFCC),
              ),
            ),
          ),
        ),
      ],
    );
  }
}