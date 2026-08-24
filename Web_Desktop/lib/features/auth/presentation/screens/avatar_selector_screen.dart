import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';

class AvatarSelectorScreen extends ConsumerStatefulWidget {
  const AvatarSelectorScreen({super.key});

  @override
  ConsumerState<AvatarSelectorScreen> createState() => _AvatarSelectorScreenState();
}

class _AvatarSelectorScreenState extends ConsumerState<AvatarSelectorScreen> {
  String? _selectedUrl;

  @override
  void initState() {
    super.initState();
    // Inicializar con el avatar actual del usuario
    final user = ref.read(authProvider);
    _selectedUrl = user?.photoUrl;
  }

  @override
  Widget build(BuildContext context) {
    // Colores del tema AurisTV (basados en settings_screen.dart)
    const backgroundColor = Color(0xFF0B0B0D);
    const surfaceColor = Color(0xFF1A1D24);
    const primaryColor = Color(0xFFEF7A1E);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              // Aquí iría la lógica de guardado que el usuario implementará
              Navigator.pop(context);
            },
            child: const Text(
              'Listo',
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Previsualización superior
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: primaryColor, width: 3),
                          image: _selectedUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(_selectedUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedUrl == null
                            ? const Icon(Icons.person, size: 80, color: Colors.white24)
                            : null,
                      ),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit, size: 20, color: Colors.black),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Elige un nuevo icono de perfil',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          // Categorías (Ejemplo tipo Prime Video)
          ..._buildAvatarSections(primaryColor, surfaceColor),
        ],
      ),
    );
  }

  List<Widget> _buildAvatarSections(Color primaryColor, Color surfaceColor) {
    // El usuario se encargará de la lógica de estas listas.
    // Esto es solo el esqueleto visual.
    final categories = ['Populares', 'Anime', 'Clásicos', 'Auris Originals'];

    return categories.map((category) {
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Text(
                category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // Mock de URL de Pinterest
                  final String mockUrl = 'https://picsum.photos/seed/${category.hashCode + index}/200';
                  final bool isSelected = _selectedUrl == mockUrl;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedUrl = mockUrl;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? primaryColor : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: mockUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(color: surfaceColor),
                            errorWidget: (context, url, error) => const Icon(Icons.error),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: 4, // 4 avatares por categoría para el esqueleto
              ),
            ),
          ),
        ],
      );
    }).toList();
  }
}
