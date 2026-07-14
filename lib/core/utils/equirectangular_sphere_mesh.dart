import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';

/// Inverted-sphere mesh for equirectangular 360° panorama (camera at center).
///
/// UV layout matches [panorama_viewer] so the full 2:1 frame wraps 360°
/// horizontally. Triangle winding is reversed for consistent interior rendering
/// on both Android (GLES) and iOS (Metal).
Mesh buildEquirectangularSphereMesh({
  num radius = 500,
  int latSegments = 32,
  int lonSegments = 128,
  ui.Image? texture,
}) {
  final count = (latSegments + 1) * (lonSegments + 1);
  final vertices = List<Vector3>.filled(count, Vector3.zero());
  final texcoords = List<Offset>.filled(count, Offset.zero);
  final indices = List<Polygon>.filled(
    latSegments * lonSegments * 2,
    Polygon(0, 0, 0),
  );

  var i = 0;
  for (var y = 0; y <= latSegments; ++y) {
    final tv = y / latSegments;
    final sv = math.sin(tv * math.pi);
    final cv = math.cos(tv * math.pi);
    for (var x = 0; x <= lonSegments; ++x) {
      final tu = x / lonSegments;
      final theta = tu * math.pi * 2.0;
      vertices[i] = Vector3(
        radius * math.cos(theta) * sv,
        radius * cv,
        radius * math.sin(theta) * sv,
      );
      texcoords[i] = Offset(tu, 1.0 - tv);
      i++;
    }
  }

  i = 0;
  for (var y = 0; y < latSegments; ++y) {
    final base1 = (lonSegments + 1) * y;
    final base2 = (lonSegments + 1) * (y + 1);
    for (var x = 0; x < lonSegments; ++x) {
      // Reversed winding — visible when camera is inside the sphere.
      indices[i++] = Polygon(base1 + x, base2 + x, base1 + x + 1);
      indices[i++] = Polygon(base1 + x + 1, base2 + x, base2 + x + 1);
    }
  }

  return Mesh(
    vertices: vertices,
    texcoords: texcoords,
    indices: indices,
    texture: texture,
  );
}
