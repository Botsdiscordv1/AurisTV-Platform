library responsive_utils;

import 'package:flutter/widgets.dart';
import 'package:auris_core/core/utils/responsive_utils.dart';

export 'package:auris_core/core/utils/responsive_utils.dart';

({int columns, double spacing, double padding}) webPosterGridMetrics(BuildContext context) {
  final double width = MediaQuery.sizeOf(context).width;
  final bool mobile = ResponsiveUtils.isMobile(context);
  return (
    columns: mobile ? 3 : (width / 180).round().clamp(5, 9),
    spacing: mobile ? 12 : 20,
    padding: mobile ? 16 : 24,
  );
}

double webPosterGridCellWidth(BuildContext context) {
  final ({int columns, double spacing, double padding}) metrics = webPosterGridMetrics(context);
  final double width = MediaQuery.sizeOf(context).width;
  return (width - 2 * metrics.padding - metrics.spacing * (metrics.columns - 1)) / metrics.columns;
}
