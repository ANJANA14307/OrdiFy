import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'shared_catalog_api.dart';

class SuggestCatalogProductScreen extends StatefulWidget {
  const SuggestCatalogProductScreen({super.key});

  @override
  State<SuggestCatalogProductScreen> createState() =>
      _SuggestCatalogProductScreenState();
}

class _SuggestCatalogProductScreenState
    extends State<SuggestCatalogProductScreen> {
  final _nameController = TextEditingController();
  final _brandController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _images = [];
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _addImage() async {
    if (_images.length >= 8) {
      _message('You can add up to eight images');
      return;
    }
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
      );
      if (image == null || !mounted) return;
      setState(() {
        _uploading = true;
        _error = null;
      });
      final url = await sharedCatalogApi.uploadImage(image);
      if (!mounted) return;
      setState(() {
        _images.add(url);
        _uploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = sharedCatalogError(error);
        _uploading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty ||
        _categoryController.text.trim().isEmpty) {
      _message('Name and category are required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await sharedCatalogApi.suggest({
        'name': _nameController.text.trim(),
        'brand': _brandController.text.trim().isEmpty
            ? null
            : _brandController.text.trim(),
        'category': _categoryController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'images': _images,
      });
      if (!mounted) return;
      setState(() => _saving = false);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Submitted for review'),
          content: const Text(
            'This catalog product will be available to businesses after backend review.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = sharedCatalogError(error);
        _saving = false;
      });
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050807),
    appBar: AppBar(
      title: const Text('Suggest a catalog product'),
      backgroundColor: const Color(0xFF07120C),
      foregroundColor: Colors.white,
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        if (_error != null)
          Card(
            color: Colors.red.withValues(alpha: .18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!),
            ),
          ),
        TextField(
          controller: _nameController,
          maxLength: 160,
          decoration: const InputDecoration(labelText: 'Product name *'),
        ),
        TextField(
          controller: _brandController,
          maxLength: 120,
          decoration: const InputDecoration(labelText: 'Brand'),
        ),
        TextField(
          controller: _categoryController,
          maxLength: 100,
          decoration: const InputDecoration(labelText: 'Category *'),
        ),
        TextField(
          controller: _descriptionController,
          maxLength: 2000,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        const SizedBox(height: 12),
        const Text('Product images'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._images.map(
              (url) => InputChip(
                label: Text('Image ${_images.indexOf(url) + 1}'),
                onDeleted: () => setState(() => _images.remove(url)),
              ),
            ),
            ActionChip(
              avatar: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_a_photo_outlined),
              label: const Text('Add image'),
              onPressed: _uploading ? null : _addImage,
            ),
          ],
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _saving || _uploading ? null : _submit,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_saving ? 'Submitting…' : 'Submit for review'),
        ),
      ],
    ),
  );
}
