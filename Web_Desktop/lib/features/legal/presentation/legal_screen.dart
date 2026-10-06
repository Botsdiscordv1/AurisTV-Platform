import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LegalScreen extends StatelessWidget {
  final bool isTerms;

  const LegalScreen({
    super.key,
    required this.isTerms,
  });

  @override
  Widget build(BuildContext context) {
    final title = isTerms ? 'Términos de Uso' : 'Política de Privacidad';
    
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141418),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/inicio');
            }
          },
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF7A1E),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Última actualización: ${DateTime.now().year}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 32),
                if (isTerms) ..._buildTermsContent() else ..._buildPrivacyContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTermsContent() {
    return [
      _buildSectionTitle('1. Aceptación de los Términos'),
      _buildParagraph(
        'Bienvenido a AurisTV. Al acceder, registrarte o utilizar nuestra plataforma de streaming y entretenimiento, aceptas cumplir y estar sujeto a estos Términos de Uso. Si no estás de acuerdo con alguno de estos términos, por favor no utilices nuestros servicios.',
      ),
      _buildSectionTitle('2. Descripción del Servicio'),
      _buildParagraph(
        'AurisTV es una plataforma digital de entretenimiento y catálogo multimedia que permite a los usuarios descubrir, organizar y reproducir contenido multimedia de diversas fuentes y catálogos en línea de forma centralizada.',
      ),
      _buildSectionTitle('3. Cuentas y Seguridad'),
      _buildParagraph(
        'Para acceder a ciertas funciones de la plataforma, es posible que debas iniciar sesión o sincronizar cuentas externas (como AniList o Simkl). Eres responsable de mantener la confidencialidad de tus credenciales y de todas las actividades que ocurran bajo tu cuenta.',
      ),
      _buildSectionTitle('4. Propiedad Intelectual y Contenido'),
      _buildParagraph(
        'Todo el diseño de la interfaz de usuario, logotipos, código fuente y marca AurisTV son propiedad exclusiva de la plataforma. Los contenidos multimedia reproducidos a través de fuentes externas pertenecen a sus respectivos creadores y titulares de derechos.',
      ),
      _buildSectionTitle('5. Modificaciones del Servicio'),
      _buildParagraph(
        'Nos reservamos el derecho de modificar, suspender o discontinuar temporal o permanentemente el servicio de AurisTV (o cualquier parte del mismo) en cualquier momento y sin previo aviso.',
      ),
      _buildSectionTitle('6. Contacto'),
      _buildParagraph(
        'Si tienes preguntas sobre estos Términos de Uso, puedes ponerte en contacto con el equipo de soporte a través de nuestros canales oficiales o sitio web principal en https://auristv.dpdns.org.',
      ),
    ];
  }

  List<Widget> _buildPrivacyContent() {
    return [
      _buildSectionTitle('1. Información que Recopilamos'),
      _buildParagraph(
        'En AurisTV valoramos tu privacidad. Recopilamos información mínima necesaria para el funcionamiento de la aplicación, como preferencias de usuario, historial de reproducción local almacenado en tu dispositivo y datos de sincronización con servicios externos autorizados por ti (como AniList o Simkl).',
      ),
      _buildSectionTitle('2. Almacenamiento Local (Cache e Historial)'),
      _buildParagraph(
        'Utilizamos almacenamiento local seguro en tu dispositivo (mediante Hive) para guardar tus ajustes personalizados, favoritos y el historial reciente de reproducción, garantizando una experiencia rápida y privada.',
      ),
      _buildSectionTitle('3. Uso de la Información'),
      _buildParagraph(
        'La información recopilada se utiliza exclusivamente para personalizar tu experiencia en la plataforma, sincronizar tu progreso multimedia y mejorar el rendimiento general del servicio.',
      ),
      _buildSectionTitle('4. Protección de Datos'),
      _buildParagraph(
        'Implementamos medidas de seguridad técnicas y organizativas para proteger tus datos contra acceso no autorizado, alteración, divulgación o destrucción.',
      ),
      _buildSectionTitle('5. Enlaces a Terceros'),
      _buildParagraph(
        'Nuestra plataforma puede interactuar con servicios externos. No somos responsables de las prácticas de privacidad ni de los contenidos de dichos sitios web o servicios de terceros.',
      ),
      _buildSectionTitle('6. Cambios en la Política de Privacidad'),
      _buildParagraph(
        'Podemos actualizar nuestra Política de Privacidad periódicamente. Te notificaremos cualquier cambio publicando la nueva política en esta misma página.',
      ),
    ];
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFEF7A1E),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withOpacity(0.8),
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }
}
