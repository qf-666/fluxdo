import 'dart:async';

import 'package:flutter/material.dart';

import 'local_notification_service.dart';

/// Toast 类型
enum ToastType { success, error, info }

/// 全局 Toast 服务（基于 Overlay，显示在屏幕顶部）
class ToastService {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;
  static AnimationController? _currentController;

  /// 显示 Toast
  static void show(
    String message, {
    ToastType type = ToastType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    // 移除旧 Toast
    _dismiss(animate: false);

    late final AnimationController controller;
    late final OverlayEntry entry;

    // 用 OverlayEntry 的 builder 获取 TickerProvider
    entry = OverlayEntry(
      builder: (context) {
        return _ToastWidget(
          message: message,
          type: type,
          actionLabel: actionLabel,
          onAction: onAction,
          onControllerCreated: (c) {
            controller = c;
            _currentController = c;
            controller.forward();
          },
          onDismiss: () => _dismiss(animate: true),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);

    // 自动消失
    _dismissTimer = Timer(duration, () => _dismiss(animate: true));
  }

  /// 显示成功提示
  static void showSuccess(String message) {
    show(message, type: ToastType.success);
  }

  /// 显示错误提示
  static void showError(String message) {
    show(message, type: ToastType.error);
  }

  /// 显示信息提示
  static void showInfo(String message) {
    show(message, type: ToastType.info);
  }

  static void _dismiss({required bool animate}) {
    _dismissTimer?.cancel();
    _dismissTimer = null;

    if (animate && _currentController != null) {
      final controller = _currentController!;
      final entry = _currentEntry;
      _currentEntry = null;
      _currentController = null;
      controller.reverse().then((_) {
        entry?.remove();
        controller.dispose();
      });
    } else {
      _currentController?.dispose();
      _currentController = null;
      _currentEntry?.remove();
      _currentEntry = null;
    }
  }
}

/// Toast 内容组件
class _ToastWidget extends StatefulWidget {
  final String message;
  final ToastType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final void Function(AnimationController) onControllerCreated;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.type,
    this.actionLabel,
    this.onAction,
    required this.onControllerCreated,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _iconAnimation;
  double _dragOffset = 0;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _iconAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOutCubic),
      ),
    );
    widget.onControllerCreated(_controller);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_dismissing) return;
    // 只允许向上拖动
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dy).clamp(-double.infinity, 0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_dismissing) return;
    // 向上拖动超过 40px 或速度足够快则消失
    if (_dragOffset < -40 || details.velocity.pixelsPerSecond.dy < -200) {
      _dismissing = true;
      widget.onDismiss();
    } else {
      // 弹回原位
      setState(() => _dragOffset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final (icon, iconColor) = switch (widget.type) {
      ToastType.success => (Icons.check_circle_rounded, const Color(0xFF10B981)), // Emerald
      ToastType.error => (Icons.error_rounded, colorScheme.error),
      ToastType.info => (Icons.info_rounded, colorScheme.primary),
    };

    return Positioned(
      top: mediaQuery.padding.top + 16,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Opacity(
                  opacity: (_dragOffset < 0)
                      ? (1.0 + _dragOffset / 120).clamp(0.0, 1.0)
                      : 1.0,
                  child: GestureDetector(
                    onVerticalDragUpdate: _onVerticalDragUpdate,
                    onVerticalDragEnd: _onVerticalDragEnd,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          // Base dark shadow
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                          // Colored glow shadow
                          BoxShadow(
                            color: iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
                            blurRadius: 24,
                            spreadRadius: -2,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(10, 10, 20, 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: iconColor.withValues(alpha: 0.15), // Colored circle behind icon
                              shape: BoxShape.circle,
                            ),
                            child: widget.type == ToastType.success
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: _AnimatedCheckmark(
                                      progress: _iconAnimation,
                                      color: iconColor,
                                    ),
                                  )
                                : Icon(icon, color: iconColor, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              widget.message,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onInverseSurface, // Adapt text color
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.actionLabel != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              width: 1,
                              height: 16,
                              color: colorScheme.onInverseSurface.withValues(alpha: 0.2),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                            ),
                            TextButton(
                              onPressed: () {
                                widget.onAction?.call();
                                widget.onDismiss();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: iconColor,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(0, 32),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                              child: Text(
                                widget.actionLabel!,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedCheckmark extends StatelessWidget {
  final Animation<double> progress;
  final Color color;

  const _AnimatedCheckmark({
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        return CustomPaint(
          painter: _CheckmarkPainter(
            progress: progress.value,
            color: color,
          ),
        );
      },
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CheckmarkPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Centered coordinates for a checkmark icon that looks like the material one
    final start = Offset(size.width * 0.28, size.height * 0.52);
    final mid = Offset(size.width * 0.45, size.height * 0.70);
    final end = Offset(size.width * 0.72, size.height * 0.35);

    final pathLength1 = (mid - start).distance;
    final pathLength2 = (end - mid).distance;
    final totalLength = pathLength1 + pathLength2;

    final currentLength = totalLength * progress;

    if (currentLength <= pathLength1) {
      // Draw first segment (the short dive)
      final currentMid = Offset.lerp(start, mid, currentLength / pathLength1)!;
      path.moveTo(start.dx, start.dy);
      path.lineTo(currentMid.dx, currentMid.dy);
    } else {
      // Draw first segment full
      path.moveTo(start.dx, start.dy);
      path.lineTo(mid.dx, mid.dy);
      // Draw second segment (the long tail upwards)
      final remainingLength = currentLength - pathLength1;
      final currentEnd =
          Offset.lerp(mid, end, remainingLength / pathLength2)!;
      path.lineTo(currentEnd.dx, currentEnd.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
