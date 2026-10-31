import 'package:shared_preferences/shared_preferences.dart';

class PlaybackSettings {
  final bool scanOnStartup;
  final bool autoNext;
  final double speed;
  final double volume;
  final bool desktopTvMode;
  final String themeMode; // 'system', 'light', 'oled'

  const PlaybackSettings({
    this.scanOnStartup = true,
    this.autoNext = false,
    this.speed = 1,
    this.volume = 1,
    this.desktopTvMode = false,
    this.themeMode = 'system',
  });

  PlaybackSettings copyWith({
    bool? scanOnStartup,
    bool? autoNext,
    double? speed,
    double? volume,
    bool? desktopTvMode,
    String? themeMode,
  }) => PlaybackSettings(
    scanOnStartup: scanOnStartup ?? this.scanOnStartup,
    autoNext: autoNext ?? this.autoNext,
    speed: speed ?? this.speed,
    volume: volume ?? this.volume,
    desktopTvMode: desktopTvMode ?? this.desktopTvMode,
    themeMode: themeMode ?? this.themeMode,
  );

  static Future<PlaybackSettings> read(SharedPreferencesAsync prefs) async =>
      fromValues(await prefs.getAll());

  static PlaybackSettings fromValues(Map<String, Object?> values) {
    final speedValue = values['speed'];
    final volumeValue = values['volume'];
    final themeValue = values['theme_mode'];
    return PlaybackSettings(
      scanOnStartup: values['scan_on_startup'] is bool
          ? values['scan_on_startup'] as bool
          : true,
      autoNext: values['auto_next'] == true,
      speed:
          speedValue is num &&
              [0.75, 1.0, 1.25, 1.5, 2.0].contains(speedValue.toDouble())
          ? speedValue.toDouble()
          : 1,
      volume: volumeValue is num && volumeValue.isFinite
          ? volumeValue.clamp(0, 1).toDouble()
          : 1,
      desktopTvMode: values['desktop_tv_mode'] == true,
      themeMode: (themeValue == 'light' || themeValue == 'oled' || themeValue == 'system')
          ? themeValue as String
          : 'system',
    );
  }

  Future<void> save(
    SharedPreferencesAsync prefs, {
    PlaybackSettings? previous,
  }) async {
    if (previous?.scanOnStartup != scanOnStartup)
      await prefs.setBool('scan_on_startup', scanOnStartup);
    if (previous?.autoNext != autoNext)
      await prefs.setBool('auto_next', autoNext);
    if (previous?.speed != speed) await prefs.setDouble('speed', speed);
    if (previous?.volume != volume) await prefs.setDouble('volume', volume);
    if (previous?.desktopTvMode != desktopTvMode)
      await prefs.setBool('desktop_tv_mode', desktopTvMode);
    if (previous?.themeMode != themeMode)
      await prefs.setString('theme_mode', themeMode);
  }
}
