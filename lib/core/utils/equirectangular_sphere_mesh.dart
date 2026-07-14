import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cube/flutter_cube.dart';

/// Inverted sphere mesh for equirectangular 360° panorama rendering.
Mesh buildEquirectangularSphereMesh({
  num radius = 500,
  int latSegments = 32,
  int lonSegments = 64,
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
    final v = y / latSegments;
    final sv = math.sin(v * math.pi);
    final cv = math.cos(v * math.pi);
    for (var x = 0; x <= lonSegments; ++x) {
      final u = x / lonSegments;
      vertices[i] = Vector3(
        radius * math.cos(u * math.pi * 2.0) * sv,
        radius * cv,
        radius * math.sin(u * math.pi * 2.0) * sv,
      );
      texcoords[i] = Offset(1.0 - u, 1.0 - v);
      i++;
    }
  }

  i = 0;
  for (var y = 0; y < latSegments; ++y) {
    final base1 = (lonSegments + 1) * y;
    final base2 = (lonSegments + 1) * (y + 1);
    for (var x = 0; x < lonSegments; ++x) {
      indices[i++] = Polygon(base1 + x, base1 + x + 1, base2 + x);
      indices[i++] = Polygon(base1 + x + 1, base2 + x + 1, base2 + x);
    }
  }

  return Mesh(
    vertices: vertices,
    texcoords: texcoords,
    indices: indices,
    texture: texture,
  );
}
