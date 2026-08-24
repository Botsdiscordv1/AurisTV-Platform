import 'package:auris_core/auris_core.dart';

/// Datos de ejemplo — reemplazar por datasources/repositories reales.
class MockData {
  MockData._();

  static final List<MediaItem> continueWatching = [
    const MediaItem(
      id: '1',
      title: 'Frieren',
      posterUrl: 'https://picsum.photos/seed/frieren/300/450',
      type: MediaType.anime,
    ),
    const MediaItem(
      id: '2',
      title: 'Crash Landing on You',
      posterUrl: 'https://picsum.photos/seed/clou/300/450',
      type: MediaType.kdrama,
    ),
  ];

  static final List<MediaItem> anime = [
    const MediaItem(
      id: '3',
      title: 'Jujutsu Kaisen',
      posterUrl: 'https://picsum.photos/seed/jjk/600/337',
      type: MediaType.anime,
    ),
    const MediaItem(
      id: '4',
      title: 'Vinland Saga',
      posterUrl: 'https://picsum.photos/seed/vinland/600/337',
      type: MediaType.anime,
    ),
    const MediaItem(
      id: '5',
      title: 'Kaiju No. 8',
      posterUrl: 'https://picsum.photos/seed/kaiju/600/337',
      type: MediaType.anime,
    ),
  ];

  static final List<MediaItem> kdramas = [
    const MediaItem(
      id: '6',
      title: 'Reply 1988',
      posterUrl: 'https://picsum.photos/seed/reply1988/600/337',
      type: MediaType.kdrama,
    ),
    const MediaItem(
      id: '7',
      title: 'Hospital Playlist',
      posterUrl: 'https://picsum.photos/seed/hospital/600/337',
      type: MediaType.kdrama,
    ),
  ];

  static final List<MediaItem> movies = [
    const MediaItem(
      id: 'm1',
      title: 'Suzume',
      posterUrl: 'https://picsum.photos/seed/suzume/600/337',
      type: MediaType.movie,
    ),
    const MediaItem(
      id: 'm2',
      title: 'Your Name',
      posterUrl: 'https://picsum.photos/seed/yourname/600/337',
      type: MediaType.movie,
    ),
  ];

  static List<MediaItem> get featuredItems => [
    const MediaItem(
      id: 'feat_0',
      title: 'Proyecto Fin del Mundo',
      posterUrl: 'https://picsum.photos/seed/feat_0/1280/720',
      bannerUrl: 'https://picsum.photos/seed/banner_0/1280/720',
      trailerKey: null,
      type: MediaType.anime,
      synopsis: 'Esta es la sinopsis del contenido destacado número 1.',
    ),
    const MediaItem(
      id: 'feat_1',
      title: 'Frieren: Beyond Journey\'s End',
      posterUrl: 'https://picsum.photos/seed/feat_1/1280/720',
      bannerUrl: 'https://picsum.photos/seed/banner_1/1280/720',
      trailerKey: 'qgQvCq06t8Y',
      type: MediaType.anime,
      synopsis: 'The journey is over, but the memories remain.',
    ),
    const MediaItem(
      id: 'feat_2',
      title: 'Jujutsu Kaisen Season 2',
      posterUrl: 'https://picsum.photos/seed/feat_2/1280/720',
      bannerUrl: 'https://picsum.photos/seed/banner_2/1280/720',
      trailerKey: 'O6qVod2G_Z4',
      type: MediaType.anime,
      synopsis: 'Cursed energy is rising.',
    ),
  ];

  static MediaItem get featured => featuredItems.first;
}
