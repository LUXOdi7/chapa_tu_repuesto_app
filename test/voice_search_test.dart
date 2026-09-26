import 'dart:convert';

import 'package:chapa_tu_repuesto_app/features/catalog/presentation/widgets/voice_search_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// El dictado se cerraba dos veces: al tocar "Usar lo dictado" se hacia `pop`,
/// y el `stop()` del reconocedor disparaba el estado `notListening` que hacia
/// un segundo `pop` con el Navigator todavia ocupado ->
/// "Failed assertion: '!_debugLocked': is not true" (pantalla roja en Android).
///
/// Aqui se simula esa carrera con el canal del plugin.
const _canal = MethodChannel('plugin.csdcorp.com/speech_to_text');

String _resultado(String palabras, {required bool finalResult}) => jsonEncode({
  'alternates': [
    {'recognizedWords': palabras, 'recognizedPhrases': null, 'confidence': 0.9},
  ],
  'resultType': finalResult ? 2 : 0,
});

/// La hoja tiene un `LinearProgressIndicator` que nunca para, asi que
/// `pumpAndSettle` se cuelga: hay que avanzar el reloj a mano.
Future<void> _avanzar(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Mensaje del "dispositivo" hacia Dart (lo que en produccion manda Android).
Future<void> _desdeElPlugin(WidgetTester tester, String metodo, Object args) {
  return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    _canal.name,
    _canal.codec.encodeMethodCall(MethodCall(metodo, args)),
    (_) {},
  );
}

void main() {
  late TextEditingController controller;
  late List<String> buscado;

  setUp(() {
    controller = TextEditingController();
    buscado = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, (call) async {
          return switch (call.method) {
            'initialize' || 'listen' || 'has_permission' => true,
            'locales' => <String>['es_PE:Español (Perú)'],
            _ => null,
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_canal, null);
    controller.dispose();
  });

  /// El buscador se abre en una ruta EMPUJADA a proposito: si la hoja hace un
  /// segundo `pop`, se lleva por delante esta pantalla y el test lo ve. Con el
  /// buscador en la raiz, el pop de mas seria invisible.
  Future<void> abrirDictado(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Buscar repuestos')),
                      body: VoiceSearchBar(
                        controller: controller,
                        onChanged: buscado.add,
                      ),
                    ),
                  ),
                ),
                child: const Text('ir al buscador'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ir al buscador'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar repuestos'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.mic));
    await _avanzar(tester);
    expect(find.text('Usar lo dictado'), findsOneWidget);
  }

  /// La hoja se cerro y el buscador sigue ahi: no hubo `pop` de mas.
  void esperarBuscadorEnPie() {
    expect(find.text('Usar lo dictado'), findsNothing);
    expect(find.text('Buscar repuestos'), findsOneWidget);
  }

  testWidgets('"Usar lo dictado" cierra una sola vez aunque el reconocedor '
      'avise que dejó de escuchar', (tester) async {
    await abrirDictado(tester);

    await _desdeElPlugin(
      tester,
      'textRecognition',
      _resultado('pastillas de freno', finalResult: false),
    );
    await tester.pump();

    await tester.tap(find.text('Usar lo dictado'));
    // Sin esperar a que termine la animacion de cierre: es justo ahi donde el
    // plugin avisaba y el segundo pop reventaba.
    await tester.pump();
    await _desdeElPlugin(tester, 'notifyStatus', 'notListening');
    await _desdeElPlugin(tester, 'notifyStatus', 'done');
    await _avanzar(tester);

    expect(tester.takeException(), isNull);
    esperarBuscadorEnPie();
    expect(controller.text, 'pastillas de freno');
    expect(buscado, ['pastillas de freno']);
  });

  testWidgets('el resultado final y el aviso de fin no se pisan', (
    tester,
  ) async {
    await abrirDictado(tester);

    await _desdeElPlugin(
      tester,
      'textRecognition',
      _resultado('kit de arrastre', finalResult: true),
    );
    await tester.pump();
    await _desdeElPlugin(tester, 'notifyStatus', 'done');
    await _avanzar(tester);

    expect(tester.takeException(), isNull);
    esperarBuscadorEnPie();
    expect(controller.text, 'kit de arrastre');
  });

  testWidgets('cancelar no manda nada al buscador', (tester) async {
    await abrirDictado(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    await _desdeElPlugin(tester, 'notifyStatus', 'notListening');
    await _avanzar(tester);

    expect(tester.takeException(), isNull);
    esperarBuscadorEnPie();
    expect(controller.text, isEmpty);
    expect(buscado, isEmpty);
  });

  test('los códigos de error del reconocedor se traducen', () {
    expect(speechErrorText('not-allowed'), contains('micrófono'));
    expect(speechErrorText('network'), contains('Brave'));
    expect(speechErrorText('no-speech'), contains('No se escuchó nada'));
  });
}
