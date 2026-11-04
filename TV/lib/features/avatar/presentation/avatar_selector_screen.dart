import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:auris_core/auris_core.dart';

import '../domain/avatar_franchise.dart';
import 'providers/avatar_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Netflix Ninja TV "Elige un icono" (Choose an Icon) — Pixel-Perfect Clone
//
// Key Netflix Ninja (TV) specifications:
//  • Canvas: Deep cinematic pure black (#000000)
//  • Header: Bold white title "Elige un icono" (32sp NetflixSans Bold)
//  • Subtitle: "Selecciona un nuevo icono para tu perfil." (#808080)
//  • Profile badge: Displays current avatar & profile name
//  • Organization: Horizontal carousels grouped by franchise / series
//  • Avatar tiles: Square 112×112dp with 8dp rounded corners
//  • Focused state: 3.5dp solid pure white border + 1.12x scale + deep drop shadow
//  • Unfocused state: Transparent border, 1.0x scale
//  • Selection dialog: Signature Netflix "¿Cambiar el icono del perfil?" modal
//    with side-by-side preview and [DE ACUERDO] / [AHORA NO] TV action buttons
//  • D-Pad traversal: Smooth horizontal and vertical remote navigation
// ─────────────────────────────────────────────────────────────────────────────

class AvatarSelectorScreen extends ConsumerStatefulWidget {
  final String? profileId;

  const AvatarSelectorScreen({super.key, this.profileId});

  @override
  ConsumerState<AvatarSelectorScreen> createState() =>
      _AvatarSelectorScreenState();
}

class _AvatarSelectorScreenState extends ConsumerState<AvatarSelectorScreen> {
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _showChangeConfirmation({
    required BuildContext context,
    required String targetProfileId,
    required String? currentPhotoUrl,
    required String newPhotoUrl,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => _NetflixAvatarConfirmDialog(
        currentPhotoUrl: currentPhotoUrl,
        newPhotoUrl: newPhotoUrl,
        onConfirm: () {
          ref
              .read(authProvider.notifier)
              .updateProfileAvatar(targetProfileId, newPhotoUrl);
          ref.read(authProvider.notifier).updateAvatar(newPhotoUrl);
          Navigator.pop(ctx);
          if (context.mounted) {
            context.pop();
          }
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFF000000);
    final user = ref.watch(authProvider);
    final catalogAsync = ref.watch(avatarCatalogProvider);

    final targetProfile = user?.profiles.firstWhere(
      (p) => p.id == widget.profileId,
      orElse: () => user.profiles.firstWhere(
        (p) => p.id == user.activeProfileId,
        orElse: () => user.profiles.first,
      ),
    );

    final profileIdToUpdate = targetProfile?.id ?? user?.activeProfileId ?? '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (Navigator.canPop(context)) {
          context.pop();
        } else {
          context.go('/select-profile');
        }
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Section ──────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 50, vertical: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Elige un icono',
                          style: TextStyle(
                            fontFamily: 'NetflixSans',
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Selecciona un nuevo icono para tu perfil de AurisTV.',
                          style: TextStyle(
                            fontFamily: 'NetflixSans',
                            color: Color(0xFF808080),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Current Profile Badge
                    if (targetProfile != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181818),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: SizedBox(
                                width: 34,
                                height: 34,
                                child: _AvatarImage(
                                    photoUrl: targetProfile.photoUrl),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ICONO ACTUAL',
                                  style: TextStyle(
                                    fontFamily: 'NetflixSans',
                                    color: Color(0xFF808080),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                Text(
                                  targetProfile.name,
                                  style: const TextStyle(
                                    fontFamily: 'NetflixSans',
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // ── Franchise / Category Rows ────────────────────────────────
              Expanded(
                child: catalogAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Text(
                      'No se pudo cargar el catálogo de avatares.',
                      style: TextStyle(
                        fontFamily: 'NetflixSans',
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  data: (catalog) {
                    final franchises = catalog.franchises;
                    if (franchises.isEmpty) {
                      return const Center(
                        child: Text(
                          'No hay avatares disponibles.',
                          style: TextStyle(
                            fontFamily: 'NetflixSans',
                            color: Colors.white60,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _verticalScrollController,
                      padding: const EdgeInsets.only(bottom: 40),
                      itemCount: franchises.length,
                      itemBuilder: (context, rowIndex) {
                        final franchise = franchises[rowIndex];
                        return _NetflixFranchiseCarousel(
                          franchise: franchise,
                          isFirstRow: rowIndex == 0,
                          onAvatarSelected: (avatarPath) {
                            _showChangeConfirmation(
                              context: context,
                              targetProfileId: profileIdToUpdate,
                              currentPhotoUrl: targetProfile?.photoUrl,
                              newPhotoUrl: avatarPath,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Bottom Remote Hint ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white.withValues(alpha: 0.4),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Presiona Atrás para cancelar',
                      style: TextStyle(
                        fontFamily: 'NetflixSans',
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Franchise Carousel Row
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixFranchiseCarousel extends StatelessWidget {
  final AvatarFranchise franchise;
  final bool isFirstRow;
  final ValueChanged<String> onAvatarSelected;

  const _NetflixFranchiseCarousel({
    required this.franchise,
    required this.isFirstRow,
    required this.onAvatarSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Flatten all variants from all characters in this franchise
    final List<String> allVariants = [];
    for (final char in franchise.characters) {
      allVariants.addAll(char.variants);
    }

    if (allVariants.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Text(
              franchise.name,
              style: const TextStyle(
                fontFamily: 'NetflixSans',
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Horizontal Carousel
          SizedBox(
            height: 136, // accommodates 112px tile + 1.12x scale + shadow
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 8),
              itemCount: allVariants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final variantPath = allVariants[index];
                return _NetflixAvatarTile(
                  avatarPath: variantPath,
                  autofocus: isFirstRow && index == 0,
                  onSelect: () => onAvatarSelected(variantPath),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Individual Avatar Tile with Netflix 10-foot Focus
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixAvatarTile extends StatefulWidget {
  final String avatarPath;
  final bool autofocus;
  final VoidCallback onSelect;

  const _NetflixAvatarTile({
    required this.avatarPath,
    required this.autofocus,
    required this.onSelect,
  });

  @override
  State<_NetflixAvatarTile> createState() => _NetflixAvatarTileState();
}

class _NetflixAvatarTileState extends State<_NetflixAvatarTile> {
  bool _hasFocus = false;

  static const double kTileSize = 112.0;
  static const double kRadius = 8.0;
  static const double kBorderWidth = 3.5;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onSelect();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onSelect,
        child: AnimatedScale(
          scale: _hasFocus ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: Container(
            width: kTileSize,
            height: kTileSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(
                color: _hasFocus ? Colors.white : Colors.transparent,
                width: kBorderWidth,
              ),
              boxShadow: _hasFocus
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                  _hasFocus ? kRadius - kBorderWidth / 2 : kRadius),
              child: _AvatarImage(photoUrl: widget.avatarPath),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirmation Modal Dialog (Netflix TV "¿Cambiar el icono del perfil?")
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixAvatarConfirmDialog extends StatelessWidget {
  final String? currentPhotoUrl;
  final String newPhotoUrl;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _NetflixAvatarConfirmDialog({
    required this.currentPhotoUrl,
    required this.newPhotoUrl,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF181818),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      title: const Text(
        '¿Cambiar el icono del perfil?',
        style: TextStyle(
          fontFamily: 'NetflixSans',
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comparison Preview Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Current Icon
                Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _AvatarImage(photoUrl: currentPhotoUrl),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Actual',
                      style: TextStyle(
                        fontFamily: 'NetflixSans',
                        color: Color(0xFF808080),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white70,
                    size: 26,
                  ),
                ),

                // New Selected Icon
                Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _AvatarImage(photoUrl: newPhotoUrl),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nuevo',
                      style: TextStyle(
                        fontFamily: 'NetflixSans',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 20),
            Text(
              'Tu nuevo icono se sincronizará y actualizará en todos tus dispositivos.',
              style: TextStyle(
                fontFamily: 'NetflixSans',
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // AHORA NO
            _NetflixDialogButton(
              label: 'AHORA NO',
              isPrimary: false,
              autofocus: false,
              onPressed: onCancel,
            ),
            const SizedBox(width: 12),
            // DE ACUERDO
            _NetflixDialogButton(
              label: 'DE ACUERDO',
              isPrimary: true,
              autofocus: true,
              onPressed: onConfirm,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog Action Button with TV Focus Inversion
// ─────────────────────────────────────────────────────────────────────────────

class _NetflixDialogButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final bool autofocus;
  final VoidCallback onPressed;

  const _NetflixDialogButton({
    required this.label,
    required this.isPrimary,
    required this.autofocus,
    required this.onPressed,
  });

  @override
  State<_NetflixDialogButton> createState() => _NetflixDialogButtonState();
}

class _NetflixDialogButtonState extends State<_NetflixDialogButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = _hasFocus
        ? Colors.white
        : (widget.isPrimary
            ? const Color(0xFF333333)
            : const Color(0xFF262626));
    final Color textColor = _hasFocus ? Colors.black : Colors.white;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'NetflixSans',
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar Image Component
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarImage extends StatelessWidget {
  final String? photoUrl;
  const _AvatarImage({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      return Container(
        color: const Color(0xFF1C1C1C),
        alignment: Alignment.center,
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xFF808080),
          size: 40,
        ),
      );
    }
    if (photoUrl!.startsWith('assets/')) {
      return Image.asset(photoUrl!, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: photoUrl!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xFF1C1C1C)),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xFF1C1C1C),
        alignment: Alignment.center,
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xFF808080),
          size: 40,
        ),
      ),
    );
  }
}
