import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/i18n/app_i18n.dart';

/// Màn chọn vùng cắt ảnh đại diện: ảnh nằm trong khung vuông có vòng tròn đánh dấu phần sẽ thành ảnh đại diện;
/// kéo để di chuyển, chụm hai ngón để phóng to/thu nhỏ; ảnh luôn phủ kín khung. Trả vùng vuông đã chọn theo điểm ảnh
/// của ảnh gốc (dùng cho `prepareAvatarImage(crop:)`), null khi huỷ.
Future<Rect?> showAvatarCropScreen(BuildContext context, Uint8List bytes) {
  return Navigator.of(context).push<Rect>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => _AvatarCropScreen(bytes: bytes)),
  );
}

class _AvatarCropScreen extends StatefulWidget {
  final Uint8List bytes;
  const _AvatarCropScreen({required this.bytes});

  @override
  State<_AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<_AvatarCropScreen> {
  final TransformationController _transform = TransformationController();
  Size? _imageSize;
  bool _failed = false;

  /// Cạnh khung cắt và tỉ lệ đặt ảnh vào khung (cạnh ngắn của ảnh vừa bằng khung) của lần dựng gần nhất.
  double _viewport = 0;
  double _baseScale = 1;
  bool _positioned = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      final size = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      if (!mounted) return;
      setState(() => _imageSize = size);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Đặt ảnh vào giữa khung lần đầu (sau khi biết kích thước khung).
  void _centerOnce(Size child) {
    if (_positioned) return;
    _positioned = true;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-(child.width - _viewport) / 2, -(child.height - _viewport) / 2, 0, 1);
  }

  void _confirm() {
    final image = _imageSize;
    if (image == null || _viewport <= 0) return;
    final m = _transform.value;
    final scale = m.getMaxScaleOnAxis();
    final translation = m.getTranslation();
    // Khung (0,0)-(viewport,viewport) quy về toạ độ ảnh đã đặt vào khung, rồi về điểm ảnh của ảnh gốc.
    final left = (-translation.x / scale) / _baseScale;
    final top = (-translation.y / scale) / _baseScale;
    final side = (_viewport / scale) / _baseScale;
    final maxSide = image.width < image.height ? image.width : image.height;
    final s = side.clamp(1.0, maxSide);
    Navigator.of(context).pop(Rect.fromLTWH(
      left.clamp(0.0, image.width - s),
      top.clamp(0.0, image.height - s),
      s,
      s,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final image = _imageSize;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('account.avatar.crop_title'.tr(), style: const TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _failed
                  ? Center(
                      child: Text('account.avatar.prepare_decode'.tr(),
                          style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                    )
                  : image == null
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : LayoutBuilder(builder: (context, constraints) {
                          final side = (constraints.biggest.shortestSide - 32).clamp(120.0, 600.0);
                          _viewport = side;
                          _baseScale = side / (image.width < image.height ? image.width : image.height);
                          final child = Size(image.width * _baseScale, image.height * _baseScale);
                          _centerOnce(child);
                          return Center(
                            child: SizedBox(
                              width: side,
                              height: side,
                              child: Stack(
                                children: [
                                  ClipRect(
                                    child: InteractiveViewer(
                                      transformationController: _transform,
                                      constrained: false,
                                      minScale: 1,
                                      maxScale: 6,
                                      boundaryMargin: EdgeInsets.zero,
                                      child: SizedBox(
                                        width: child.width,
                                        height: child.height,
                                        child: Image.memory(widget.bytes, fit: BoxFit.fill, gaplessPlayback: true),
                                      ),
                                    ),
                                  ),
                                  IgnorePointer(
                                    child: CustomPaint(size: Size(side, side), painter: _CircleMaskPainter()),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                'account.avatar.crop_hint'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('common.cancel'.tr()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: image == null ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFACC15),
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: Text('account.avatar.crop_use'.tr(), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Làm tối phần ngoài vòng tròn (phần ảnh đại diện hiển thị) và vẽ viền vòng tròn.
class _CircleMaskPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Path()..addOval(rect.deflate(1));
    final mask = Path.combine(PathOperation.difference, Path()..addRect(rect), circle);
    canvas.drawPath(mask, Paint()..color = Colors.black.withValues(alpha: 0.55));
    canvas.drawOval(
      rect.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
