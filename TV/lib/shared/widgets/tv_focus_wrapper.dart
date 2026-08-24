import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TVFocusWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleFactor;
  final bool showBorder;
  final Duration duration;
  final FocusNode? focusNode;
  final bool autoScroll;

  const TVFocusWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.scaleFactor = 1.08,
    this.showBorder = true,
    this.duration = const Duration(milliseconds: 200),
    this.focusNode,
    this.autoScroll = true,
  });

  @override
  State<TVFocusWrapper> createState() => _TVFocusWrapperState();
}

class _TVFocusWrapperState extends State<TVFocusWrapper> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });

      if (_isFocused && widget.autoScroll) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.5,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.space) {
            widget.onTap?.call();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isFocused ? widget.scaleFactor : 1.0,
          duration: widget.duration,
          curve: Curves.easeOutBack,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: widget.showBorder && _isFocused
                  ? Border.all(color: Colors.white, width: 2.0)
                  : Border.all(color: Colors.transparent, width: 2.0),
              boxShadow: _isFocused
                  ? [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.15),
                        blurRadius: 15,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
