import 'dart:io';

import 'package:image/image.dart' as img;

/// Packages the approved transparent logo for launcher and in-app use.
void main(List<String> arguments) {
  final source = img.decodePng(File(arguments.single).readAsBytesSync())!;
  final mark = img.copyResize(
    source,
    width: 880,
    height: 880,
    interpolation: img.Interpolation.cubic,
  );
  final foreground = img.Image(width: 1024, height: 1024, numChannels: 4);
  img.compositeImage(foreground, mark, dstX: 72, dstY: 72);
  File('assets/icon/app_icon_foreground.png')
      .writeAsBytesSync(img.encodePng(foreground));
  final flat = img.Image(width: 1024, height: 1024, numChannels: 3);
  img.fill(flat, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flat, foreground);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(flat));
  File('assets/branding/fast_ride_mark_source.png')
      .writeAsBytesSync(File(arguments.single).readAsBytesSync());
  stdout.writeln(
    'Packaged 1024px opaque RGB icon and transparent adaptive foreground.',
  );
}
