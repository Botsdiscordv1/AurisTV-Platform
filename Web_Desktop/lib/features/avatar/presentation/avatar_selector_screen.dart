// AurisTV Avatar Selector Screen
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../domain/avatar_catalog.dart';
import '../domain/avatar_franchise.dart';
import '../domain/avatar_selection.dart';
import 'providers/avatar_providers.dart';
import 'package:auris_core/auris_core.dart';
import '../../../core/utils/responsive_utils.dart';

class AvatarSelectorScreen extends ConsumerStatefulWidget {
  const AvatarSelectorScreen({super.key});

  @override
  ConsumerState<AvatarSelectorScreen> createState() => _AvatarSelectorScreenState();
}

class _AvatarSelectorScreenState extends ConsumerState<AvatarSelectorScreen> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider);
    _nameController = TextEditingController(text: user?.displayName ?? '');

    // Resetear la selección temporal al entrar para evitar heredar selecciones de otros perfiles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(avatarSelectionProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF0B0B0D);
    const surfaceColor = Color(0xFF1A1D24);
    const primaryColor = Color(0xFFEF7A1E);

    final user = ref.watch(authProvider);
    final catalogAsync = ref.watch(avatarCatalogProvider);
    final selection = ref.watch(avatarSelectionProvider);
    final currentCategory = ref.watch(avatarCategoryProvider);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Editar Perfil'),
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              final catalog = catalogAsync.valueOrNull;
              if (catalog != null) {
                // Guardar nombre
                final newName = _nameController.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(authProvider.notifier).updateProfileName(newName);
                }

                // Guardar avatar
                final selectedAvatar = _selectedPath(catalog, selection);
                if (selectedAvatar != null) {
                  ref.read(authProvider.notifier).updateAvatar(selectedAvatar);
                }
              }
              
              // Senior Fix: Navegación segura diferida
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  if (Navigator.canPop(context)) {
                    context.pop();
                  } else {
                    context.go('/select-profile');
                  }
                }
              });
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
      body: Column(
        children: [
          // Sección de Nombre (Nickname)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: TextField(
                controller: _nameController,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Tu nombre',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: primaryColor)),
                ),
              ),
            ),
          ),

          // Barra de Categorias (Estilo Prime Video / HomeScreen)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _CategoryPillBar(
                    currentCategory: currentCategory,
                    onCategoryChanged: (cat) =>
                        ref.read(avatarCategoryProvider.notifier).state = cat,
                  ),
                ),
              ),
            ),
          ),
          
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: catalogAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image_not_supported_outlined,
                              size: 48, color: Colors.white24),
                          const SizedBox(height: 12),
                          const Text('No se pudo cargar el catálogo de avatares',
                              style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          Text('$err',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  data: (catalog) {
                    final filteredFranchises = catalog.franchises
                        .where((f) => f.category == currentCategory)
                        .toList();

                    // Calculamos qué mostrar en la preview: la selección actual o el avatar que ya tiene el usuario
                    final previewPath = _selectedPath(catalog, selection) ?? user?.photoUrl;

                    if (filteredFranchises.isEmpty) {
                      return Column(
                        children: [
                          _PreviewAvatar(
                            selectedPath: previewPath,
                            primaryColor: primaryColor,
                          ),
                          Expanded(
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.category_outlined,
                                      size: 64, color: Colors.white10),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No hay avatares en esta categoria aun',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.3),
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: _PreviewAvatar(
                            selectedPath: previewPath,
                            primaryColor: primaryColor,
                          ),
                        ),
                        ...filteredFranchises.map((franchise) {
                          return SliverToBoxAdapter(
                            child: _AvatarFranchiseRow(
                              franchise: franchise,
                              selection: selection,
                              surfaceColor: surfaceColor,
                              primaryColor: primaryColor,
                            ),
                          );
                        }),
                        const SliverToBoxAdapter(child: SizedBox(height: 40)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _selectedPath(AvatarCatalog catalog, AvatarSelection selection) {
    for (final franchise in catalog.franchises) {
      for (final character in franchise.characters) {
        if (character.characterId == selection.characterId) {
          return character.variantAt(selection.variantIndex);
        }
      }
    }
    return null;
  }
}

class _PreviewAvatar extends StatelessWidget {
  final String? selectedPath;
  final Color primaryColor;

  const _PreviewAvatar({
    required this.selectedPath,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor, width: 4),
              image: selectedPath != null
                  ? DecorationImage(
                      image: selectedPath!.startsWith('assets/')
                          ? AssetImage(selectedPath!) as ImageProvider
                          : NetworkImage(selectedPath!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: selectedPath == null
                ? const Icon(Icons.person, size: 80, color: Colors.white24)
                : null,
          ),
        ],
      ),
    );
  }
}

class _AvatarItem extends StatelessWidget {
  final String characterName;
  final List<String> characterVariants;
  final bool isSelected;
  final int selectedVariantIndex;
  final Color surfaceColor;
  final Color primaryColor;
  final ValueChanged<int> onTap;

  const _AvatarItem({
    super.key,
    required this.characterName,
    required List<String> variants,
    required this.isSelected,
    required this.selectedVariantIndex,
    required this.surfaceColor,
    required this.primaryColor,
    required this.onTap,
  }) : characterVariants = variants;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(selectedVariantIndex),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              _AvatarCircle(
                assetPath: characterVariants.isNotEmpty
                    ? characterVariants[selectedVariantIndex.clamp(0, characterVariants.length - 1)]
                    : null,
                isSelected: isSelected,
                surfaceColor: surfaceColor,
                primaryColor: primaryColor,
              ),
              if (characterVariants.length > 1)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: GestureDetector(
                    onTap: () {
                      final next = (selectedVariantIndex + 1) % characterVariants.length;
                      onTap(next);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0B0B0D), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.5),
                            blurRadius: 4,
                          )
                        ],
                      ),
                      child: const Icon(Icons.sync_alt,
                          size: 14, color: Colors.black),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            characterName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white60,
              fontSize: 15,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String? assetPath;
  final bool isSelected;
  final Color surfaceColor;
  final Color primaryColor;

  const _AvatarCircle({
    required this.assetPath,
    required this.isSelected,
    required this.surfaceColor,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 120,
      height: 120,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? primaryColor : Colors.white10,
          width: 3.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: primaryColor.withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 3,
                )
              ]
            : null,
      ),
      child: ClipOval(
        child: assetPath != null
            ? Image.asset(
                assetPath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    Container(color: surfaceColor, child: const Icon(Icons.person, color: Colors.white24)),
              )
            : Container(
                color: surfaceColor,
                child: const Icon(Icons.person, color: Colors.white24),
              ),
      ),
    );
  }
}

class _CategoryPillBar extends StatelessWidget {
  final String currentCategory;
  final ValueChanged<String> onCategoryChanged;

  const _CategoryPillBar({
    required this.currentCategory,
    required this.onCategoryChanged,
  });

  double _calculateTextWidth(String text) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return textPainter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = ResponsiveUtils.isMobile(context);
    final double hPadding = isMobile ? 24.0 : 36.0;
    const double spacing = 8.0;

    final categories = [
      {'id': 'anime', 'label': 'Anime'},
      {'id': 'peliculas', 'label': 'Peliculas'},
      {'id': 'series', 'label': 'Series'},
      {'id': 'kdrama', 'label': 'KDrama'},
    ];

    final List<double> itemWidths = categories
        .map((c) => _calculateTextWidth(c['label']!) + hPadding)
        .toList();
    final activeIndex = categories.indexWhere((c) => c['id'] == currentCategory);

    double leftOffset = 0;
    for (int i = 0; i < activeIndex; i++) {
      leftOffset += itemWidths[i] + spacing;
    }

    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // LA PILDORA (El fondo que desliza)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            left: leftOffset,
            child: Container(
              width: itemWidths[activeIndex],
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),

          // LOS TEXTOS
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(categories.length, (index) {
              final cat = categories[index];
              final isSelected = index == activeIndex;
              return Padding(
                padding: EdgeInsets.only(
                    right: index == categories.length - 1 ? 0 : spacing),
                child: _PillNavItem(
                  label: cat['label']!,
                  isActive: isSelected,
                  width: itemWidths[index],
                  onTap: () => onCategoryChanged(cat['id']!),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PillNavItem extends StatefulWidget {
  final String label;
  final bool isActive;
  final double width;
  final VoidCallback onTap;

  const _PillNavItem({
    required this.label,
    required this.isActive,
    required this.width,
    required this.onTap,
  });

  @override
  State<_PillNavItem> createState() => _PillNavItemState();
}

class _PillNavItemState extends State<_PillNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _hovered = false); }),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.width,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: (!widget.isActive && _hovered)
                ? Colors.white.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: GoogleFonts.poppins(
              color: widget.isActive ? Colors.black : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
            child: Text(widget.label),
          ),
        ),
      ),
    );
  }
}

class _AvatarFranchiseRow extends ConsumerStatefulWidget {
  final AvatarFranchise franchise;
  final AvatarSelection selection;
  final Color surfaceColor;
  final Color primaryColor;

  const _AvatarFranchiseRow({
    required this.franchise,
    required this.selection,
    required this.surfaceColor,
    required this.primaryColor,
  });

  @override
  ConsumerState<_AvatarFranchiseRow> createState() => _AvatarFranchiseRowState();
}

class _AvatarFranchiseRowState extends ConsumerState<_AvatarFranchiseRow> {
  final ScrollController _scrollController = ScrollController();
  bool _isHovered = false;
  bool _canScrollLeft = false;
  bool _canScrollRight = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateScrollIndicators());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollIndicators() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    setState(() {
      _canScrollLeft = currentScroll > 5;
      _canScrollRight = maxScroll > currentScroll + 5;
    });
  }

  void _scroll(double offset) {
    if (!_scrollController.hasClients) return;
    final target = (_scrollController.offset + offset).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 600), curve: Curves.easeOutQuart);
  }

  @override
  Widget build(BuildContext context) {
    final isTactic = ResponsiveUtils.isTactic(context);

    return MouseRegion(
      onEnter: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = true); }),
      onExit: (_) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isHovered = false); }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Text(
              widget.franchise.name.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Stack(
            children: [
              SizedBox(
                height: 180,
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.franchise.characters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final character = widget.franchise.characters[index];
                    return SizedBox(
                      width: 130,
                      child: _AvatarItem(
                        key: ValueKey('avatar_${character.characterId}'),
                        characterName: character.name,
                        variants: character.variants,
                        isSelected: widget.selection.characterId != null &&
                            widget.selection.characterId == character.characterId,
                        selectedVariantIndex: widget.selection.characterId == character.characterId
                            ? widget.selection.variantIndex
                            : 0,
                        surfaceColor: widget.surfaceColor,
                        primaryColor: widget.primaryColor,
                        onTap: (variantIndex) {
                          ref.read(avatarSelectionProvider.notifier).select(
                                character.characterId,
                                variantIndex: variantIndex,
                              );
                        },
                      ),
                    );
                  },
                ),
              ),
              if (!isTactic) ...[
                // Flecha Izquierda
                Positioned(
                  left: 0, top: 0, height: 120, // Senior Fix: Centrado exacto con el círculo de 120px
                  child: AnimatedOpacity(
                    opacity: (_isHovered && _canScrollLeft) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Center(
                      child: NavArrow(
                        icon: Icons.arrow_back_ios_new,
                        onTap: () => _scroll(-400),
                      ),
                    ),
                  ),
                ),
                // Flecha Derecha
                Positioned(
                  right: 0, top: 0, height: 120, // Senior Fix: Centrado exacto con el círculo de 120px
                  child: AnimatedOpacity(
                    opacity: (_isHovered && _canScrollRight) ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Center(
                      child: NavArrow(
                        icon: Icons.arrow_forward_ios,
                        onTap: () => _scroll(400),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
