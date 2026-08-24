class SourceInfo {
  final String name;
  final String description;
  final String categoria;

  const SourceInfo({
    required this.name,
    required this.description,
    required this.categoria,
  });

  factory SourceInfo.fromJson(Map<String, dynamic> json) {
    return SourceInfo(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      categoria: json['categoria'] as String? ?? '',
    );
  }
}
