import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class MaterializeMask extends StatelessWidget {
  final double progress;
  final double time;
  final Widget child;

  const MaterializeMask({
    super.key,
    required this.progress,
    required this.child,
    this.time = 0,
  });

  static final Future<ui.FragmentProgram> _program = ui.FragmentProgram.fromAsset(
    'shaders/materialize.frag',
  );

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);

    return FutureBuilder<ui.FragmentProgram>(
      future: _program,
      builder: (context, snapshot) {
        final program = snapshot.data;
        if (program == null) {
          // Fallback (e.g. while shader is loading).
          return Opacity(opacity: p, child: child);
        }

        return ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (bounds) {
            final shader = program.fragmentShader();
            shader.setFloat(0, bounds.width);
            shader.setFloat(1, bounds.height);
            shader.setFloat(2, p);
            shader.setFloat(3, time);
            return shader;
          },
          child: child,
        );
      },
    );
  }
}
