import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A [painter] drawn once into an image at the screen's own resolution,
/// and that image shown from then on: for a drawing too heavy to paint
/// every frame that changes only now and then.
///
/// It is drawn again when [identity] changes (compared with ==), or the
/// size or the pixel ratio does; never because something around it
/// moved.
class SnapshotPaint extends StatefulWidget {
  final CustomPainter painter;
  final Object identity;

  const SnapshotPaint({
    super.key,
    required this.painter,
    required this.identity,
  });

  @override
  State<SnapshotPaint> createState() => _SnapshotPaintState();
}

class _SnapshotPaintState extends State<SnapshotPaint> {
  ui.Image? _image;
  Object? _identity;
  Size? _size;
  double? _ratio;

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  ui.Image? _imageFor(Size size, double ratio) {
    if (size.isEmpty) return null;
    if (_image != null &&
        _identity == widget.identity &&
        _size == size &&
        _ratio == ratio) {
      return _image;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(ratio);
    widget.painter.paint(canvas, size);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.width * ratio).ceil(),
      (size.height * ratio).ceil(),
    );
    picture.dispose();
    _image?.dispose();
    _image = image;
    _identity = widget.identity;
    _size = size;
    _ratio = ratio;
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final image = _imageFor(size, ratio);
        if (image == null) return const SizedBox.expand();
        return RawImage(
          image: image,
          width: size.width,
          height: size.height,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}
