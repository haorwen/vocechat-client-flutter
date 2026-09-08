import 'package:flutter/material.dart';

import 'package:vocechat_client/l10n/generated/app_localizations.dart';
import 'package:vocechat_client/shared/models/avo_params.dart';
import 'package:vocechat_client/shared/widgets/avo_avatar.dart';

// Flutter 3.27 predates widget_previews. This isolated entry point has no
// authentication, network, Riverpod or native plugin dependencies.
// flutter run -t tool/avo_preview.dart -d windows
void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: _AvoPreview(),
    ));

class _AvoPreview extends StatefulWidget {
  const _AvoPreview();
  @override
  State<_AvoPreview> createState() => _AvoPreviewState();
}

class _AvoPreviewState extends State<_AvoPreview> {
  AvoParams _params = AvoParams.defaults.copyWith(name: 'Han');
  double _level = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final styles = {
      'blob': l.avoStyleBlob,
      'ring': l.avoStyleRing,
      'wave': l.avoStyleWave,
    };
    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: const Color(0xff0a0b0c),
        appBar: AppBar(title: const Text('Avo')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Text(l.avoPreviewHint),
          const SizedBox(height: 16),
          Wrap(spacing: 16, runSpacing: 16, children: [
            for (final style in ['blob', 'ring', 'wave'])
              SizedBox(
                width: 320,
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: const Color(0xff101214),
                      child: SizedBox(
                        height: 260,
                        child: AvoAvatar(
                          params: _params.copyWith(style: style),
                          level: _level,
                          interactive: true,
                        ),
                      ),
                    ),
                  ),
                  Text(styles[style]!),
                ]),
              ),
          ]),
          const SizedBox(height: 24),
          TextField(
            controller: null,
            decoration: InputDecoration(labelText: l.avoPreviewNameLabel),
            onChanged: (name) =>
                setState(() => _params = _params.copyWith(name: name)),
          ),
          Text(l.avoVoiceLevel((_level * 100).round())),
          Slider(
              value: _level,
              onChanged: (level) => setState(() => _level = level)),
          Text(l.avoEnergy((_params.energy * 100).round())),
          Slider(
              min: .1,
              max: 1,
              divisions: 18,
              value: _params.energy,
              onChanged: (energy) =>
                  setState(() => _params = _params.copyWith(energy: energy))),
          Wrap(spacing: 8, children: [
            for (final hue in AvoParams.allowedHues)
              ChoiceChip(
                  label: Text('$hue°'),
                  selected: _params.hue == hue,
                  onSelected: (_) =>
                      setState(() => _params = _params.copyWith(hue: hue))),
            OutlinedButton(
                onPressed: () => setState(() =>
                    _params = _params.copyWith(variant: _params.variant + 1)),
                child: Text(l.avoNextVariant)),
          ]),
        ]),
      ),
    );
  }
}
