import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// Ảnh gửi lên tối đa 1 MB (web `AVATAR_MAX_UPLOAD_BYTES`; máy chủ từ chối tệp lớn hơn).
const int kAvatarMaxUploadBytes = 1024 * 1024;

/// Ảnh gốc người dùng chọn tối đa 5 MB (web `AVATAR_MAX_SOURCE_BYTES`).
const int kAvatarMaxSourceBytes = 5 * 1024 * 1024;

/// Cạnh ảnh đại diện sau khi thu nhỏ (web `AVATAR_SIZE_PX`).
const int kAvatarSizePx = 512;

/// Lỗi chuẩn bị ảnh đại diện; [code] là `too_small` | `decode` | `encode`.
class AvatarImageException implements Exception {
  final String code;
  const AvatarImageException(this.code);
}

/// Web `prepareAvatarImage`: cắt vuông ([crop] là vùng vuông người dùng chọn, tính theo điểm ảnh của ảnh gốc;
/// bỏ trống thì lấy ở giữa), thu về tối đa 512×512 trên nền trắng rồi nén JPEG (chất lượng 90, quá
/// 1 MB thì 75). Ảnh gửi lên vì thế luôn nhỏ và đúng định dạng máy chủ nhận; ảnh gốc 5 MB không phải đi qua mạng.
/// Giải mã bằng bộ giải mã của hệ điều hành nên đọc được cả ảnh HEIC của iPhone.
Future<Uint8List> prepareAvatarImage(Uint8List source, {ui.Rect? crop}) async {
  final ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(source);
  } catch (_) {
    throw const AvatarImageException('decode');
  }
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final maxSide = image.width < image.height ? image.width : image.height;
  // Vùng cắt nằm gọn trong ảnh; không có thì lấy hình vuông lớn nhất ở giữa.
  final side = crop == null ? maxSide : crop.width.round().clamp(1, maxSide);
  if (side < 32) {
    image.dispose();
    throw const AvatarImageException('too_small');
  }
  final size = side < kAvatarSizePx ? side : kAvatarSizePx;
  final double sx = crop == null ? (image.width - side) / 2 : crop.left.clamp(0.0, (image.width - side).toDouble());
  final double sy = crop == null ? (image.height - side) / 2 : crop.top.clamp(0.0, (image.height - side).toDouble());

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(sx, sy, side.toDouble(), side.toDouble()),
    ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final scaled = await recorder.endRecording().toImage(size, size);
  image.dispose();
  final rgba = await scaled.toByteData(format: ui.ImageByteFormat.rawRgba);
  scaled.dispose();
  if (rgba == null) throw const AvatarImageException('encode');

  final pixels = img.Image.fromBytes(
    width: size,
    height: size,
    bytes: rgba.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  for (final quality in const [90, 75]) {
    final jpeg = img.encodeJpg(pixels, quality: quality);
    if (jpeg.length <= kAvatarMaxUploadBytes) return jpeg;
  }
  throw const AvatarImageException('encode');
}
