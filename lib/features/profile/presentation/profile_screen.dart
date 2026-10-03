import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../core/config/dev_features.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/updater/github_updater.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';
import '../../../domain/transport_profiles.dart';
import 'profile_overview.dart';
import 'screen_settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.embedded = false, this.section});
  final bool embedded;
  final ProfileSection? section;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String version = '…';
  bool checking = false;
  bool saving = false;
  bool requestedProfile = false;
  double? progress;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => version = info.version);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (requestedProfile) {
      return;
    }
    requestedProfile = true;
    final state = AppScope.of(context);
    if (state.profile == null && state.auth.signedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await state.refreshProfile();
        } catch (_) {
          // Cached profile is shown when the network is unavailable.
        }
      });
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => checking = true);
    try {
      final updater = GithubUpdater();
      final info = await updater.check();
      if (!mounted) {
        return;
      }
      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Du har siste versjon.')));
        return;
      }
      final install = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(info.name),
          content: SingleChildScrollView(
            child: Text(info.notes.isEmpty ? 'Ny versjon ${info.version} er tilgjengelig.' : info.notes),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Senere')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Last ned')),
          ],
        ),
      );
      if (install == true) {
        final file = await updater.download(info, onProgress: (value) {
          if (mounted) {
            setState(() => progress = value);
          }
        });
        await updater.install(file);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Oppdatering feilet: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          checking = false;
          progress = null;
        });
      }
    }
  }

  Future<void> _editProfile(UserProfile profile) async {
    final state = AppScope.of(context);
    final name = TextEditingController(text: profile.displayName);
    final location = TextEditingController(text: profile.location);
    final bio = TextEditingController(text: profile.bio);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rediger profil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Navn')),
              const SizedBox(height: 12),
              TextField(controller: location, decoration: const InputDecoration(labelText: 'Område / hjemsted')),
              const SizedBox(height: 12),
              TextField(
                controller: bio,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Kort bio'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Lagre')),
        ],
      ),
    );
    if (save != true) {
      return;
    }
    await _runSave(() => state.updateProfile(displayName: name.text, location: location.text, bio: bio.text));
  }

  Future<void> _changeAvatar() async {
    final state = AppScope.of(context);
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600);
    if (image == null) {
      return;
    }
    final extension = image.path.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    await _runSave(() async {
      await state.uploadProfileAvatar(bytes: await image.readAsBytes(), extension: extension, contentType: contentType);
    });
  }

  Future<void> _selectTransport(UserProfile profile) async {
    final state = AppScope.of(context);
    final value = await showModalBottomSheet<StageTransport>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Foretrukket transport', style: TextStyle(fontWeight: FontWeight.w900))),
            for (final transport in primaryTripTransports)
              ListTile(
                onTap: () => Navigator.pop(context, transport),
                title: Text(transportLabel(transport)),
                trailing: transport == profile.preferredTransport ? const Icon(Icons.check_circle, color: GoViaColors.orange) : null,
              ),
          ],
        ),
      ),
    );
    if (value != null && value != profile.preferredTransport) {
      await _runSave(() => state.updateProfile(preferredTransport: value));
    }
  }

  Future<void> _selectUnits(UserProfile profile) async {
    final value = await _choose<String>(
      title: 'Enheter',
      current: profile.unitSystem,
      options: const {'metric': 'Metrisk (km, m)', 'imperial': 'Imperial (mi, ft)'},
    );
    if (value != null && value != profile.unitSystem) {
      await _runSave(() => AppScope.of(context).updateProfile(unitSystem: value));
    }
  }



  Future<void> _selectNavigationLanguage() async {
    final state = AppScope.of(context);
    final value = await _choose<String>(
      title: 'Navigasjonsspråk',
      current: state.navigationLanguage,
      options: const {
        'auto': 'Automatisk',
        'nb': 'Norsk',
        'en': 'English',
      },
    );
    if (value != null && value != state.navigationLanguage) {
      await _runSave(() => state.setNavigationLanguage(value));
    }
  }

  String _navigationLanguageLabel(String value) => switch (value) {
        'nb' => 'Norsk',
        'en' => 'English',
        _ => 'Automatisk',
      };

  Future<void> _selectAppTheme() async {
    final state = AppScope.of(context);
    final value = await _choose<String>(title: 'Mobiltema', current: state.appThemeMode,
      options: const {'system': 'Automatisk', 'light': 'Lys', 'dark': 'Mørk'});
    if (value != null) {
      await _runSave(() => state.setAppThemeMode(value));
    }
  }

  Future<void> _selectAndroidAutoTheme() async {
    final state = AppScope.of(context);
    final value = await _choose<String>(
      title: 'Bilskjermtema · Android Auto',
      current: state.androidAutoThemeMode,
      options: const {
        'system': 'Automatisk',
        'light': 'Lys',
        'dark': 'Mørk',
      },
    );
    if (value != null && value != state.androidAutoThemeMode) {
      await _runSave(() => state.setAndroidAutoThemeMode(value));
    }
  }

  String _androidAutoThemeLabel(String value) => switch (value) {
        'light' => 'Lys',
        'dark' => 'Mørk',
        _ => 'Automatisk',
      };

  Future<void> _selectLocationSharing(UserProfile profile) async {
    final value = await _choose<String>(
      title: 'Posisjonsdeling',
      current: profile.locationSharing,
      options: const {
        'off': 'Av',
        'active_trip': 'Kun under aktiv tur',
        'group_trip': 'Kun med deltakere på turen',
      },
    );
    if (value != null && value != profile.locationSharing) {
      await _runSave(() => AppScope.of(context).updateProfile(locationSharing: value));
    }
  }

  Future<T?> _choose<T>({required String title, required T current, required Map<T, String> options}) =>
      showModalBottomSheet<T>(
        context: context,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              for (final entry in options.entries)
                ListTile(
                  onTap: () => Navigator.pop(context, entry.key),
                  title: Text(entry.value),
                  trailing: entry.key == current ? const Icon(Icons.check_circle, color: GoViaColors.orange) : null,
                ),
            ],
          ),
        ),
      );

  Future<void> _runSave(Future<void> Function() action) async {
    if (saving) {
      return;
    }
    setState(() => saving = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lagret.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kunne ikke lagre: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final user = state.auth.user;
    final profile = state.profile ?? UserProfile(
      id: user?.id ?? 'local',
      email: user?.email ?? (AppConfig.devSeed ? 'Utviklermodus' : 'Ikke innlogget'),
      displayName: user?.email?.split('@').first ?? '',
    );

    final body = RefreshIndicator(
      onRefresh: () async {
        try {
          await state.refreshProfile();
        } catch (_) {}
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, widget.embedded ? 18 : 8, 18, widget.embedded ? 110 : 24),
        children: [
          if (widget.section == null)
            ProfileOverview(
              profile: profile,
              showTitle: widget.embedded,
              onOpen: (section) => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(section: section))),
            ),
          if (widget.section == ProfileSection.account) ...[
            _ProfileHero(profile: profile, saving: saving, onAvatar: _changeAvatar),
            const SizedBox(height: 22),
            const SectionTitle('Konto'),
            _settingTile(Icons.manage_accounts_outlined, 'Profilopplysninger', 'Navn, område, bio og profilbilde', onTap: () => _editProfile(profile)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await state.auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    AppRoutes.login,
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logg ut'),
            ),
          ],
          if (widget.section == ProfileSection.settings) ...[
            const SectionTitle('Navigasjon og transport'),
            _settingTile(Icons.display_settings_outlined, 'Skjerm og kart', 'Skjermretning, kartmodus og visning under tur',
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ScreenSettingsScreen()))),

            _settingTile(
              Icons.route_outlined,
              'Foretrukket transport',
              transportLabel(profile.preferredTransport),
              onTap: () => _selectTransport(profile),
            ),
            _settingTile(Icons.straighten, 'Enheter', profile.unitSystem == 'imperial' ? 'Imperial' : 'Metrisk', onTap: () => _selectUnits(profile)),
            _switchTile(
              Icons.volume_up_outlined,
              'Stemmeveiledning',
              'Talebeskjeder under aktiv navigasjon',
              profile.voiceEnabled,
              (value) => _runSave(() => state.updateProfile(voiceEnabled: value)),
            ),
            _settingTile(
              Icons.translate_rounded,
              'Navigasjonsspråk',
              _navigationLanguageLabel(state.navigationLanguage),
              onTap: _selectNavigationLanguage,
            ),
            const SizedBox(height: 18),
            const SectionTitle('Utseende'),
            _settingTile(
              Icons.brightness_6_outlined,
              'Mobiltema',
              _androidAutoThemeLabel(state.appThemeMode),
              onTap: _selectAppTheme,
            ),
            _settingTile(
              Icons.brightness_6_outlined,
              'Bilskjermtema · Android Auto',
              _androidAutoThemeLabel(state.androidAutoThemeMode),
              onTap: _selectAndroidAutoTheme,
            ),
          ],
          if (widget.section == ProfileSection.privacy) ...[
            const SectionTitle('Personvern og deling'),
            _settingTile(
              Icons.location_on_outlined,
              'Posisjonsdeling',
              _locationSharingLabel(profile.locationSharing),
              onTap: () => _selectLocationSharing(profile),
            ),
            _switchTile(
              Icons.public_outlined,
              'Offentlig profil',
              'Andre GoVia-brukere kan åpne den korte profilen din',
              profile.profilePublic,
              (value) => _runSave(() => state.updateProfile(profilePublic: value)),
            ),
            _switchTile(
              Icons.alt_route_outlined,
              'Vis publiserte turer',
              'Publiserte ruter vises på profilen din',
              profile.showPublishedRoutes,
              (value) => _runSave(() => state.updateProfile(showPublishedRoutes: value)),
            ),
            _switchTile(
              Icons.star_outline,
              'Tillat vurderinger',
              'Andre kan vurdere turer du publiserer',
              profile.allowRouteRatings,
              (value) => _runSave(() => state.updateProfile(allowRouteRatings: value)),
            ),
          ],
          if (widget.section == ProfileSection.routes) ...[
            const SectionTitle('Innhold'),
            _settingTile(Icons.bookmark_outline, 'Lagrede turer', 'Ruter du har lagret fra Oppdag', onTap: () => Navigator.pushNamed(context, AppRoutes.savedRoutes)),
            _settingTile(Icons.public_outlined, 'Mine publiserte turer', 'Publiser, rediger og avpubliser community-ruter', onTap: () => Navigator.pushNamed(context, AppRoutes.myPublishedRoutes)),
          ],
          if (widget.section == ProfileSection.app) ...[
            if (DevFeatures.navigationSimulator) ...[
              const SectionTitle('Utviklerverktøy'),
              Card(
                child: ListTile(
                  onTap: () => Navigator.pushNamed(context, AppRoutes.navigationSimulator),
                  leading: const Icon(Icons.science_rounded, color: GoViaColors.orange),
                  title: const Text('Navigasjonssimulator', style: TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: const Text('DEV ONLY · test GPS, rerouting, manøvrer og ankomst hjemmefra'),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 18),
            ],
            const SectionTitle('App'),
            _settingTile(
              Icons.notifications_outlined,
              'Varsler',
              state.unreadNotificationCount == 0 ? 'Ingen uleste varsler' : '${state.unreadNotificationCount} ulest${state.unreadNotificationCount == 1 ? '' : 'e'}',
              onTap: widget.embedded ? () => state.setShellIndex(1) : () => Navigator.pushNamed(context, AppRoutes.notifications),
            ),
            _settingTile(Icons.download_for_offline_outlined, 'Offlinekart', 'Administrer nedlastede områder', onTap: () => Navigator.pushNamed(context, AppRoutes.offline)),
            Card(
              child: ListTile(
                onTap: Platform.isAndroid && !checking ? _checkUpdate : null,
                leading: const Icon(Icons.system_update_alt, color: GoViaColors.orange),
                title: const Text('Se etter oppdatering', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(Platform.isAndroid ? 'GitHub Releases · v$version' : 'iOS bruker App Store / TestFlight'),
                trailing: checking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chevron_right),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: progress),
            ],
            const SizedBox(height: 18),
          ],

        ],
      ),
    );

    return widget.embedded ? body : Scaffold(appBar: AppBar(title: Text(widget.section?.title ?? 'Profil')), body: body);
  }

  String _locationSharingLabel(String value) => switch (value) {
        'off' => 'Av',
        'group_trip' => 'Kun med deltakere på turen',
        _ => 'Kun under aktiv tur',
      };

  Widget _settingTile(IconData icon, String title, String subtitle, {required VoidCallback onTap}) => Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            onTap: saving ? null : onTap,
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            trailing: const Icon(Icons.chevron_right),
          ),
          const Divider(height: 1),
        ],
      );

  Widget _switchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) => Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            value: value,
            onChanged: saving ? null : onChanged,
          ),
          const Divider(height: 1),
        ],
      );
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.saving, required this.onAvatar});

  final UserProfile profile;
  final bool saving;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    backgroundImage: profile.avatarUrl?.isNotEmpty == true ? NetworkImage(profile.avatarUrl!) : null,
                    child: profile.avatarUrl?.isNotEmpty == true ? null : Icon(Icons.person, size: 42, color: Theme.of(context).colorScheme.primary),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: IconButton.filled(
                      tooltip: 'Bytt profilbilde',
                      onPressed: saving ? null : onAvatar,
                      icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName.trim().isEmpty ? profile.email.split('@').first : profile.displayName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(profile.email, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    if (profile.location.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(children: [Icon(Icons.location_on_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 4), Flexible(child: Text(profile.location, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))]),
                    ],
                    if (profile.bio.trim().isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(profile.bio, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

