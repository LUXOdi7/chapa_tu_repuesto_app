// Prueba contra el backend REAL (no corre en CI):
//   flutter test test/live_admin_test.dart --dart-define=API_BASE_URL=http://localhost:9001 --dart-define=LIVE=true
import 'dart:io';

import 'package:chapa_tu_repuesto_app/features/admin/presentation/admin_shell.dart';
import 'package:chapa_tu_repuesto_app/features/orders/presentation/order_tracking_page.dart';
import 'package:chapa_tu_repuesto_app/features/profile/presentation/profile_page.dart';
import 'package:chapa_tu_repuesto_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login admin contra backend real', (tester) async {
    if (!const bool.fromEnvironment('LIVE')) return;
    HttpOverrides.global = null; // flutter_test bloquea la red por defecto
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(const ChapaTuRepuestoApp());
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(0), 'admin@demo.pe');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await tester.pump();
        final err = tester.takeException();
        if (err != null) fail('EXCEPCION: $err');
        if (find.byType(AdminShell).evaluate().isNotEmpty) break;
      }
      expect(find.byType(AdminShell), findsOneWidget);
      for (var i = 1; i < 5; i++) {
        await tester.tap(find.byType(NavigationDestination).at(i));
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump();
        final err = tester.takeException();
        if (err != null) fail('EXCEPCION pestaña $i: $err');
      }
    });
  });

  testWidgets('comprador con motos: buscador, ficha, perfil y seguimiento con chat', (tester) async {
    if (!const bool.fromEnvironment('LIVE')) return;
    HttpOverrides.global = null;
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await tester.runAsync(() async {
      Future<void> settle([int ms = 1500]) async {
        await Future<void>.delayed(Duration(milliseconds: ms));
        // Varios frames con tiempo: las transiciones de ruta (300 ms) se
        // completan; con un solo pump() quedaban a medio camino y los botones
        // fuera de la pantalla.
        for (var f = 0; f < 5; f++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final err = tester.takeException();
        if (err != null) fail('EXCEPCION: $err');
      }

      Future<void> back() async {
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await settle(600);
      }

      // Bombea hasta que aparezca (las respuestas llegan por red real). Si la
      // pantalla es una lista, la va bajando por si el widget quedo abajo.
      Future<void> waitFor(Finder f, [int seconds = 15]) async {
        for (var i = 0; i < seconds * 4; i++) {
          await settle(250);
          if (f.evaluate().isNotEmpty) return;
          // Baja la lista/grilla visible mas profunda (la ultima en el arbol).
          final lists = find
              .byWidgetPredicate((w) =>
                  w is Scrollable &&
                  w.axisDirection == AxisDirection.down &&
                  w.physics is! NeverScrollableScrollPhysics)
              .hitTestable();
          if (i % 4 == 3 && lists.evaluate().isNotEmpty) {
            await tester.drag(lists.last, const Offset(0, -400), warnIfMissed: false);
          }
        }
        fail('No aparecio: $f');
      }

      await tester.pumpWidget(const ChapaTuRepuestoApp());
      await settle();
      await tester.enterText(find.byType(TextFormField).at(0), 'taller.julio@demo.pe');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      // "Ver mas" agrega la siguiente pagina sin reiniciar la grilla
      await waitFor(find.textContaining('restantes)'));
      final antes = (tester.widget(find.textContaining('restantes)')) as Text).data!;
      await tester.ensureVisible(find.textContaining('restantes)'));
      await settle(300);
      await tester.tap(find.textContaining('restantes)'));
      // Tras cargar, el boton queda al final de la grilla (mas abajo): se baja
      // hasta verlo otra vez y el contador debe haber cambiado.
      await settle(1500);
      await waitFor(find.textContaining('restantes)'), 10);
      final despues = (tester.widget(find.textContaining('restantes)')) as Text).data!;
      expect(despues, isNot(antes)); // (65 restantes) -> (45 restantes)
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Chips "Mis motos" en el buscador y filtro al tocar
      await waitFor(find.textContaining('Bajaj Pulsar NS 200'));
      await tester.tap(find.textContaining('Bajaj Pulsar NS 200').first);
      await waitFor(find.textContaining('compatibles con tu'));
      // Ficha: compatible con tu moto + campana de alerta
      await tester.tap(find.byType(Card).first);
      await waitFor(find.textContaining('Compatible con tu'));
      await tester.tap(find.byIcon(Icons.notifications_none));
      await settle();
      expect(find.text('Crear alerta'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await settle();
      await back();
      await settle();
      // Perfil: mis motos y alertas
      await waitFor(find.byIcon(Icons.account_circle_outlined));
      await tester.tap(find.byIcon(Icons.account_circle_outlined));
      await waitFor(find.byType(ProfilePage));
      await tester.tap(find.text('Mis alertas'));
      await waitFor(find.text('Mis alertas'));
      await settle(1500);
      await back();
      await waitFor(find.byType(ProfilePage));
      await back();
      await waitFor(find.text('Pedidos'));
      // Pedidos -> seguimiento -> chat
      await tester.tap(find.text('Pedidos'));
      await waitFor(find.textContaining('CTR-'));
      await tester.tap(find.widgetWithText(ListTile, 'CTR-000004'));
      await settle(600);
      await waitFor(find.text('Ver tienda').hitTestable(), 15);
      expect(find.byType(OrderTrackingPage), findsOneWidget);
      // "Consultar" la primera vez; "Mensajes (N)" si ya hubo chat en esa orden
      final chatBtn = find.textContaining(RegExp('Consultar|Mensajes'));
      await waitFor(chatBtn.hitTestable());
      await tester.tap(chatBtn.hitTestable().first);
      await waitFor(find.byType(TextField));
      await tester.enterText(find.byType(TextField).last, 'Hola, tienen stock?');
      await tester.tap(find.byIcon(Icons.send));
      await waitFor(find.text('Hoy')); // chip de fecha = el mensaje ya esta en la lista
      // Chip de fecha "Hoy" una sola vez, hora en la burbuja
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Hola, tienen stock?'), findsWidgets); // en burbuja (el campo ya se vacio); puede haber de corridas previas
      await back();
      await back();
      // Campana -> bandeja de notificaciones con recargar
      await waitFor(find.byIcon(Icons.notifications_outlined));
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await waitFor(find.text('Notificaciones'));
      await waitFor(find.byIcon(Icons.refresh));
      await tester.tap(find.byIcon(Icons.refresh));
      await settle(1500);
    });
  });

  testWidgets('proveedor: editar tienda guarda (antes daba 422 por nulls)', (tester) async {
    if (!const bool.fromEnvironment('LIVE')) return;
    HttpOverrides.global = null;
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await tester.runAsync(() async {
      Future<void> settle([int ms = 1500]) async {
        await Future<void>.delayed(Duration(milliseconds: ms));
        // Varios frames con tiempo: las transiciones de ruta (300 ms) se
        // completan; con un solo pump() quedaban a medio camino y los botones
        // fuera de la pantalla.
        for (var f = 0; f < 5; f++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final err = tester.takeException();
        if (err != null) fail('EXCEPCION: $err');
      }

      Future<void> waitFor(Finder f, [int seconds = 15]) async {
        for (var i = 0; i < seconds * 4; i++) {
          await settle(250);
          if (f.evaluate().isNotEmpty) return;
          // Baja la lista/grilla visible mas profunda (la ultima en el arbol).
          final lists = find
              .byWidgetPredicate((w) =>
                  w is Scrollable &&
                  w.axisDirection == AxisDirection.down &&
                  w.physics is! NeverScrollableScrollPhysics)
              .hitTestable();
          if (i % 4 == 3 && lists.evaluate().isNotEmpty) {
            await tester.drag(lists.last, const Offset(0, -400), warnIfMissed: false);
          }
        }
        fail('No aparecio: $f');
      }

      await tester.pumpWidget(const ChapaTuRepuestoApp());
      await settle();
      await tester.enterText(find.byType(TextFormField).at(0), 'proveedor1@demo.pe');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await waitFor(find.text('Editar datos de la tienda'));
      await tester.tap(find.text('Editar datos de la tienda'));
      await waitFor(find.text('Guardar cambios'));
      expect(find.text('Marcar mi tienda en el mapa').evaluate().isEmpty, isTrue); // ya tiene ubicacion
      await tester.tap(find.text('Guardar cambios'));
      await waitFor(find.text('Tienda guardada'), 10);
    });
  });

  testWidgets('proveedor 4 recibe en la campana el mensaje del comprador', (tester) async {
    if (!const bool.fromEnvironment('LIVE')) return;
    HttpOverrides.global = null;
    TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
    await tester.runAsync(() async {
      Future<void> settle([int ms = 1500]) async {
        await Future<void>.delayed(Duration(milliseconds: ms));
        // Varios frames con tiempo: las transiciones de ruta (300 ms) se
        // completan; con un solo pump() quedaban a medio camino y los botones
        // fuera de la pantalla.
        for (var f = 0; f < 5; f++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final err = tester.takeException();
        if (err != null) fail('EXCEPCION: $err');
      }

      Future<void> waitFor(Finder f, [int seconds = 15]) async {
        for (var i = 0; i < seconds * 4; i++) {
          await settle(250);
          if (f.evaluate().isNotEmpty) return;
        }
        fail('No aparecio: $f');
      }

      await tester.pumpWidget(const ChapaTuRepuestoApp());
      await settle();
      await tester.enterText(find.byType(TextFormField).at(0), 'proveedor4@demo.pe');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');
      await tester.tap(find.widgetWithText(FilledButton, 'Ingresar'));
      await waitFor(find.byIcon(Icons.notifications_outlined));
      await waitFor(find.byType(Badge)); // hay no leidas
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await waitFor(find.textContaining('Mensaje de'));
      await tester.tap(find.byIcon(Icons.done_all));
      await settle(1500);
    });
  });
}
