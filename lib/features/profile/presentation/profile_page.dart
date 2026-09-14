import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_scope.dart';
import '../../../core/app_theme.dart';
import '../../../core/network/api_config.dart';
import '../../../main.dart' show shopMode, themeMode;
import '../../../shared/widgets/app_widgets.dart';
import '../../auth/domain/user.dart';
import 'alerts_page.dart';
import 'my_motos_page.dart';

/// Mi cuenta: datos, contraseña, tema, sugerencias y cierre de sesión.
/// La misma pantalla sirve a comprador, proveedor y admin.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  static const route = '/profile';

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _busy = false;

  Future<void> _editProfile(User user) async {
    final scope = AppScope.of(context);
    final name = TextEditingController(text: user.name);
    final phone = TextEditingController(text: user.phone);
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Editar mis datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 8),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                helperText: 'Déjala vacía para no cambiarla',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await scope.auth.updateProfile(
        name: name.text.trim().isEmpty ? null : name.text.trim(),
        phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
        password: password.text.length >= 6 ? password.text : null,
      );
      scope.session.updateUser(updated);
      if (mounted) showInfo(context, 'Datos guardados');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Foto de perfil -> uploads/avatars/ -> PATCH /auth/me.
  Future<void> _changeAvatar() async {
    final scope = AppScope.of(context);
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final path = await scope.api.uploadImage(picked, folder: 'avatars');
      scope.session.updateUser(await scope.auth.updateProfile(avatarUrl: path));
      if (mounted) showInfo(context, 'Foto actualizada');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _feedback() async {
    final auth = AppScope.of(context).auth;
    final subject = TextEditingController();
    final message = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Enviar sugerencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: subject, decoration: const InputDecoration(labelText: 'Asunto')),
            const SizedBox(height: 8),
            TextField(
              controller: message,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '¿Qué mejorarías de la app?'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await auth.sendFeedback(subject: subject.text.trim(), message: message.text.trim());
      if (mounted) showInfo(context, '¡Gracias! Leemos todas las sugerencias.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.sessionOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final user = session.user;
          if (user == null) return const SizedBox.shrink();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: _busy ? null : _changeAvatar,
                    customBorder: const CircleBorder(),
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: kBrandAmber,
                          backgroundImage: user.avatarUrl != null
                              ? NetworkImage(ApiConfig.imageUrl(user.avatarUrl)!)
                              : null,
                          child: user.avatarUrl == null
                              ? Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 26, color: Colors.black87))
                              : null,
                        ),
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: CircleAvatar(
                            radius: 11,
                            child: Icon(Icons.photo_camera, size: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                        Text(user.email),
                        Chip(label: Text(user.role.label), visualDensity: VisualDensity.compact),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar datos y contraseña'),
                subtitle: Text(user.phone ?? 'Sin teléfono'),
                onTap: _busy ? null : () => _editProfile(user),
              ),
              if (!user.isAdmin) ...[
                ListenableBuilder(
                  listenable: session,
                  builder: (context, _) => ListTile(
                    leading: const Icon(Icons.two_wheeler),
                    title: const Text('Mis motos'),
                    subtitle: Text(session.motos.isEmpty
                        ? 'Guarda tu moto para buscar solo lo compatible'
                        : session.motos.map((m) => m.label).join(', ')),
                    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const MyMotosPage())),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none),
                  title: const Text('Mis alertas'),
                  subtitle: const Text('Avisos de stock y precio'),
                  onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AlertsPage())),
                ),
                if (user.buyerRatingCount > 0)
                  ListTile(
                    leading: const Icon(Icons.star_outline),
                    title: const Text('Mi reputación como comprador'),
                    subtitle: Text(user.buyerRatingLabel),
                  ),
              ],
              if (user.isSupplier)
                ValueListenableBuilder<bool>(
                  valueListenable: shopMode,
                  builder: (context, buying, _) => SwitchListTile(
                    secondary: const Icon(Icons.swap_horiz),
                    title: const Text('Modo comprador'),
                    subtitle: const Text('Compra repuestos a otras tiendas con esta cuenta'),
                    value: buying,
                    onChanged: (v) {
                      shopMode.value = v;
                      Navigator.pop(context);
                    },
                  ),
                ),
              SwitchListTile(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: const Text('Tema oscuro'),
                value: dark,
                onChanged: (v) => themeMode.value = v ? ThemeMode.dark : ThemeMode.light,
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: const Text('Enviar sugerencia'),
                subtitle: const Text('Cuéntanos qué mejorarías'),
                onTap: _feedback,
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                title: const Text('Cerrar sesión'),
                onTap: () {
                  Navigator.pop(context);
                  session.signOut();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
