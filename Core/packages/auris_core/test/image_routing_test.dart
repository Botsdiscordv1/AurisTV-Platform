import 'package:auris_core/core/api/api_endpoints.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('weserv urls carry proxy errorredirect by default', () {
    final out = ApiEndpoints.proxyImage('https://image.tmdb.org/t/p/w500/abc.jpg');
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

  test('nested proxy url unwraps without double-proxy', () {
    final out = ApiEndpoints.proxyImage(
        'https://anime.auristv.dpdns.org/api/proxy/image?url=https%3A%2F%2Fcdn.animeav1.com%2Fs%2F1.jpg');
    expect(out.contains('images.weserv.nl'), true);
    // Sin URL anidada literal (el 'url=https' del query de weserv no cuenta).
    expect(out.contains('/api/proxy/image?url=http'), false);
    final err = Uri.parse(out).queryParameters['errorredirect'] ?? '';
    expect(err.contains('/api/proxy/image?url='), true);
    expect(err.contains('weserv'), false);
  });
}
