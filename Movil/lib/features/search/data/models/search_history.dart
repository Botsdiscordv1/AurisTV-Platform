class SearchHistoryItem {
  final String query;
  final DateTime timestamp;

  SearchHistoryItem({required this.query, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'query': query,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) => SearchHistoryItem(
        query: json['query'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
