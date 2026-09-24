import 'dart:convert';

import 'package:storypad/core/objects/sp_latlng.dart';
import 'package:storypad/core/services/logger/app_logger.dart';
import 'package:http/http.dart' as http;

/// A snapshot of current weather conditions, decoded from an Open-Meteo
/// `current` response.
class WeatherInfoObject {
  final double temperatureCelsius;
  final int weatherCode;
  final bool isDay;

  const WeatherInfoObject({
    required this.temperatureCelsius,
    required this.weatherCode,
    required this.isDay,
  });

  factory WeatherInfoObject.fromJsonResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('unexpected response');

    final current = decoded['current'];
    if (current is! Map<String, dynamic>) throw const FormatException('missing current block');

    final temperature = (current['temperature_2m'] as num?)?.toDouble();
    final code = current['weather_code'] as int?;
    final isDay = current['is_day'] as int?;
    if (temperature == null || code == null || isDay == null) {
      throw const FormatException('missing current fields');
    }

    return WeatherInfoObject(temperatureCelsius: temperature, weatherCode: code, isDay: isDay != 0);
  }

  /// WMO weather interpretation codes (WW) mapped to an emoji + full
  /// translation key (literal strings, so the unused-translations test can
  /// trace them).
  static const Map<int, (String, String)> _codeInfo = {
    0: ('☀️', 'weather.condition.clear_sky'),
    1: ('🌤️', 'weather.condition.mainly_clear'),
    2: ('⛅', 'weather.condition.partly_cloudy'),
    3: ('☁️', 'weather.condition.overcast'),
    45: ('🌫️', 'weather.condition.fog'),
    48: ('🌫️', 'weather.condition.depositing_rime_fog'),
    51: ('🌦️', 'weather.condition.light_drizzle'),
    53: ('🌦️', 'weather.condition.moderate_drizzle'),
    55: ('🌦️', 'weather.condition.dense_drizzle'),
    56: ('🌧️', 'weather.condition.light_freezing_drizzle'),
    57: ('🌧️', 'weather.condition.dense_freezing_drizzle'),
    61: ('🌧️', 'weather.condition.slight_rain'),
    63: ('🌧️', 'weather.condition.moderate_rain'),
    65: ('🌧️', 'weather.condition.heavy_rain'),
    66: ('🌧️', 'weather.condition.light_freezing_rain'),
    67: ('🌧️', 'weather.condition.heavy_freezing_rain'),
    71: ('🌨️', 'weather.condition.slight_snowfall'),
    73: ('🌨️', 'weather.condition.moderate_snowfall'),
    75: ('❄️', 'weather.condition.heavy_snowfall'),
    77: ('🌨️', 'weather.condition.snow_grains'),
    80: ('🌦️', 'weather.condition.slight_rain_showers'),
    81: ('🌦️', 'weather.condition.moderate_rain_showers'),
    82: ('⛈️', 'weather.condition.violent_rain_showers'),
    85: ('🌨️', 'weather.condition.slight_snow_showers'),
    86: ('❄️', 'weather.condition.heavy_snow_showers'),
    95: ('⛈️', 'weather.condition.thunderstorm'),
    96: ('⛈️', 'weather.condition.thunderstorm_with_slight_hail'),
    99: ('⛈️', 'weather.condition.thunderstorm_with_heavy_hail'),
  };

  String get emoji => _codeInfo[weatherCode]?.$1 ?? '🌡️';

  /// Full translation key for the condition (e.g.
  /// `weather.condition.clear_sky`), or null for codes outside the WMO table.
  String? get conditionKeyOrNull => _codeInfo[weatherCode]?.$2;

  /// One-line, human-readable summary suitable for prepending to an entry,
  /// e.g. "⛅ 22°C — Partly cloudy". Falls back to emoji + temperature only
  /// when the weather code has no known condition label.
  String displayLine({required String localizedCondition}) {
    final rounded = temperatureCelsius.round();
    if (localizedCondition.isEmpty) return '$emoji $rounded°C';
    return '$emoji $rounded°C — $localizedCondition';
  }
}

/// Fetches current weather from Open-Meteo (https://open-meteo.com).
///
/// Open-Meteo needs no API key, so this works in the community flavor and is
/// F-Droid-safe. Everything here is best-effort: any failure (offline,
/// timeout, unexpected payload) returns `null` and the caller silently skips
/// attaching weather — story creation must never stall on the network.
class OpenMeteoWeatherService {
  const OpenMeteoWeatherService._();

  /// Max wait for the weather request. Offline/roaming must never stall
  /// story creation.
  static const Duration requestTimeout = Duration(seconds: 5);

  static const String _currentFields = 'temperature_2m,weather_code,is_day';

  /// Returns the current weather at [latLng], or `null` when unavailable.
  static Future<WeatherInfoObject?> fetchCurrentWeather(SpLatLng latLng) async {
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'current': _currentFields,
        'timezone': 'auto',
        'latitude': latLng.latitude.toStringAsFixed(4),
        'longitude': latLng.longitude.toStringAsFixed(4),
      });

      final response = await http.get(uri).timeout(requestTimeout);
      if (response.statusCode != 200) return null;

      return WeatherInfoObject.fromJsonResponse(response.body);
    } catch (e) {
      AppLogger.d('OpenMeteoWeatherService: fetch failed (offline-graceful): $e');
      return null;
    }
  }
}
