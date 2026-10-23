import 'package:flutter/material.dart';

import '../../../core/app_scope.dart';
import '../../../shared/widgets/app_widgets.dart';

/// Pagina de informacion legal y contacto.
///
/// section: 'about' | 'terms' | 'returns' | 'complaints'
class LegalPage extends StatefulWidget {
  const LegalPage({super.key, this.section = 'about'});

  static const route = '/legal';
  final String section;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage>
    with SingleTickerProviderStateMixin {
  static const _tabs = ['about', 'terms', 'returns', 'complaints'];
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    final idx = _tabs.indexOf(widget.section).clamp(0, 3);
    _tab = TabController(length: 4, vsync: this, initialIndex: idx);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Informacion'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Acerca de'),
            Tab(text: 'Terminos'),
            Tab(text: 'Devoluciones'),
            Tab(text: 'Reclamaciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _AboutTab(),
          _TermsTab(),
          _ReturnsTab(),
          _ComplaintsTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Acerca de
// ---------------------------------------------------------------------------
class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(child: BrandLogo(height: 80)),
        const SizedBox(height: 16),
        Text(
          'ChapaTuRepuesto',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Marketplace de repuestos de motocicleta',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        const SectionTitle('Que ofrecemos'),
        const _Body(
          'ChapaTuRepuesto es un marketplace que conecta talleres mecanicos, '
          'motociclistas y conductores de mototaxis con tiendas de autopartes '
          'de confianza en Chiclayo y la region.\n\n'
          'En nuestra plataforma encuentras:\n'
          '  • Motor y culata\n'
          '  • Frenos y discos\n'
          '  • Transmision y cadena\n'
          '  • Sistema electrico\n'
          '  • Carroceria y plasticos\n'
          '  • Llantas y neumaticos\n'
          '  • Lubricantes y filtros\n'
          '  • Accesorios y equipamiento\n\n'
          'Cada repuesto incluye informacion de compatibilidad por tipo de moto '
          '(lineal, carguero, mototaxi), marca, modelo y anio.',
        ),
        const SizedBox(height: 24),
        const SectionTitle('Contacto'),
        const _ContactTile(
          icon: Icons.phone_outlined,
          label: 'Telefono',
          value: '+51 992 712 408',
        ),
        const _ContactTile(
          icon: Icons.email_outlined,
          label: 'Correo electronico',
          value: 'luisbarboza0503@gmail.com',
        ),
        const _ContactTile(
          icon: Icons.location_on_outlined,
          label: 'Direccion',
          value: 'Calle Nueva York 198, Chiclayo, Peru',
        ),
        const SizedBox(height: 8),
        Text(
          'Horario de atencion: Lunes a Sabado, 8:00 am - 7:00 pm',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(label, style: Theme.of(context).textTheme.labelSmall),
    subtitle: Text(value),
  );
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

// ---------------------------------------------------------------------------
// Terminos y condiciones
// ---------------------------------------------------------------------------
class _TermsTab extends StatelessWidget {
  const _TermsTab();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      _LegalHeader('Terminos y Condiciones de Uso', 'Vigente desde el 01 de enero de 2025'),
      _Section('1. Identificacion del proveedor',
        'ChapaTuRepuesto es un servicio de intermediacion digital operado desde '
        'Calle Nueva York 198, Chiclayo, Peru. Contacto: luisbarboza0503@gmail.com / '
        '+51 992 712 408.'),
      _Section('2. Objeto del servicio',
        'ChapaTuRepuesto es un marketplace que facilita el contacto entre '
        'compradores y tiendas de autopartes independientes. No es vendedor directo: '
        'los contratos de compraventa se celebran entre el comprador y cada tienda '
        'proveedora.'),
      _Section('3. Registro y cuenta de usuario',
        'Para comprar o publicar productos es necesario registrarse con datos '
        'verdaderos. El usuario es responsable de mantener la confidencialidad de '
        'su contrasena. ChapaTuRepuesto puede suspender cuentas que incumplan estos '
        'terminos.'),
      _Section('4. Obligaciones del comprador',
        'El comprador se compromete a: (a) proporcionar una direccion de entrega '
        'valida; (b) pagar el monto acordado en el plazo indicado; '
        '(c) recibir el pedido y confirmar la entrega; '
        '(d) calificar la experiencia de compra de manera honesta.'),
      _Section('5. Obligaciones del proveedor',
        'El proveedor (tienda) se compromete a: (a) publicar solo productos '
        'disponibles con informacion veraz; (b) despachar en los plazos indicados; '
        '(c) contar con RUC activo y store verificada por ChapaTuRepuesto; '
        '(d) atender reclamaciones dentro de los plazos legales.'),
      _Section('6. Comisiones y pagos',
        'ChapaTuRepuesto aplica una comision del 1% sobre el monto de cada venta '
        'realizada a traves de la pasarela de pagos integrada. Las tiendas que operen '
        'en modalidad de pago manual (efectivo, transferencia directa) no pagan '
        'comision por la intermediacion.'),
      _Section('7. Propiedad intelectual',
        'El nombre, logotipo, diseno y codigo de ChapaTuRepuesto son propiedad de '
        'sus creadores. Las imagenes de productos son responsabilidad de cada tienda. '
        'Queda prohibida la reproduccion no autorizada del contenido de la plataforma.'),
      _Section('8. Privacidad y datos personales',
        'El tratamiento de datos personales se rige por la Ley N 29733 (Ley de '
        'Proteccion de Datos Personales del Peru) y su reglamento. Los datos '
        'recopilados se usan exclusivamente para operar el marketplace. No se ceden '
        'a terceros sin consentimiento, salvo obligacion legal.'),
      _Section('9. Limitacion de responsabilidad',
        'ChapaTuRepuesto no es responsable de: (a) calidad o estado de los productos '
        'vendidos por las tiendas; (b) retrasos por causa mayor; '
        '(c) uso incorrecto de los repuestos por parte del comprador. '
        'La plataforma facilita la comunicacion pero no garantiza el resultado de '
        'cada transaccion.'),
      _Section('10. Ley aplicable y resolucion de conflictos',
        'Estos terminos se rigen por las leyes de la Republica del Peru. Para '
        'reclamaciones de consumo, el usuario puede acudir a INDECOPI '
        '(www.indecopi.gob.pe) o usar el Libro de Reclamaciones integrado en esta '
        'app. La sede es Chiclayo, Peru.'),
      _Section('11. Modificaciones',
        'ChapaTuRepuesto puede actualizar estos terminos notificando a los usuarios '
        'con al menos 15 dias de anticipacion. El uso continuado de la plataforma '
        'implica la aceptacion de los terminos vigentes.'),
    ],
  );
}

// ---------------------------------------------------------------------------
// Politica de devoluciones
// ---------------------------------------------------------------------------
class _ReturnsTab extends StatelessWidget {
  const _ReturnsTab();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      _LegalHeader(
        'Politica de Cambios y Devoluciones',
        'Segun Ley N 29571 - Codigo de Proteccion al Consumidor',
      ),
      _Section('Plazo para ejercer el derecho',
        'Conforme al articulo 29 del Codigo de Proteccion al Consumidor (Ley 29571), '
        'el consumidor tiene 7 dias habiles desde la recepcion del producto para '
        'solicitar cambio o devolucion, sin necesidad de justificacion.'),
      _Section('Condiciones para la devolucion',
        'El producto debe estar en su estado original, sin uso, con empaque y '
        'accesorios completos. No se aceptan devoluciones de: '
        '(a) lubricantes o liquidos abiertos; '
        '(b) piezas instaladas salvo defecto de fabrica; '
        '(c) pedidos especiales o bajo encargo; '
        '(d) productos con codigo de parte alterado o sin etiqueta.'),
      _Section('Producto con defecto de fabrica',
        'Si el repuesto presenta defecto de fabrica, el consumidor tiene derecho a: '
        '(1) reparacion gratuita; (2) reemplazo del producto; '
        '(3) devolucion del precio pagado. '
        'El plazo para reclamar garantia es el indicado por cada tienda en la '
        'publicacion del producto (minimo 30 dias para piezas mecanicas).'),
      _Section('Proceso de devolucion',
        '1. Contacta a la tienda dentro del plazo indicado usando el chat del pedido.\n'
        '2. La tienda confirma la recepcion de la solicitud en 48 horas.\n'
        '3. Coordina el retiro o envio del producto segun acuerdo con la tienda.\n'
        '4. El reembolso se procesa en el mismo medio de pago dentro de 7 dias '
        'habiles tras confirmar la devolucion del producto.'),
      _Section('Costos de envio en devoluciones',
        'Si la devolucion se debe a un error de la tienda (producto incorrecto o '
        'defectuoso), el costo de envio es cubierto por la tienda. '
        'Si la devolucion es por arrepentimiento del comprador, el costo de '
        'envio lo asume el comprador.'),
      _Section('Reclamaciones no resueltas',
        'Si la tienda no da respuesta satisfactoria en el plazo legal, el '
        'consumidor puede: (a) usar el Libro de Reclamaciones integrado en esta '
        'app (pestana "Reclamaciones"); (b) acudir a INDECOPI; '
        '(c) contactar a ChapaTuRepuesto en luisbarboza0503@gmail.com.'),
    ],
  );
}

class _LegalHeader extends StatelessWidget {
  const _LegalHeader(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(body, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Libro de reclamaciones
// ---------------------------------------------------------------------------
class _ComplaintsTab extends StatefulWidget {
  const _ComplaintsTab();

  @override
  State<_ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<_ComplaintsTab> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _dni = TextEditingController();
  final _direccion = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _bien = TextEditingController();
  final _numPedido = TextEditingController();
  final _detalle = TextEditingController();
  final _pedidoConsumidor = TextEditingController();
  String _tipo = 'reclamo';
  bool _submitting = false;
  String? _correlativo;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Prellenar si hay sesion activa (solo en la primera llamada)
    if (_nombre.text.isNotEmpty) return;
    final user = AppScope.sessionOf(context).user;
    if (user == null) return;
    _nombre.text = user.name;
    _correo.text = user.email;
    _telefono.text = user.phone ?? '';
    _direccion.text = user.address ?? '';
  }

  @override
  void dispose() {
    for (final c in [
      _nombre, _dni, _direccion, _telefono, _correo,
      _bien, _numPedido, _detalle, _pedidoConsumidor,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final correlativo = await AppScope.of(context).auth.submitReclamacion(
        nombre: _nombre.text.trim(),
        dni: _dni.text.trim(),
        direccion: _direccion.text.trim(),
        telefono: _telefono.text.trim(),
        correo: _correo.text.trim(),
        tipo: _tipo,
        bienContratado: _bien.text.trim(),
        numPedido: _numPedido.text.trim(),
        detalle: _detalle.text.trim(),
        pedidoConsumidor: _pedidoConsumidor.text.trim(),
      );
      if (mounted) setState(() => _correlativo = correlativo);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_correlativo != null) return _Success(correlativo: _correlativo!);

    return FormBox(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _LegalHeader(
              'Libro de Reclamaciones',
              'ChapaTuRepuesto - Calle Nueva York 198, Chiclayo, Peru',
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Conforme al DS 011-2011-PCM y Ley 29571, toda empresa debe '
                  'contar con un Libro de Reclamaciones. Tu reclamacion sera '
                  'atendida en un maximo de 30 dias calendario. Al enviar '
                  'recibiras un numero correlativo como constancia.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Datos del consumidor'),
            _field(_nombre, 'Nombre y apellidos', required: true),
            _field(_dni, 'DNI / CE / Pasaporte', required: true,
                keyboard: TextInputType.number),
            _field(_direccion, 'Domicilio', required: true),
            _field(_telefono, 'Telefono', required: true,
                keyboard: TextInputType.phone),
            _field(_correo, 'Correo electronico', required: true,
                keyboard: TextInputType.emailAddress),
            const SizedBox(height: 16),
            const SectionTitle('Datos de la reclamacion'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tipo',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: 'reclamo',
                        label: Text('Reclamo'),
                      ),
                      ButtonSegment(
                        value: 'queja',
                        label: Text('Queja'),
                      ),
                    ],
                    selected: {_tipo},
                    onSelectionChanged: (v) =>
                        setState(() => _tipo = v.first),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _tipo == 'reclamo'
                        ? 'Reclamo: disconformidad con un producto o servicio '
                            '(exige compensacion o reposicion).'
                        : 'Queja: disconformidad con la atencion recibida '
                            '(no implica compensacion economica).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            _field(
              _bien,
              'Bien o servicio contratado',
              hint: 'Ej: Repuesto de freno CTR-000123 - Tienda El Motor',
              required: true,
            ),
            _field(_numPedido, 'Numero de pedido (opcional)',
                hint: 'Ej: CTR-000045'),
            _field(
              _detalle,
              'Detalle del reclamo o queja',
              hint: 'Describe con precision el problema (minimo 20 caracteres)',
              maxLines: 5,
              required: true,
              minLength: 20,
            ),
            _field(
              _pedidoConsumidor,
              'Lo que solicita al proveedor',
              hint: 'Ej: Devolucion del importe pagado / Reemplazo del producto',
              maxLines: 3,
              required: true,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enviar reclamacion'),
            ),
            const SizedBox(height: 8),
            Text(
              'Al enviar, recibes un numero correlativo como constancia. '
              'Guardalo para hacer seguimiento.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    String? hint,
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    bool required = false,
    int minLength = 0,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) return 'Campo requerido';
              if (v.trim().length < minLength) {
                return 'Minimo $minLength caracteres';
              }
              return null;
            }
          : null,
    ),
  );
}

class _Success extends StatelessWidget {
  const _Success({required this.correlativo});
  final String correlativo;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Reclamacion registrada',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Tu numero de reclamacion es:',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            correlativo,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Guardalo como constancia. Responderemos dentro de los\n'
            '30 dias calendario segun lo establece la Ley 29571.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    ),
  );
}
