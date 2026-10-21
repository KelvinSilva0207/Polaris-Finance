import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;

/// Resultado de una verificación de actualizaciones.
enum UpdateStatus { upToDate, updateAvailable, error }

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.status,
    this.releaseNotes,
    this.downloadUrl,
    this.publishedAt,
    this.error,
  });

  final String currentVersion;
  final String latestVersion;
  final UpdateStatus status;
  final String? releaseNotes;
  final String? downloadUrl;
  final DateTime? publishedAt;
  final String? error;

  bool get hasUpdate => status == UpdateStatus.updateAvailable;

  UpdateInfo copyWith({
    String? currentVersion,
    String? latestVersion,
    UpdateStatus? status,
    String? releaseNotes,
    String? downloadUrl,
    DateTime? publishedAt,
    String? error,
  }) {
    return UpdateInfo(
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      status: status ?? this.status,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      error: error ?? this.error,
    );
  }
}

class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _timeout = Duration(seconds: 15);

/// Extrae la parte numérica de un tag de versión (`v1.2.3`, `1.2.3+build`).
/// Devuelve null si no hay nada comparable.
List<int>? parseVersion(String? raw) {
  if (raw == null) return null;
  final match = RegExp(r'(\d+(?:\.\d+)*)').firstMatch(raw.trim());
  if (match == null) return null;
  final parts = match
      .group(1)!
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList();
  return parts.isEmpty ? null : parts;
}

/// Compara dos versiones de forma semántica. Ignora el sufijo de build
/// (`+N`). Devuelve negativo si [a] < [b], 0 si son iguales y positivo si
/// [a] > [b].
int compareVersions(String a, String b) {
  final left = parseVersion(a) ?? const [0];
  final right = parseVersion(b) ?? const [0];
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

/// Version publicada que el CI escribe junto a cada release (fuente primaria,
/// ya que el tag de GitHub es literalmente `latest`).
/// Ej: `{"version": "1.0.2", "notes": "...", "published_at": "..."}`.
class _VersionManifest {
  const _VersionManifest({
    required this.version,
    this.notes,
    this.downloadUrl,
    this.publishedAt,
  });

  final String version;
  final String? notes;
  final String? downloadUrl;
  final DateTime? publishedAt;
}

class UpdateService {
  UpdateService({
    required String owner,
    required String repo,
    http.Client? client,
    Future<String> Function()? currentVersionLoader,
    Future<bool> Function(Uri)? launcherFn,
    String? manifestBaseUrl,
  }) : _owner = owner,
       _repo = repo,
       _client = client ?? http.Client(),
       _currentVersionLoader = currentVersionLoader ?? _defaultCurrentVersion,
       _launcherFn = launcherFn ?? _defaultLauncher,
       _manifestBaseUrl =
           manifestBaseUrl ??
           'https://raw.githubusercontent.com/$owner/$repo/main';

  final String _owner;
  final String _repo;
  final http.Client _client;
  final Future<String> Function() _currentVersionLoader;
  final Future<bool> Function(Uri) _launcherFn;
  final String _manifestBaseUrl;

  static Future<String> _defaultCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  static Future<bool> _defaultLauncher(Uri uri) {
    return launcher.launchUrl(
      uri,
      mode: launcher.LaunchMode.externalApplication,
    );
  }

  /// Consulta la versión publicada: prioriza el manifiesto `version.json`
  /// generado por el CI y cae a la API de GitHub Releases como respaldo.
  Future<UpdateInfo> check() async {
    final current = await _currentVersionLoader();
    try {
      final release = await _fetchLatestRelease();
      if (release == null) {
        return UpdateInfo(
          currentVersion: current,
          latestVersion: current,
          status: UpdateStatus.error,
          error: 'Sin información de versiones publicadas.',
        );
      }
      final status = compareVersions(release.version, current) > 0
          ? UpdateStatus.updateAvailable
          : UpdateStatus.upToDate;
      return UpdateInfo(
        currentVersion: current,
        latestVersion: release.version,
        status: status,
        releaseNotes: release.notes,
        downloadUrl: release.downloadUrl,
        publishedAt: release.publishedAt,
      );
    } on UpdateCheckException catch (error) {
      return UpdateInfo(
        currentVersion: current,
        latestVersion: current,
        status: UpdateStatus.error,
        error: error.message,
      );
    } catch (error) {
      return UpdateInfo(
        currentVersion: current,
        latestVersion: current,
        status: UpdateStatus.error,
        error: 'Error de red: $error',
      );
    }
  }

  Future<_VersionManifest?> _fetchLatestRelease() async {
    final fromManifest = await _tryManifest();
    if (fromManifest != null) return fromManifest;
    return _tryGitHubApi();
  }

  Future<_VersionManifest?> _tryManifest() async {
    final uri = Uri.parse('$_manifestBaseUrl/version.json');
    final http.Response res;
    try {
      res = await _client.get(uri).timeout(_timeout);
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;
    try {
      final json = jsonDecode(res.body);
      if (json is! Map<String, dynamic>) return null;
      final version = json['version']?.toString();
      if (version == null || version.isEmpty) return null;
      final published = json['published_at']?.toString();
      return _VersionManifest(
        version: version,
        notes: json['notes']?.toString(),
        downloadUrl: json['download_url']?.toString() ?? _apkUrl(),
        publishedAt: published == null ? null : DateTime.tryParse(published),
      );
    } catch (_) {
      return null;
    }
  }

  Future<_VersionManifest?> _tryGitHubApi() async {
    final uri = Uri.parse(
      'https://api.github.com/repos/$_owner/$_repo/releases/latest',
    );
    final res = await _client
        .get(
          uri,
          headers: const {
            'accept': 'application/vnd.github+json',
            'user-agent': 'PolarisFinance-Updater',
          },
        )
        .timeout(_timeout);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw UpdateCheckException('GitHub: HTTP ${res.statusCode}');
    }
    final json = jsonDecode(res.body);
    if (json is! Map<String, dynamic>) return null;

    var version = json['tag_name']?.toString();
    if (version == null || version.isEmpty || parseVersion(version) == null) {
      version = await _tagVersionForRelease(json);
    }
    if (version == null || parseVersion(version) == null) return null;

    final published = json['published_at']?.toString();
    return _VersionManifest(
      version: version,
      notes: json['body']?.toString(),
      downloadUrl: _apkUrlFromAssets(json['assets']) ?? _apkUrl(),
      publishedAt: published == null ? null : DateTime.tryParse(published),
    );
  }

  /// El release `latest` tiene un tag sin número, así que buscamos el tag con
  /// versión semántica más reciente entre los `tags` del repo.
  Future<String?> _tagVersionForRelease(Map<String, dynamic> release) async {
    final uri = Uri.parse('https://api.github.com/repos/$_owner/$_repo/tags');
    final http.Response res;
    try {
      res = await _client
          .get(
            uri,
            headers: const {
              'accept': 'application/vnd.github+json',
              'user-agent': 'PolarisFinance-Updater',
            },
          )
          .timeout(_timeout);
    } catch (_) {
      return null;
    }
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body);
    if (json is! List) return null;
    final versions = <String>[
      for (final tag in json)
        if (tag is Map<String, dynamic>)
          if (tag['name']?.toString() case final String name
              when parseVersion(name) != null)
            name,
    ];
    if (versions.isEmpty) return null;
    versions.sort((a, b) => compareVersions(b, a));
    return versions.first;
  }

  String? _apkUrlFromAssets(Object? assets) {
    if (assets is! List) return null;
    for (final asset in assets) {
      if (asset is Map<String, dynamic> &&
          asset['browser_download_url']?.toString().endsWith('.apk') == true) {
        return asset['browser_download_url'].toString();
      }
    }
    return null;
  }

  String _apkUrl() =>
      'https://github.com/$_owner/$_repo/releases/download/latest/polaris-finance.apk';

  /// Abre el enlace de descarga del APK en el navegador o gestor de descargas
  /// del sistema. Devuelve `true` si se pudo abrir.
  Future<bool> openDownload(String? url) async {
    final target = url ?? _apkUrl();
    final uri = Uri.tryParse(target);
    if (uri == null) return false;
    return _launcherFn(uri);
  }

  /// Abre la página de releases en el navegador.
  Future<bool> openReleasePage() {
    return _launcherFn(
      Uri.parse('https://github.com/$_owner/$_repo/releases/latest'),
    );
  }
}

const updateRepoOwner = 'KelvinSilva0207';
const updateRepoName = 'Polaris-Finance';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(owner: updateRepoOwner, repo: updateRepoName);
});

/// Resultado de la última verificación silenciosa (banner del dashboard).
/// `null` mientras nunca se ha comprobado o si el resultado fue "al día".
class UpdateController extends Notifier<UpdateInfo?> {
  @override
  UpdateInfo? build() => null;

  Future<UpdateInfo> check() async {
    final info = await ref.read(updateServiceProvider).check();
    state = info.hasUpdate ? info : null;
    return info;
  }
}

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateInfo?>(UpdateController.new);
