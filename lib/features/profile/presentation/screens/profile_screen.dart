import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/routes.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../../domain/entities/profile_avatar.dart';
import '../widgets/avatar_picker_sheet.dart';
import '../widgets/user_avatar.dart';

/// Max characters for the bio. Mirrors `PROFILE_LIMITS.description` on the
/// backend, which truncates anything longer.
const int _descriptionMaxLength = 280;

/// View + edit of the signed-in volunteer's own profile. One screen: the
/// fields are always editable and a single Save button patches `/user`.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Null until the first build seeds the form from the authenticated user.
  String? _avatarValue;
  bool _seeded = false;
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _seed(AuthUser user) {
    if (_seeded) return;
    _seeded = true;
    _nameController.text = user.completeName;
    _descriptionController.text = user.description;
    _avatarValue = user.profileImageUrl;
  }

  bool _isDirty(AuthUser user) =>
      _nameController.text.trim() != user.completeName ||
      _descriptionController.text.trim() != user.description ||
      _avatarValue != user.profileImageUrl;

  Future<void> _save() async {
    final t = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    final error = await ref.read(authControllerProvider.notifier).updateProfile(
          completeName: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          profileImage: _avatarValue ?? '',
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitError = error?.message;
    });
    if (error == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t.profile_saved)));
    }
  }

  Future<void> _pickAvatar() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => AvatarPickerSheet(selected: _avatarValue),
    );
    if (picked == null || !mounted) return;
    setState(() => _avatarValue = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    if (authState is! AuthStateAuthenticated) {
      // The router redirects unauthenticated users away; this only shows
      // during the frame where logout is in flight.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = authState.user;
    _seed(user);

    final avatar = ProfileAvatar.resolve(_avatarValue);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.profile_title),
        actions: [
          IconButton(
            tooltip: t.common_logout,
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      InkWell(
                        onTap: _pickAvatar,
                        customBorder: const CircleBorder(),
                        child: UserAvatar(
                          imageValue: _avatarValue,
                          fallbackLabel: user.completeName,
                          radius: 48,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (avatar != null)
                        Text(
                          avatar.label(t),
                          style: theme.textTheme.titleMedium,
                        ),
                      TextButton.icon(
                        onPressed: _pickAvatar,
                        icon: const Icon(Icons.face_retouching_natural),
                        label: Text(t.profile_avatar_change),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // The numbers live on their own screen — this screen is
                // about editing who you are, not reading stats.
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.insights_outlined),
                    title: Text(t.profile_stats_title),
                    subtitle: Text(t.profile_stats_subtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.pushNamed(AppRoute.journey),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(height: 1),
                ),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t.profile_name_label,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? t.profile_name_required
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: _descriptionMaxLength,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: t.profile_description_label,
                    hintText: t.profile_description_hint,
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                _ReadOnlyRow(
                  icon: Icons.person_outline,
                  label: t.profile_username_label,
                  value: user.username,
                ),
                _ReadOnlyRow(
                  icon: Icons.email_outlined,
                  label: t.profile_email_label,
                  value: user.email,
                  note: t.profile_email_locked,
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _submitError!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submitting || !_isDirty(user) ? null : _save,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(t.profile_save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.outline),
      title: Text(label, style: theme.textTheme.bodySmall),
      subtitle: Text(value, style: theme.textTheme.bodyLarge),
      trailing: note == null
          ? null
          : Tooltip(
              message: note!,
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ),
    );
  }
}
