import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/account_store.dart';
import '../../../core/storage/secure_token_store.dart';
import '../../../shared/models/avo_params.dart';
import '../../../shared/widgets/avo_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../data/user_api.dart';

/// Profile-scoped Avo editor. Changes stay in the preview until Save is
/// pressed, so dragging energy never produces an HTTP request per frame.
class AvoSettingsCard extends ConsumerStatefulWidget {
  const AvoSettingsCard({super.key});
  @override
  ConsumerState<AvoSettingsCard> createState() => _AvoSettingsCardState();
}

class _AvoSettingsCardState extends ConsumerState<AvoSettingsCard> {
  AvoParams _params = AvoParams.defaults;
  late final TextEditingController _nameController =
      TextEditingController(text: _params.name);
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Settings is also rendered by logged-out/loading shells and by widget
    // tests. Do not start Dio's retry chain until an account-scoped token is
    // actually available; Avo is optional and defaults are sufficient here.
    final accountId =
        ref.read(accountStoreProvider).valueOrNull?.currentAccountId;
    if (accountId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final tokens =
          await ref.read(secureTokenStoreProvider(accountId)).readTokens();
      if (tokens == null || !mounted) {
        if (mounted) setState(() => _loading = false);
        return;
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final params = await ref.read(userApiProvider).getAvo();
      if (mounted) {
        _nameController.text = params.name;
        setState(() => _params = params);
      }
    } catch (_) {
      // The Avo feature is optional and must not make settings unusable.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(userApiProvider).updateAvo(_params);
      // Refreshing /me also updates account metadata and directory data through
      // the existing auth lifecycle without putting transient interaction state
      // in the message cache.
      await ref.read(authControllerProvider.notifier).refreshUser();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Avo saved')));
      }
      // Some compatible servers return a partial user without avo_params; the
      // authenticated refresh above remains the source of truth in that case.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Unable to save Avo: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Avo',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Customize the avatar shown when your camera is off.'),
          const SizedBox(height: 18),
          Center(
              child: SizedBox(
                  width: 150,
                  height: 150,
                  child: AvoAvatar(params: _params, level: .35))),
          if (_loading)
            const LinearProgressIndicator()
          else ...[
            TextField(
              key: const Key('avo-name'),
              maxLength: 20,
              decoration: const InputDecoration(labelText: 'Name'),
              controller: _nameController,
              onChanged: (v) =>
                  setState(() => _params = _params.copyWith(name: v)),
            ),
            DropdownButtonFormField<String>(
              value: _params.style,
              decoration: const InputDecoration(labelText: 'Style'),
              items: const [
                DropdownMenuItem(value: 'blob', child: Text('Blob')),
                DropdownMenuItem(value: 'ring', child: Text('Ring')),
                DropdownMenuItem(value: 'wave', child: Text('Wave'))
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _params = _params.copyWith(style: v));
                }
              },
            ),
            const SizedBox(height: 12),
            Text('Energy ${(100 * _params.energy).round()}%'),
            Slider(
              key: const Key('avo-energy'),
              min: .1,
              max: 1,
              divisions: 18,
              value: _params.energy,
              onChanged: (v) =>
                  setState(() => _params = _params.copyWith(energy: v)),
            ),
            Wrap(spacing: 8, children: [
              for (final hue in AvoParams.allowedHues)
                ChoiceChip(
                    label: Text('$hue°'),
                    selected: hue == _params.hue,
                    onSelected: (_) =>
                        setState(() => _params = _params.copyWith(hue: hue)))
            ]),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'))),
          ],
        ]),
      ),
    );
  }
}
