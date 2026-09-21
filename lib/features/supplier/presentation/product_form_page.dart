import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_scope.dart';
import '../../../core/format.dart';
import '../../../shared/widgets/app_widgets.dart';
import '../../catalog/domain/compatibility.dart';
import '../../catalog/domain/product.dart';
import '../data/supplier_repository.dart';

/// Publicar o editar un repuesto.
///
/// La foto se sube antes de guardar (`POST /uploads/image`) y en el producto se
/// guarda la RUTA que devuelve, no la URL completa.
class ProductFormPage extends StatefulWidget {
  const ProductFormPage({super.key, this.product});

  static const route = '/supplier/product';

  final Product? product;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _partCode = TextEditingController(text: widget.product?.partCode);
  late final _brand = TextEditingController(text: widget.product?.brand);
  late final _description =
      TextEditingController(text: widget.product?.description);
  late final _price =
      TextEditingController(text: widget.product?.price.toStringAsFixed(2));
  late final _stock =
      TextEditingController(text: widget.product?.stock.toString());
  late final _warranty = TextEditingController(
      text: widget.product?.warrantyMonths?.toString() ?? '6');

  late String _category = widget.product?.category ?? knownCategories.first;
  late bool _active = widget.product?.isActive ?? true;
  /// Galeria: hasta 5 rutas; la primera es la portada.
  late final List<String> _images = [...?widget.product?.imageUrls];
  static const _maxImages = 5;
  late final List<Compatibility> _compatibilities =
      [...?widget.product?.compatibilities];

  bool _busy = false;
  String? _uploadingLabel;

  @override
  void dispose() {
    _name.dispose();
    _partCode.dispose();
    _brand.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    _warranty.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final room = _maxImages - _images.length;
    if (room <= 0) return;
    final picked = await ImagePicker().pickMultiImage(maxWidth: 1280, imageQuality: 85, limit: room);
    if (picked.isEmpty || !mounted) return;
    setState(() => _uploadingLabel = 'Subiendo ${picked.length} foto(s)...');
    try {
      final repo = AppScope.suppliersOf(context);
      for (final file in picked.take(room)) {
        final path = await repo.uploadImage(file);
        if (mounted) setState(() => _images.add(path));
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _uploadingLabel = null);
    }
  }

  /// Nueva categoria desde el formulario (tiendas y admin).
  Future<void> _newCategory() async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Accesorios, Cascos...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, ctrl.text.trim()), child: const Text('Crear')),
        ],
      ),
    );
    if (label == null || label.length < 2 || !mounted) return;
    try {
      final key = await AppScope.catalogOf(context).createCategory(label);
      if (mounted) setState(() => _category = key);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _addCompatibility() async {
    final result = await showDialog<Compatibility>(
      context: context,
      builder: (_) => const _CompatibilityDialog(),
    );
    if (result != null) setState(() => _compatibilities.add(result));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = AppScope.suppliersOf(context);
      final body = SupplierRepository.productBody(
        name: _name.text.trim(),
        category: _category,
        partCode: _partCode.text.trim(),
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        description:
            _description.text.trim().isEmpty ? null : _description.text.trim(),
        imageUrl: _images.isEmpty ? null : _images.first,
        imageUrls: _images,
        price: double.parse(_price.text.replaceAll(',', '.')),
        stock: int.parse(_stock.text),
        warrantyMonths: int.tryParse(_warranty.text),
        isActive: _active,
        compatibilities: _compatibilities,
      );
      if (widget.product == null) {
        await repo.createProduct(body);
      } else {
        await repo.updateProduct(widget.product!.id, body);
      }
      if (!mounted) return;
      showInfo(context, 'Repuesto guardado');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Nuevo repuesto' : 'Editar repuesto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Galeria: portada grande + miniaturas; mantener pulsado una
            // miniatura la convierte en portada; la X la quita.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PartImage(path: _images.isEmpty ? null : _images.first),
                    if (_uploadingLabel != null)
                      Container(
                        color: Colors.black54,
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (var i = 0; i < _images.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _images.insert(0, _images.removeAt(i))),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(width: 64, height: 64, child: PartImage(path: _images[i], height: 64)),
                            ),
                            if (i == 0)
                              const Positioned(
                                left: 4,
                                bottom: 4,
                                child: Icon(Icons.star, size: 16, color: Colors.amber),
                              ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: InkWell(
                                onTap: () => setState(() => _images.removeAt(i)),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_images.length < _maxImages)
                    InkWell(
                      onTap: _uploadingLabel == null ? _pickImages : null,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add_a_photo_outlined),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                'Hasta $_maxImages fotos (opcional). Toca una miniatura para hacerla portada.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('cat|$_category|${categoryLabels.length}'),
                    initialValue: categoryLabels.containsKey(_category) ? _category : null,
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    items: [
                      for (final key in knownCategories)
                        DropdownMenuItem(value: key, child: Text(categoryLabel(key))),
                    ],
                    onChanged: (v) => setState(() => _category = v ?? _category),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  tooltip: 'Nueva categoría',
                  icon: const Icon(Icons.add),
                  onPressed: _newCategory,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _partCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código de parte',
                helperText: 'Es lo que agrupa tu oferta con la de otras tiendas',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(
                labelText: 'Marca del repuesto (opcional)',
                hintText: 'NGK, Brembo, DID...',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Precio', prefixText: 'S/ '),
                    validator: (v) {
                      final value =
                          double.tryParse((v ?? '').replaceAll(',', '.'));
                      return (value == null || value <= 0)
                          ? 'Precio inválido'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stock,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock'),
                    validator: (v) {
                      final value = int.tryParse(v ?? '');
                      return (value == null || value < 0)
                          ? 'Stock inválido'
                          : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _warranty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Garantía (m)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Visible en el catálogo'),
              contentPadding: EdgeInsets.zero,
            ),

            SectionTitle(
              'Compatibilidad (${_compatibilities.length})',
              trailing: TextButton.icon(
                onPressed: _addCompatibility,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
              ),
            ),
            if (_compatibilities.isEmpty)
              const Text(
                'Sin compatibilidades el repuesto no aparece en las búsquedas '
                'por marca / modelo / año.',
              ),
            for (var i = 0; i < _compatibilities.length; i++)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.two_wheeler),
                title: Text(_compatibilities[i].label),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      setState(() => _compatibilities.removeAt(i)),
                ),
              ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompatibilityDialog extends StatefulWidget {
  const _CompatibilityDialog();

  @override
  State<_CompatibilityDialog> createState() => _CompatibilityDialogState();
}

class _CompatibilityDialogState extends State<_CompatibilityDialog> {
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _from = TextEditingController(text: '2015');
  final _to = TextEditingController(text: '${DateTime.now().year}');

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  void _submit() {
    final from = int.tryParse(_from.text);
    final to = int.tryParse(_to.text);
    if (_brand.text.trim().isEmpty ||
        _model.text.trim().isEmpty ||
        from == null ||
        to == null ||
        to < from) {
      showInfo(context, 'Revisa marca, modelo y el rango de años');
      return;
    }
    Navigator.pop(
      context,
      Compatibility(
        motoBrand: _brand.text.trim(),
        motoModel: _model.text.trim(),
        yearFrom: from,
        yearTo: to,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Moto compatible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _brand,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Marca', hintText: 'Honda, Bajaj...'),
            ),
            TextField(
              controller: _model,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                  labelText: 'Modelo', hintText: 'XR 150L'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _from,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Desde'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _to,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hasta'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Agregar')),
        ],
      );
}
