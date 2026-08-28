import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:auris_core/auris_core.dart';

final settingsRepositoryProvider = Provider<AurisRepository>((ref) {
  return ref.watch(aurisRepositoryProvider);
});

final sourcesProvider = FutureProvider<List<SourceInfo>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getSources();
});
