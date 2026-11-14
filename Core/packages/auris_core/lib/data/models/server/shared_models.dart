import '../../../core/api/api_endpoints.dart';

/// Un elemento navegable: nombre para mostrar + URL opcional de la fuente.
/// Cuando [url] es null el consumidor puede hacer un search por [name].
class NavigableItem {
  final String name;
  final String? url;

  const NavigableItem({required this.name, this.url});

  /// Parsea desde JSON. Acepta:
  ///   - String plain   → NavigableItem(name: s, url: null)
  ///   - {"name":"…"}  → NavigableItem(name: n, url: null)
  ///   - {"name":"…","url":"…"} → NavigableItem(name: n, url: u)
  factory NavigableItem.fromJson(dynamic json) {
    if (json is String) return NavigableItem(name: json);
    if (json is Map) {
      final name = (json['name'] ?? '').toString().trim();
      final url  = json['url'] as String?;
      return NavigableItem(name: name, url: url?.isNotEmpty == true ? url : null);
    }
    return NavigableItem(name: json.toString());
  }

  Map<String, dynamic> toJson() => {'name': name, if (url != null) 'url': url};

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is NavigableItem && other.name.toLowerCase() == name.toLowerCase());

  @override
  int get hashCode => name.toLowerCase().hashCode;
}

class PlatformInfo {
  final String providerName;
  final String? logo;

  const PlatformInfo({required this.providerName, this.logo});

  factory PlatformInfo.fromJson(Map<String, dynamic> json) {
    return PlatformInfo(
      providerName: json['providerName'] as String? ?? '',
      logo: ApiEndpoints.proxyImage(json['logo'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'providerName': providerName,
    'logo': logo,
  };
}
