import '../../../core/api/api_endpoints.dart';

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
