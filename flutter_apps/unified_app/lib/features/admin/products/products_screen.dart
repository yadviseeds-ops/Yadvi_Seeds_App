import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:unified_app/core/config/app_config.dart';
import 'package:unified_app/core/theme/app_theme.dart';
import 'package:unified_app/models/product_model.dart';
import 'package:unified_app/providers/admin_provider.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AdminProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildProductThumbnail(String imageUrl, {double size = 52}) {
    final cleanUrl = imageUrl.trim();
    if (cleanUrl.isEmpty) {
      return _buildImagePlaceholder(size: size);
    }

    String resolvedUrl = cleanUrl;
    if (cleanUrl.startsWith('/')) {
      resolvedUrl = '${AppConfig.apiBaseUrl}$cleanUrl';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: Colors.grey.shade100,
        child: Image.network(
          resolvedUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (ctx, err, stack) => _buildImagePlaceholder(size: size),
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primaryGreen,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder({double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade100),
      ),
      child: const Icon(
        Icons.eco,
        color: AppTheme.primaryGreen,
        size: 26,
      ),
    );
  }

  void _showImageSourcePicker(BuildContext parentContext, Function(ImageSource) onSelected) {
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryGreen),
              title: const Text('Photo Gallery'),
              onTap: () {
                Navigator.pop(sheetCtx);
                onSelected(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryGreen),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(sheetCtx);
                onSelected(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDialog({ProductModel? product}) {
    final isEditing = product != null;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: product?.name ?? '');
    final varietyController = TextEditingController(text: product?.varietyType ?? '');
    final skuController = TextEditingController(text: product?.sku ?? '');
    final categoryController = TextEditingController(text: product?.category ?? 'Hybrid Seeds');
    final stockController = TextEditingController(
      text: isEditing
          ? (product.availableStockKg.truncateToDouble() == product.availableStockKg
              ? product.availableStockKg.toInt().toString()
              : product.availableStockKg.toString())
          : '100',
    );
    final packageSizesController = TextEditingController(text: product?.packageSizes ?? '100g, 500g, 1kg');

    Uint8List? pickedImageBytes;
    String? pickedImageName;
    String currentImageUrl = product?.imageUrl ?? '';
    bool removeCurrentImage = false;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickImage(ImageSource source) async {
            try {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(
                source: source,
                maxWidth: 1024,
                maxHeight: 1024,
                imageQuality: 85,
              );
              if (pickedFile != null) {
                final bytes = await pickedFile.readAsBytes();
                setDialogState(() {
                  pickedImageBytes = bytes;
                  pickedImageName = pickedFile.name;
                  removeCurrentImage = false;
                });
              }
            } catch (e) {
              debugPrint('Error picking image: $e');
            }
          }

          final hasExistingImage = !removeCurrentImage && currentImageUrl.trim().isNotEmpty;
          final hasImage = pickedImageBytes != null || hasExistingImage;

          return AlertDialog(
            title: Text(
              isEditing ? 'Edit Seed Variety' : 'Add Seed Variety',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Product Image Picker Section ---
                    const Text(
                      'Product Image',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textDark),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 74,
                          height: 74,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: pickedImageBytes != null
                                ? Image.memory(pickedImageBytes!, width: 74, height: 74, fit: BoxFit.cover)
                                : (hasExistingImage
                                    ? _buildProductThumbnail(currentImageUrl, size: 74)
                                    : Center(
                                        child: Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 32,
                                          color: Colors.grey.shade400,
                                        ),
                                      )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      side: const BorderSide(color: AppTheme.primaryGreen),
                                    ),
                                    onPressed: isSaving
                                        ? null
                                        : () => _showImageSourcePicker(ctx, (source) => pickImage(source)),
                                    icon: const Icon(Icons.photo_camera, size: 16, color: AppTheme.primaryGreen),
                                    label: Text(
                                      hasImage ? 'Change' : 'Select Image',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primaryGreen,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (hasImage) ...[
                                    const SizedBox(width: 6),
                                    TextButton.icon(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                        foregroundColor: Colors.redAccent,
                                      ),
                                      onPressed: isSaving
                                          ? null
                                          : () {
                                              setDialogState(() {
                                                pickedImageBytes = null;
                                                pickedImageName = null;
                                                removeCurrentImage = true;
                                              });
                                            },
                                      icon: const Icon(Icons.close, size: 14),
                                      label: const Text('Remove', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'JPG, PNG, WebP supported',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // --- Variety Name ---
                    TextFormField(
                      controller: nameController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(labelText: 'Variety Name *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),

                    // --- Crop / Variety Type ---
                    TextFormField(
                      controller: varietyController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(labelText: 'Crop / Variety Type *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 10),

                    // --- SKU Code (Optional) ---
                    TextFormField(
                      controller: skuController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'SKU Code (Optional)',
                        hintText: 'Leave empty to auto-generate',
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Category ---
                    TextFormField(
                      controller: categoryController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 10),

                    // --- Available Stock (kg) ---
                    TextFormField(
                      controller: stockController,
                      enabled: !isSaving,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Available Stock (kg) *',
                        hintText: 'e.g. 100',
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final num = double.tryParse(v.trim());
                        if (num == null || num < 0) return 'Enter a valid positive stock in kg';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),

                    // --- Package Sizes ---
                    TextFormField(
                      controller: packageSizesController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        labelText: 'Package Sizes (e.g. 100g, 500g, 1kg)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => isSaving = true);

                        final adminProvider = Provider.of<AdminProvider>(context, listen: false);

                        String finalImageUrl = product?.imageUrl ?? '';
                        if (removeCurrentImage) {
                          finalImageUrl = '';
                        }

                        // Upload new image if chosen
                        if (pickedImageBytes != null) {
                          final uploadedUrl = await adminProvider.uploadProductImage(
                            pickedImageBytes!,
                            pickedImageName ?? 'product_${DateTime.now().millisecondsSinceEpoch}.jpg',
                          );
                          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
                            finalImageUrl = uploadedUrl;
                          } else {
                            setDialogState(() => isSaving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to upload image. Please check format/size.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                            return;
                          }
                        }

                        final stockKg = double.tryParse(stockController.text.trim()) ?? 0.0;
                        final payload = {
                          'name': nameController.text.trim(),
                          'variety_type': varietyController.text.trim(),
                          'sku': skuController.text.trim().isEmpty ? null : skuController.text.trim(),
                          'category': categoryController.text.trim().isEmpty ? 'Hybrid Seeds' : categoryController.text.trim(),
                          'image_url': finalImageUrl,
                          'available_stock_kg': stockKg,
                          'germination_rate': '85% Min',
                          'purity': '98% Min',
                          'availability': stockKg > 0 ? 'In Stock' : 'Out of Stock',
                          'package_sizes': packageSizesController.text.trim().isEmpty ? '100g, 500g, 1kg' : packageSizesController.text.trim(),
                        };

                        String? errorMsg;
                        if (isEditing) {
                          errorMsg = await adminProvider.updateProductWithResult(product.id, payload);
                        } else {
                          errorMsg = await adminProvider.createProductWithResult(payload);
                        }

                        setDialogState(() => isSaving = false);

                        if (errorMsg == null) {
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEditing ? 'Product updated successfully' : 'Product added successfully'),
                                backgroundColor: AppTheme.primaryGreen,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                backgroundColor: Colors.redAccent,
                                duration: const Duration(seconds: 4),
                              ),
                            );
                          }
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isEditing ? 'Save Changes' : 'Add Product'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(ProductModel prod) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Product'),
        content: Text('Are you sure you want to remove "${prod.name}" (${prod.sku})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final adminProvider = Provider.of<AdminProvider>(context, listen: false);
              final success = await adminProvider.deleteProduct(prod.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Product removed' : 'Failed to remove product'),
                    backgroundColor: success ? AppTheme.primaryLight : Colors.redAccent,
                  ),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminProvider = Provider.of<AdminProvider>(context);

    final filteredProducts = adminProvider.products.where((p) {
      return _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.varietyType.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          p.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Variety', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _showProductDialog(),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search products by name, variety or SKU...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => adminProvider.fetchProducts(),
              color: AppTheme.primaryGreen,
              child: adminProvider.isLoadingProducts && adminProvider.products.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                  : filteredProducts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              const Text('No products found', style: TextStyle(color: AppTheme.textMuted)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 80),
                          itemCount: filteredProducts.length,
                          itemBuilder: (ctx, i) {
                            final prod = filteredProducts[i];
                            final stockDisplay = prod.availableStockKg.truncateToDouble() == prod.availableStockKg
                                ? '${prod.availableStockKg.toInt()} kg'
                                : '${prod.availableStockKg.toStringAsFixed(2)} kg';

                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildProductThumbnail(prod.imageUrl),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  prod.name,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: AppTheme.textDark,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.green.shade300),
                                                ),
                                                child: Text(
                                                  stockDisplay,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${prod.varietyType} • SKU: ${prod.sku}',
                                            style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Packs: ${prod.packageSizes} | Germ: ${prod.germinationRate}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primaryGreen),
                                          tooltip: 'Edit',
                                          onPressed: () => _showProductDialog(product: prod),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                          tooltip: 'Remove',
                                          onPressed: () => _confirmDelete(prod),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
