import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bakaloo_flutter_app/core/theme/remote_theme_model.dart';
import 'package:bakaloo_flutter_app/core/theme/remote_theme_provider.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_model.dart';
import 'package:bakaloo_flutter_app/core/theme/section_manifest_provider.dart';
import 'package:bakaloo_flutter_app/features/home/presentation/widgets/section_registry.dart';

class DynamicHomeSections extends ConsumerWidget {
  const DynamicHomeSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manifest = ref.watch(activeSectionManifestProvider);
    final theme = ref.watch(activeTabThemeProvider);

    if (manifest.sections.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          final SectionManifestEntry entry = manifest.sections[index];
          return _DynamicSectionSlot(
            entry: entry,
            theme: theme,
          );
        },
        childCount: manifest.sections.length,
      ),
    );
  }
}

class _DynamicSectionSlot extends ConsumerWidget {
  const _DynamicSectionSlot({
    required this.entry,
    required this.theme,
  });

  final SectionManifestEntry entry;
  final RemoteTheme theme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!entry.visible) {
      return const SizedBox.shrink();
    }

    final builder = sectionRegistry[entry.type];
    if (builder == null) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: builder(entry, theme, ref),
    );
  }
}

