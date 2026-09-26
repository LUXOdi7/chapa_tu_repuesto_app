import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_config.dart';

/// Isotipo + titulo para las barras superiores.
class BrandTitle extends StatelessWidget {
  const BrandTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Image.asset('assets/ctr_mark.png', height: 26, width: 26),
      ),
      const SizedBox(width: 10),
      Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
    ],
  );
}

/// Logo completo (login, splash): version con fondo blanco dentro de una
/// tarjeta redondeada, asi se ve igual de limpio en tema claro y oscuro.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) => Center(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          'assets/ctr_logo_white.png',
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    ),
  );
}

/// Foto del repuesto con degradacion a icono: el backend devuelve rutas
/// relativas (o null), y en el taller la conexion se cae. La grilla tiene que
/// seguir siendo legible en los dos casos.
class PartImage extends StatelessWidget {
  const PartImage({super.key, required this.path, this.height});

  /// Ruta relativa tal como llega del backend (`/uploads/products/ab12.jpg`).
  final String? path;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.imageUrl(path);
    final fallback = Container(
      height: height,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.settings_suggest_outlined,
        size: (height ?? 96) * 0.4,
        color: Theme.of(context).colorScheme.outline,
      ),
    );

    if (url == null) return fallback;

    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : fallback,
    );
  }
}

/// Semaforo de disponibilidad: verde con stock, gris agotado, ambar si queda
/// poco (el mecanico necesita saber si alcanza para hoy).
class StockChip extends StatelessWidget {
  const StockChip({super.key, required this.stock, this.dense = false});

  final int stock;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (stock) {
      <= 0 => (Colors.grey, 'Sin stock'),
      < 5 => (Colors.orange, 'Ultimas $stock'),
      _ => (Colors.green, 'En stock'),
    };

    // Fondo opaco, no translucido: el chip va encima de la foto del repuesto y
    // con alpha adoptaba el color de la imagen hasta volverse ilegible.
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: Color.lerp(color, Colors.black, 0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: dense ? 10 : 11,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Carga / vacio / error
// ---------------------------------------------------------------------------

/// Los tres estados de cualquier pantalla que habla con el backend, en un solo
/// widget: cargando, error con reintentar, vacio con mensaje propio.
///
/// Para recargar a mano, cambia [refreshKey] (un contador en el State de la
/// pantalla): eso vuelve a llamar a [load].
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.isEmpty,
    this.emptyMessage = 'No hay nada por aqui todavia.',
    this.emptyIcon = Icons.inbox_outlined,
    this.refreshKey,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;
  final IconData emptyIcon;
  final Object? refreshKey;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  @override
  void didUpdateWidget(AsyncView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _future = widget.load();
    }
  }

  void _retry() {
    final future = widget
        .load(); // fuera del setState: la arrow devolvia la Future
    setState(() => _future = future);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const BrandLoader();
      }
      if (snapshot.hasError) {
        return ErrorRetry(error: snapshot.error!, onRetry: _retry);
      }
      final data = snapshot.data as T;
      if (widget.isEmpty?.call(data) ?? false) {
        return EmptyState(message: widget.emptyMessage, icon: widget.emptyIcon);
      }
      return widget.builder(context, data);
    },
  );
}

class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off,
            size: 52,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage(error),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EmptyArt(icon: icon),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

/// El backend ya manda el mensaje redactado en español dentro de `detail`; solo
/// hay que sacarlo del error.
String errorMessage(Object error) =>
    error is ApiException ? error.message : 'Ocurrio un error inesperado.';

/// SnackBar de error estandar.
void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(errorMessage(error)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Ilustracion de estado vacio: todo en gris menos un engranaje naranja, para
/// que la pantalla no parezca un error. design.md 5.
class _EmptyArt extends StatelessWidget {
  const _EmptyArt({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 84,
    height: 76,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          icon,
          size: 60,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: kBrandOrange,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings, size: 15, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

/// Spinner de marca: el isotipo CTR girando sobre un aro naranja. design.md 5
/// pide dejar el `CircularProgressIndicator` generico.
class BrandLoader extends StatefulWidget {
  const BrandLoader({super.key, this.size = 46});

  final double size;

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RotationTransition(
            turns: _spin,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation(kBrandOrange),
              backgroundColor: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/ctr_mark.png',
              width: widget.size * 0.46,
              height: widget.size * 0.46,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Navegacion adaptable de design.md 4: barra inferior en movil (< 600 px) y
/// riel lateral azul desde tablet, extendido en escritorio (>= 900 px). Un solo
/// juego de destinos para las tres pantallas raiz (comprador, tienda, admin).
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.destinations,
    required this.body,
    this.appBar,
    this.floatingActionButton,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    if (!isWide(context)) {
      return Scaffold(
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected,
          destinations: destinations,
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Row(
        children: [
          NavigationRail(
            extended: isDesktop(context),
            minExtendedWidth: 190,
            selectedIndex: selectedIndex,
            onDestinationSelected: onSelected,
            labelType: isDesktop(context)
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: d.icon,
                  selectedIcon: d.selectedIcon ?? d.icon,
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// Formulario centrado y con ancho maximo. En un monitor de taller un input de
/// 1400 px no se lee; design.md 4 lo limita a 600. En movil no cambia nada.
class FormBox extends StatelessWidget {
  const FormBox({super.key, required this.child, this.maxWidth = kFormWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
