import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

/// Loads artwork with its baked-in neutral checkerboard keyed out in memory.
/// The caller owns the returned sprite's image and must dispose it on removal.
Future<Sprite> loadKeyedArt(
  String assetName, {
  int minimumGray = 135,
  int maximumGray = 255,
  int tolerance = 24,
  bool edgeConnectedOnly = false,
  bool keyWarmGlow = false,
  bool clearEnclosedPatches = true,
  bool cleanSpriteEdges = false,
  List<ui.Offset> backgroundSeeds = const [],
  List<ui.Color> backgroundColors = const [],
  bool cleanNeutralEdges = false,
  int maximumWidth = 1024,
}) async {
  final data = await rootBundle.load('assets/images/$assetName');
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  late final ui.Image source;
  try {
    source = (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
  try {
    final bytes = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bytes == null) throw StateError('Cannot read $assetName pixels');
    final pixels = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    // Preserve replacements that already have a genuine transparent background.
    for (var i = 3; i < pixels.length; i += 4) {
      if (pixels[i] < 255) return Sprite(source.clone());
    }
    // Key at source resolution before resizing. Otherwise checker colors get
    // blended into the sprite edges and leave gray/white rectangular fringes.
    bool isBackground(int pixel) {
      final i = pixel * 4;
      if (pixels[i + 3] == 0) return false;
      if (backgroundColors.isNotEmpty) {
        return backgroundColors.any((color) {
          final rgb = color.toARGB32();
          return (pixels[i] - ((rgb >> 16) & 255)).abs() <= tolerance &&
              (pixels[i + 1] - ((rgb >> 8) & 255)).abs() <= tolerance &&
              (pixels[i + 2] - (rgb & 255)).abs() <= tolerance;
        });
      }
      final low = math.min(pixels[i], math.min(pixels[i + 1], pixels[i + 2]));
      final high = math.max(pixels[i], math.max(pixels[i + 1], pixels[i + 2]));
      final warmChecker =
          keyWarmGlow &&
          low >= minimumGray &&
          high <= 240 &&
          pixels[i + 2] <= pixels[i] + 3 &&
          (pixels[i] - pixels[i + 1]).abs() <= 25 &&
          pixels[i] - pixels[i + 2] <= 100;
      return warmChecker ||
          (low >= minimumGray &&
              high <= maximumGray &&
              high - low <= tolerance);
    }

    void clearPixel(int pixel) {
      final i = pixel * 4;
      pixels[i] = pixels[i + 1] = pixels[i + 2] = pixels[i + 3] = 0;
    }

    if (edgeConnectedOnly) {
      // Preserve enclosed pale details, such as the lion's teeth and eyes.
      final width = source.width;
      final height = source.height;
      final queue = Uint32List(width * height);
      var head = 0;
      var tail = 0;
      void visit(int pixel) {
        if (isBackground(pixel)) {
          clearPixel(pixel);
          queue[tail++] = pixel;
        }
      }

      for (var x = 0; x < width; x++) {
        visit(x);
        visit((height - 1) * width + x);
      }
      for (var y = 0; y < height; y++) {
        visit(y * width);
        visit(y * width + width - 1);
      }
      // Explicit background pockets allow pale clothing to remain untouched.
      for (final seed in backgroundSeeds) {
        visit((seed.dy * height).floor() * width + (seed.dx * width).floor());
      }
      while (head < tail) {
        final pixel = queue[head++];
        final x = pixel % width;
        if (x > 0) visit(pixel - 1);
        if (x + 1 < width) visit(pixel + 1);
        if (pixel >= width) visit(pixel - width);
        if (pixel + width < width * height) visit(pixel + width);
      }
      // Edge-only flood fill misses checkerboard trapped between arms/legs.
      // Clear substantial enclosed patches, preserving tiny eyes and teeth.
      if (clearEnclosedPatches) {
        final visited = Uint8List(width * height);
        final minimumArea = (32 * math.pow(width / 1024, 2)).ceil();
        void collect(int pixel) {
          if (visited[pixel] != 0 || !isBackground(pixel)) return;
          visited[pixel] = 1;
          queue[tail++] = pixel;
        }

        for (var start = 0; start < width * height; start++) {
          if (visited[start] != 0 || !isBackground(start)) continue;
          head = tail = 0;
          collect(start);
          while (head < tail) {
            final pixel = queue[head++];
            final x = pixel % width;
            if (x > 0) collect(pixel - 1);
            if (x + 1 < width) collect(pixel + 1);
            if (pixel >= width) collect(pixel - width);
            if (pixel + width < width * height) collect(pixel + width);
          }
          if (tail >= minimumArea) {
            for (var i = 0; i < tail; i++) {
              clearPixel(queue[i]);
            }
          }
        }
      }
    } else {
      for (var pixel = 0; pixel < source.width * source.height; pixel++) {
        if (isBackground(pixel)) clearPixel(pixel);
      }
    }
    if (cleanSpriteEdges) {
      final width = source.width;
      final count = width * source.height;
      final queue = Uint32List(count);
      final visited = Uint8List(count);
      // Compression and antialiased checkerboard intersections leave isolated
      // flecks. Keep substantial silhouettes, not these tiny opaque islands.
      final minimumArea = (150 * math.pow(width / 1024, 2)).ceil();
      for (var start = 0; start < count; start++) {
        if (visited[start] != 0 || pixels[start * 4 + 3] == 0) continue;
        var head = 0;
        var tail = 0;
        void collect(int pixel) {
          if (visited[pixel] != 0 || pixels[pixel * 4 + 3] == 0) return;
          visited[pixel] = 1;
          queue[tail++] = pixel;
        }

        collect(start);
        while (head < tail) {
          final pixel = queue[head++];
          final x = pixel % width;
          if (x > 0) collect(pixel - 1);
          if (x + 1 < width) collect(pixel + 1);
          if (pixel >= width) collect(pixel - width);
          if (pixel + width < count) collect(pixel + width);
        }
        if (tail < minimumArea) {
          for (var i = 0; i < tail; i++) {
            clearPixel(queue[i]);
          }
        }
      }
      // Strip only pale pixels touching transparency, with a bounded reach.
      // An unrestricted color flood can leak into Jesus' light-colored robe.
      final passes = (1.5 * width / 1024).ceil();
      for (var pass = 0; pass < passes; pass++) {
        var tail = 0;
        for (var pixel = 0; pixel < count; pixel++) {
          final i = pixel * 4;
          if (pixels[i + 3] == 0) continue;
          final low = math.min(
            pixels[i],
            math.min(pixels[i + 1], pixels[i + 2]),
          );
          final high = math.max(
            pixels[i],
            math.max(pixels[i + 1], pixels[i + 2]),
          );
          final neutralFringe =
              cleanNeutralEdges && low >= 30 && high - low <= 18;
          if (!neutralFringe && (low < 135 || high - low > 45)) continue;
          final x = pixel % width;
          if ((x > 0 && pixels[(pixel - 1) * 4 + 3] == 0) ||
              (x + 1 < width && pixels[(pixel + 1) * 4 + 3] == 0) ||
              (pixel >= width && pixels[(pixel - width) * 4 + 3] == 0) ||
              (pixel + width < count && pixels[(pixel + width) * 4 + 3] == 0)) {
            queue[tail++] = pixel;
          }
        }
        for (var i = 0; i < tail; i++) {
          clearPixel(queue[i]);
        }
      }
    }
    final image = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      source.width,
      source.height,
      ui.PixelFormat.rgba8888,
      image.complete,
      targetWidth: math.min(source.width, maximumWidth),
      allowUpscaling: false,
    );
    return Sprite(await image.future);
  } finally {
    source.dispose();
  }
}
