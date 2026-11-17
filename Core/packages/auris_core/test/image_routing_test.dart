import 'package:auris_core/core/api/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tmdb urls bypass weserv and go direct', () {
    final out = ApiEndpoints.proxyImage('https://image.tmdb.org/t/p/w500/abc.jpg');
    expect(out, 'https://image.tmdb.org/t/p/w500/abc.jpg');
    expect(out.contains('weserv.nl'), false);
  });

  test('tmdb urls adapt bucket to targetWidth', () {
    final out = ApiEndpoints.proxyImage('https://image.tmdb.org/t/p/w500/abc.jpg', width: 300);
    expect(out, 'https://image.tmdb.org/t/p/w300/abc.jpg');
  });

  test('weserv urls carry proxy errorredirect by default', () {
    final out = ApiEndpoints.proxyImage('https://cdn.jkanime.net/assets/images/animes/image/abc.jpg');
    expect(out.contains('images.weserv.nl'), true);
    expect(out.contains('errorredirect='), true);
    expect(out.contains(Uri.encodeComponent('api/proxy/image')), true);
  });

  test('explicit fallbackUrl wins over proxy default', () {
    final out = ApiEndpoints.proxyImage('https://cdn.animeav1.com/s/1.jpg',
        fallbackUrl: 'https://image.tmdb.org/t/p/w500/abc.jpg');
    expect(out.contains(Uri.encodeComponent('https://image.tmdb.org/t/p/w500/abc.jpg')), true);
    expect(out.contains('api/proxy/image'), false);
  });

  test('nested proxy url from backend is preserved directly without weserv', () {
    const input = 'https://anime.auristv.dpdns.org/api/proxy/image?url=https%3A%2F%2Fcdn.animeav1.com%2Fs%2F1.jpg';
    final out = ApiEndpoints.proxyImage(input);
    expect(out, input);
    expect(out.contains('weserv.nl'), false);
  });
}
