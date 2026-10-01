import 'package:flutter/services.dart' show appFlavor;

/// Flutter supplies FLUTTER_APP_FLAVOR from --flavor to match Android's variant.
/// Do not replace this with an independent dart-define: native and Dart feature
/// availability must agree. Unflavored desktop/iOS builds retain their behavior.
const isPlayDistribution = appFlavor == 'play';
const supportsDirectDistributionFeatures = !isPlayDistribution;
