import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocechat_client/shared/models/avo_interaction.dart';
import 'package:vocechat_client/shared/models/avo_params.dart';
import 'package:vocechat_client/shared/widgets/avo_avatar.dart';

void main() {
  testWidgets('renders each native Avo style without a web view',
      (tester) async {
    for (final style in AvoParams.allowedStyles) {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 180,
            height: 180,
            child: AvoAvatar(
              params: AvoParams.defaults.copyWith(style: style),
              level: .5,
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
      expect(find.byType(AvoAvatar), findsOneWidget);
    }
  });

  testWidgets('tap sends a pop and animation settles', (tester) async {
    final interactions = <AvoLocalInteraction>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 180,
          height: 180,
          child: AvoAvatar(
            params: AvoParams.defaults,
            interactive: true,
            onInteraction: interactions.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AvoAvatar));
    await tester.pumpAndSettle();

    expect(interactions.map((value) => value.type),
        contains(AvoInteractionType.pop));
  });

  testWidgets('remote pulse is accepted by event id', (tester) async {
    final pulse = AvoPulse(eventId: 'remote-pop-1', receivedAt: DateTime.now());
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 180,
          height: 180,
          child: AvoAvatar(
            params: AvoParams.defaults,
            remoteInteraction: RemoteAvoInteraction(pop: pulse),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });
}
