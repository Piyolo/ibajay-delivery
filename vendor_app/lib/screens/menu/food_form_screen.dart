import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/food_item.dart';
import '../../models/vendor.dart';
import '../../providers/menu_provider.dart';
import '../../theme/app_theme.dart';

class FoodFormScreen extends StatefulWidget {
  final FoodItem? existingItem;
  const FoodFormScreen({super.key, this.existingItem});

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _description;
  late TextEditingController _price;
  late String _category;
  late bool _isAvailable;
  late bool _isFeatured;
  late List<FoodAddon> _addons;

  // Preserved on edit so saving never wipes the item's photo/flag.
  String _imageUrl = '';
  bool _saving = false;
  bool _uploading = false;

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _name = TextEditingController(text: item?.name ?? '');
    _description = TextEditingController(text: item?.description ?? '');
    _price = TextEditingController(text: item != null ? item.price.toStringAsFixed(0) : '');
    _category = (item?.category.isNotEmpty ?? false) ? item!.category : kStoreCategoryOptions.first;
    _isAvailable = item?.isAvailable ?? true;
    _isFeatured = item?.isFeatured ?? false;
    _imageUrl = item?.imageUrl ?? '';
    _addons = item != null ? List.from(item.addons.map((a) => FoodAddon(name: a.name, price: a.price))) : [];
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final XFile? file;
    try {
      file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    } catch (_) {
      return;
    }
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await context.read<MenuProvider>().uploadImage(file.path);
      if (!mounted) return;
      setState(() => _imageUrl = url);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not upload the photo — try again')));
    }
    if (mounted) setState(() => _uploading = false);
  }

  void _addAddonDialog() {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Extra / Add-on'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'e.g. Extra Cheese')),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Price (e.g. 20)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceCtrl.text) ?? 0;
              if (nameCtrl.text.trim().isEmpty) return;
              setState(() => _addons.add(FoodAddon(name: nameCtrl.text.trim(), price: price)));
              Navigator.pop(dialogContext);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ).then((_) {
      nameCtrl.dispose();
      priceCtrl.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final menu = context.read<MenuProvider>();
    final price = double.tryParse(_price.text) ?? 0;
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _saving = true);
    if (_isEditing) {
      final updated = FoodItem(
        id: widget.existingItem!.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        price: price,
        category: _category,
        imageUrl: _imageUrl,
        isAvailable: _isAvailable,
        isFeatured: _isFeatured,
        addons: _addons,
      );
      await menu.updateItem(updated);
    } else {
      // The server assigns the real id; addItem swaps it in on success.
      final newItem = FoodItem(
        id: 'temp_${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        description: _description.text.trim(),
        price: price,
        category: _category,
        imageUrl: _imageUrl,
        isAvailable: _isAvailable,
        isFeatured: _isFeatured,
        addons: _addons,
      );
      await menu.addItem(newItem);
    }
    if (!mounted) return;
    setState(() => _saving = false);

    // Only close on success; a failed save stays open with the reason.
    if (menu.lastError != null) {
      messenger.showSnackBar(SnackBar(content: Text('Not saved — ${menu.lastError}')));
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text('"${widget.existingItem!.name}" will be removed from your menu. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Keep Item')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final menu = context.read<MenuProvider>();
    await menu.deleteItem(widget.existingItem!.id);
    if (!mounted) return;
    if (menu.lastError != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Not deleted — ${menu.lastError}')));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Food Item' : 'Add Food Item'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.danger), onPressed: _delete),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _uploading ? null : _pickPhoto,
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: _uploading
                        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                        : _imageUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: Image.network(_imageUrl, fit: BoxFit.cover, width: double.infinity,
                                    errorBuilder: (_, __, ___) => _uploadHint()),
                              )
                            : _uploadHint(),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('Name', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(hintText: 'e.g. Chicken Adobo Rice Bowl'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                const Text('Description', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Describe the dish'),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Price (₱)', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _price,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: '0'),
                            validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter a valid price' : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            decoration: const InputDecoration(),
                            items: kStoreCategoryOptions
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (v) => setState(() => _category = v ?? _category),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Available', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Turn off to hide this item from customers', style: TextStyle(fontSize: 12)),
                  value: _isAvailable,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _isAvailable = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Show this item in customers\' Featured Foods carousel',
                      style: TextStyle(fontSize: 12)),
                  value: _isFeatured,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _isFeatured = v),
                ),
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Extras / Add-ons', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextButton.icon(
                      onPressed: _addAddonDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                ..._addons.map((a) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(a.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('+₱${a.price.toStringAsFixed(0)}'),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => setState(() => _addons.remove(a)),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEditing ? 'Save Changes' : 'Add Item'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _uploadHint() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondary),
          SizedBox(height: 4),
          Text('Upload photo', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
