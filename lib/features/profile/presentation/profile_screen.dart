import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_scope.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/govia_theme.dart';
import '../../../core/updater/github_updater.dart';
import '../../../core/widgets/govia_widgets.dart';
import '../../../domain/models.dart';
import '../../../domain/transport_profiles.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.embedded = false});
  final bool embedded;

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
      if (mounted) setState(() => version = info.version);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (requestedProfile) return;
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
      if (!mounted) return;
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
          if (mounted) setState(() => progress = value);
        });
        await updater.install(file);
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Oppdatering feilet: $error')));
    } finally {
      if (mounted) setState(() {
        checking = false;
        progress = null;
      });
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
    if (save != true) return;
    await _runSave(() => state.updateProfile(displayName: name.text, location: location.text, bio: bio.text));
  }

  Future<void> _changeAvatar() async {
    final state = AppScope.of(context);
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600);
    if (image == null) return;
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
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lagret.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kunne ikke lagre: $error')));
    } finally {
      if (mounted) setState(() => saving = false);
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
    final completedCount = state.trips.where((trip) => trip.status == TripStatus.completed).length;
    final plannedCount = state.trips.where((trip) => trip.status == TripStatus.planned).length;
    final activeCount = state.trips.where((trip) => trip.status == TripStatus.active).length;

    final body = RefreshIndicator(
      onRefresh: () async {
        try {
          await state.refreshProfile();
        } catch (_) {}
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(18, widget.embedded ? 18 : 8, 18, 110),
        children: [
          if (widget.embedded) ...[
            Text('Profil', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 18),
          ],
          _ProfileHero(profile: profile, version: version, saving: saving, onEdit: () => _editProfile(profile), onAvatar: _changeAvatar),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Planlagt', value: '$plannedCount', icon: Icons.event_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Aktiv', value: '$activeCount', icon: Icons.navigation_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Fullført', value: '$completedCount', icon: Icons.check_circle_outline)),
            ],
          ),
          const SizedBox(height: 22),
          const SectionTitle('Tur og navigasjon'),
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
            Icons.location_on_outlined,
            'Posisjonsdeling',
            _locationSharingLabel(profile.locationSharing),
            onTap: () => _selectLocationSharing(profile),
          ),
          const SizedBox(height: 18),
          const SectionTitle('Community og personvern'),
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
          const SizedBox(height: 18),
          const SectionTitle('Mitt innhold'),
          _settingTile(Icons.history, 'Mine turer og historikk', '$completedCount fullførte', onTap: () => Navigator.pushNamed(context, AppRoutes.history)),
          _settingTile(Icons.bookmark_outline, 'Lagrede turer', 'Ruter du har lagret fra Oppdag', onTap: () => Navigator.pushNamed(context, AppRoutes.savedRoutes)),
          const SizedBox(height: 18),
          const SectionTitle('App'),
          _settingTile(Icons.notifications_outlined, 'Varsler', 'Åpne varsler', onTap: () => Navigator.pushNamed(context, AppRoutes.notifications)),
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
          OutlinedButton.icon(
            onPressed: () async {
              await state.auth.signOut();
              if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logg ut'),
          ),
        ],
      ),
    );

    return widget.embedded ? body : Scaffold(appBar: AppBar(title: const Text('Profil / innstillinger')), body: body);
  }

  String _locationSharingLabel(String value) => switch (value) {
        'off' => 'Av',
        'group_trip' => 'Kun med deltakere på turen',
        _ => 'Kun under aktiv tur',
      };

  Widget _settingTile(IconData icon, String title, String subtitle, {required VoidCallback onTap}) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Card(
          child: ListTile(
            onTap: saving ? null : onTap,
            leading: Icon(icon, color: GoViaColors.blue),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      );

  Widget _switchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Card(
          child: SwitchListTile(
            secondary: Icon(icon, color: GoViaColors.blue),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(subtitle),
            value: value,
            onChanged: saving ? null : onChanged,
          ),
        ),
      );
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.profile, required this.version, required this.saving, required this.onEdit, required this.onAvatar});

  final UserProfile profile;
  final String version;
  final bool saving;
  final VoidCallback onEdit;
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
                    backgroundColor: GoViaColors.panel2,
                    backgroundImage: profile.avatarUrl?.isNotEmpty == true ? NetworkImage(profile.avatarUrl!) : null,
                    child: profile.avatarUrl?.isNotEmpty == true ? null : const Icon(Icons.person, size: 42, color: GoViaColors.cyan),
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
                    Text(profile.email, style: const TextStyle(color: GoViaColors.muted)),
                    if (profile.location.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(children: [const Icon(Icons.location_on_outlined, size: 16, color: GoViaColors.muted), const SizedBox(width: 4), Flexible(child: Text(profile.location, style: const TextStyle(color: GoViaColors.muted)))]),
                    ],
                    if (profile.bio.trim().isNotEmpty) ...[
                      const SizedBox(height: 9),
                      Text(profile.bio, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FilledButton.tonalIcon(onPressed: saving ? null : onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Rediger profil')),
                        const SizedBox(width: 10),
                        Text('v$version', style: const TextStyle(color: GoViaColors.muted)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: GoViaColors.cyan),
              const SizedBox(height: 7),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: GoViaColors.muted, fontSize: 12)),
            ],
          ),
        ),
      );
}
