class ContentType {
  ContentType.parse(String header) {
    final chunks = header.split(';').map((String e) => e.trim().toLowerCase());

    for (final chunk in chunks) {
      if (!chunk.contains('=')) {
        _mimeType = chunk;
      } else {
        final bits = chunk.split('=').map((String e) => e.trim()).toList();
        assert(bits.length == 2);
        switch (bits.first) {
          case 'charset':
            _charset = bits[1];
            break;
          case 'boundary':
            _boundary = bits[1];
            break;
          default:
            throw StateError('Unable to parse "$chunk" in content-type.');
        }
      }
    }
  }

  String? _mimeType;
  String? _charset;
  String? _boundary;

  String? get mimeType => _mimeType;
  String? get charset => _charset;
  String? get boundary => _boundary;
}
