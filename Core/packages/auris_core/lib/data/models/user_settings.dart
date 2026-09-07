import 'package:flutter/material.dart';

class UserSettings {
  final String preferredQuality;
  final String preferredLanguage;
  final bool autoPlayTrailers;
  final bool autoPlayNextEpisode;
  final bool showAiringCountdown;
  final double subtitleSize;
  final int subtitleColor;
  final bool externalSyncEnabled;

  const UserSettings({
    this.preferredQuality = 'auto',
    this.preferredLanguage = 'latino',
    this.autoPlayTrailers = true,
    this.autoPlayNextEpisode = true,
    this.showAiringCountdown = true,
    this.subtitleSize = 1.0,
    this.subtitleColor = 0xFFFFFFFF,
    this.externalSyncEnabled = false,
  });

  UserSettings copyWith({
    String? preferredQuality,
    String? preferredLanguage,
    bool? autoPlayTrailers,
    bool? autoPlayNextEpisode,
    bool? showAiringCountdown,
    double? subtitleSize,
    int? subtitleColor,
    bool? externalSyncEnabled,
  }) {
    return UserSettings(
      preferredQuality: preferredQuality ?? this.preferredQuality,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      autoPlayTrailers: autoPlayTrailers ?? this.autoPlayTrailers,
      autoPlayNextEpisode: autoPlayNextEpisode ?? this.autoPlayNextEpisode,
      showAiringCountdown: showAiringCountdown ?? this.showAiringCountdown,
      subtitleSize: subtitleSize ?? this.subtitleSize,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      externalSyncEnabled: externalSyncEnabled ?? this.externalSyncEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredQuality': preferredQuality,
      'preferredLanguage': preferredLanguage,
      'autoPlayTrailers': autoPlayTrailers,
      'autoPlayNextEpisode': autoPlayNextEpisode,
      'showAiringCountdown': showAiringCountdown,
      'subtitleSize': subtitleSize,
      'subtitleColor': subtitleColor,
      'externalSyncEnabled': externalSyncEnabled,
    };
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      preferredQuality: json['preferredQuality'] ?? 'auto',
      preferredLanguage: json['preferredLanguage'] ?? 'latino',
      autoPlayTrailers: json['autoPlayTrailers'] ?? true,
      autoPlayNextEpisode: json['autoPlayNextEpisode'] ?? true,
      showAiringCountdown: json['showAiringCountdown'] ?? true,
      subtitleSize: (json['subtitleSize'] as num?)?.toDouble() ?? 1.0,
      subtitleColor: json['subtitleColor'] ?? 0xFFFFFFFF,
      externalSyncEnabled: json['externalSyncEnabled'] ?? false,
    );
  }
}
