import 'package:flutter/material.dart';

/// Barra de acciones del episodio para la WatchScreen (Crunchyroll Style).
///
/// Incluye:
/// - Me gusta (Thumbs Up) con contador.
/// - No me gusta (Thumbs Down) con contador.
/// - Compartir.
class WatchActionBar extends StatelessWidget {
  const WatchActionBar({
    super.key,
    this.likeCount = '20K',
    this.dislikeCount = '142',
    this.isLiked = false,
    this.isDisliked = false,
    this.onLikePressed,
    this.onDislikePressed,
    this.onSharePressed,
  });

  final String likeCount;
  final String dislikeCount;
  final bool isLiked;
  final bool isDisliked;
  final VoidCallback? onLikePressed;
  final VoidCallback? onDislikePressed;
  final VoidCallback? onSharePressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Me gusta
          InkWell(
            onTap: onLikePressed,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: isLiked ? const Color(0xFFEF7A1E) : Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    likeCount,
                    style: TextStyle(
                      color: isLiked ? const Color(0xFFEF7A1E) : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 16),

          // No me gusta
          InkWell(
            onTap: onDislikePressed,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    isDisliked ? Icons.thumb_down : Icons.thumb_down_outlined,
                    color: isDisliked ? Colors.redAccent : Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dislikeCount,
                    style: TextStyle(
                      color: isDisliked ? Colors.redAccent : Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Compartir
          IconButton(
            onPressed: onSharePressed,
            icon: const Icon(
              Icons.share_outlined,
              color: Colors.white70,
              size: 22,
            ),
            tooltip: 'Compartir',
          ),
        ],
      ),
    );
  }
}
