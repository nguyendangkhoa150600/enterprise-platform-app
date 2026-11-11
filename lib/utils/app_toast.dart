import 'package:flutter/material.dart';

/// Toast thông báo toàn cục hiển thị ở lớp Overlay cao nhất (Root Overlay),
/// đảm bảo NỔI TRÊN MỌI MODAL, BOTTOM SHEET, DIALOG hoặc KEYBOARD.
class AppToast {
  static OverlayEntry? _currentEntry;

  /// Hiển thị Toast thông báo với hiệu ứng trượt mượt mà từ trên xuống
  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    // Xoá toast cũ nếu đang hiển thị
    _dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlayWidget(
        message: message,
        isError: isError,
        onDismiss: () {
          if (_currentEntry == entry) {
            _dismiss();
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    Future.delayed(duration, () {
      if (_currentEntry == entry) {
        _dismiss();
      }
    });
  }

  static void success(BuildContext context, String message) =>
      show(context, message, isError: false);

  static void error(BuildContext context, String message) =>
      show(context, message, isError: true);

  static void _dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _ToastOverlayWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  const _ToastOverlayWidget({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  @override
  State<_ToastOverlayWidget> createState() => _ToastOverlayWidgetState();
}

class _ToastOverlayWidgetState extends State<_ToastOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack));

    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _handleDismiss() async {
    await _animCtrl.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 14;

    final bgColor = widget.isError ? const Color(0xFFDC2626) : const Color(0xFF059669);
    final icon = widget.isError ? Icons.error_outline_rounded : Icons.check_circle_rounded;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnim,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: GestureDetector(
              onTap: _handleDismiss,
              onVerticalDragUpdate: (details) {
                if (details.primaryDelta != null && details.primaryDelta! < -4) {
                  _handleDismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: _handleDismiss,
                      child: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
