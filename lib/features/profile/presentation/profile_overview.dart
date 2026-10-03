import 'package:flutter/material.dart';
import '../../../domain/models.dart';

enum ProfileSection {
  account('Brukerkonto', Icons.person_outline),
  settings('Innstillinger', Icons.settings_outlined),
  privacy('Personvern og deling', Icons.shield_outlined),
  routes('Mine ruter', Icons.bookmark_outline),
  app('App og offline', Icons.download_for_offline_outlined);

  const ProfileSection(this.title, this.icon);
  final String title;
  final IconData icon;
}

class ProfileOverview extends StatelessWidget {
  const ProfileOverview({super.key, required this.profile, required this.onOpen, this.showTitle = true});
  final UserProfile profile;
  final bool showTitle;
  final ValueChanged<ProfileSection> onOpen;

  String _description(ProfileSection section) => switch (section) {
    ProfileSection.account => 'Profilopplysninger og profilbilde',
    ProfileSection.settings => '${transportLabel(profile.preferredTransport)} · navigasjon og utseende',
    ProfileSection.privacy => 'Synlighet og posisjonsdeling',
    ProfileSection.routes => 'Lagrede og publiserte turer',
    ProfileSection.app => 'Offlinekart, varsler og oppdateringer',
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = profile.displayName.trim().isEmpty
        ? profile.email.split('@').first : profile.displayName;
    final avatar = profile.avatarUrl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Text('Profil', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
        ],
        Center(child: CircleAvatar(
          radius: 44,
          backgroundColor: colors.surfaceContainerHighest,
          backgroundImage: avatar?.isNotEmpty == true ? NetworkImage(avatar!) : null,
          child: avatar?.isNotEmpty == true ? null : Icon(Icons.person_outline, size: 44, color: colors.primary),
        )),
        const SizedBox(height: 14),
        Text(name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(profile.email, textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
        const SizedBox(height: 26),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final section in ProfileSection.values) ...[
              ListTile(
                key: ValueKey(section),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Icon(section.icon, color: colors.primary),
                title: Text(section.title),
                subtitle: Text(_description(section)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpen(section),
              ),
              if (section != ProfileSection.values.last) const Divider(height: 1, indent: 56),
            ],
          ]),
        ),
      ],
    );
  }
}
