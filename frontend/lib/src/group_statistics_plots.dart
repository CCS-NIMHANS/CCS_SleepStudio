import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'group_statistics_engine.dart';

/// Supported plot representation types.
enum GroupStatsPlotType {
  boxplot,
  barChart,
}

/// Supported grouping/clustering arrangements across the horizontal axis.
enum GroupStatsClusterMode {
  /// Cluster by Region/Spatial Factor (e.g. Frontal: [CNT] [MCI], Central: [CNT] [MCI]).
  bySubgroup,

  /// Cluster by Cohort/Primary Group (e.g. CNT: [Frontal, Central...], MCI: [Frontal, Central...]).
  byGroup,
}

/// Interactive publication-grade Box-and-Whisker & Grouped Bar Chart widget rendered directly in Flutter.
class GroupStatsBoxplotWidget extends StatelessWidget {
  const GroupStatsBoxplotWidget({
    super.key,
    required this.metric,
    this.unit = '',
    required this.descriptives,
    required this.posthocs,
    this.plotType = GroupStatsPlotType.boxplot,
    this.clusterMode = GroupStatsClusterMode.bySubgroup,
    this.useSem = true,
  });

  final String metric;
  final String unit;
  final List<Map<String, dynamic>> descriptives;
  final List<Map<String, dynamic>> posthocs;
  final GroupStatsPlotType plotType;
  final GroupStatsClusterMode clusterMode;
  final bool useSem;

  @override
  Widget build(BuildContext context) {
    if (descriptives.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No observations to plot.')));
    }

    final hasSubgroups = descriptives.any((d) => d['subgroup'] != null && (d['subgroup'] as String).isNotEmpty);
    final orderedGroups = <String>[];
    for (final d in descriptives) {
      final g = d['group'] as String;
      if (!orderedGroups.contains(g)) orderedGroups.add(g);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = constraints.maxWidth;
        final plotHeight = 460.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [
                  BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              padding: const EdgeInsets.only(top: 16, bottom: 8, left: 12, right: 16),
              child: CustomPaint(
                size: Size(plotWidth, plotHeight),
                painter: _BoxplotPainter(
                  descriptives: descriptives,
                  posthocs: posthocs,
                  metric: metric,
                  unit: unit,
                  plotType: plotType,
                  clusterMode: clusterMode,
                  useSem: useSem,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (hasSubgroups && clusterMode == GroupStatsClusterMode.bySubgroup) ...[
                  for (var k = 0; k < orderedGroups.length; k++)
                    _buildGroupLegendItem(
                      orderedGroups[k],
                      _BoxplotPainter._palette[k % _BoxplotPainter._palette.length],
                      isHatched: (k % 2 == 1 && plotType == GroupStatsPlotType.barChart),
                    ),
                ],
                if (plotType == GroupStatsPlotType.barChart) ...[
                  _buildLegendItem(Colors.black87, useSem ? 'Error Bar (±SEM)' : 'Error Bar (±SD)'),
                  _buildLegendItem(Colors.black54, 'Observations (Jittered •)'),
                  _buildLegendItem(const Color(0xFF16A34A), 'Sig Contrast (* p<0.05)'),
                ] else ...[
                  _buildLegendItem(const Color(0xFF1F4E79), 'Box (IQR: Q1–Q3)'),
                  _buildLegendItem(Colors.black87, 'Median Line (—)'),
                  _buildLegendItem(const Color(0xFFD32F2F), 'Mean Marker (▲)'),
                  _buildLegendItem(Colors.grey.shade600, 'Observations (Jittered •)'),
                  _buildLegendItem(const Color(0xFF16A34A), 'Sig Contrast (* p<0.05)'),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildGroupLegendItem(String label, Color color, {bool isHatched = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color.withOpacity(isHatched ? 0.25 : 0.40),
            border: Border.all(color: color, width: 1.6),
            borderRadius: BorderRadius.circular(2),
          ),
          child: isHatched
              ? CustomPaint(
                  painter: _HatchLegendPainter(color: color),
                )
              : null,
        ),
        const SizedBox(width: 5),
        Text(
          isHatched ? '$label (Hatched)' : label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
      ],
    );
  }

  /// Renders publication-grade plot (Boxplot or Grouped Bar Chart) to PNG image bytes offscreen.
  static Future<Uint8List> renderPlotImage({
    required List<Map<String, dynamic>> descriptives,
    required List<Map<String, dynamic>> posthocs,
    required String metric,
    String unit = '',
    String? title,
    GroupStatsPlotType plotType = GroupStatsPlotType.boxplot,
    GroupStatsClusterMode clusterMode = GroupStatsClusterMode.bySubgroup,
    bool useSem = true,
    double width = 1100,
    double height = 620,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = const Color(0xFFFFFFFF));

    final painter = _BoxplotPainter(
      descriptives: descriptives,
      posthocs: posthocs,
      metric: metric,
      unit: unit,
      title: title,
      showLegend: true,
      plotType: plotType,
      clusterMode: clusterMode,
      useSem: useSem,
    );
    painter.paint(canvas, Size(width, height));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Backwards-compatible alias for renderPlotImage.
  static Future<Uint8List> renderBoxplotImage({
    required List<Map<String, dynamic>> descriptives,
    required List<Map<String, dynamic>> posthocs,
    required String metric,
    String unit = '',
    String? title,
    GroupStatsPlotType plotType = GroupStatsPlotType.boxplot,
    GroupStatsClusterMode clusterMode = GroupStatsClusterMode.bySubgroup,
    bool useSem = true,
    double width = 1100,
    double height = 620,
  }) {
    return renderPlotImage(
      descriptives: descriptives,
      posthocs: posthocs,
      metric: metric,
      unit: unit,
      title: title,
      plotType: plotType,
      clusterMode: clusterMode,
      useSem: useSem,
      width: width,
      height: height,
    );
  }
}

class _HatchLegendPainter extends CustomPainter {
  _HatchLegendPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withOpacity(0.8)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), p);
    canvas.drawLine(Offset(size.width * 0.4, size.height), Offset(size.width, size.height * 0.4), p);
    canvas.drawLine(Offset(0, size.height * 0.6), Offset(size.width * 0.6, 0), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlotItem {
  _PlotItem({
    required this.descriptive,
    required this.lookupKey,
    required this.color,
    required this.groupIndex,
    required this.clusterIndex,
    required this.itemSubLabel,
    required this.cx,
    required this.width,
  });

  final Map<String, dynamic> descriptive;
  final String lookupKey;
  final Color color;
  final int groupIndex;
  final int clusterIndex;
  final String itemSubLabel;
  final double cx;
  final double width;
}

class _ClusterInfo {
  _ClusterInfo({
    required this.label,
    required this.startX,
    required this.endX,
    required this.centerX,
  });

  final String label;
  final double startX;
  final double endX;
  final double centerX;
}

class _BoxplotPainter extends CustomPainter {
  _BoxplotPainter({
    required this.descriptives,
    required this.posthocs,
    required this.metric,
    required this.unit,
    this.title,
    this.showLegend = false,
    this.plotType = GroupStatsPlotType.boxplot,
    this.clusterMode = GroupStatsClusterMode.bySubgroup,
    this.useSem = true,
  });

  final List<Map<String, dynamic>> descriptives;
  final List<Map<String, dynamic>> posthocs;
  final String metric;
  final String unit;
  final String? title;
  final bool showLegend;
  final GroupStatsPlotType plotType;
  final GroupStatsClusterMode clusterMode;
  final bool useSem;

  static const List<Color> _palette = [
    Color(0xFF1F4E79), // Deep Navy Blue (Group 1 / CNT)
    Color(0xFFE65100), // Vibrant Orange (Group 2 / MCI)
    Color(0xFF2E7D32), // Forest Green
    Color(0xFF6A1B9A), // Royal Purple
    Color(0xFFD32F2F), // Crimson Red
    Color(0xFF00838F), // Teal
    Color(0xFF4E342E), // Brown
    Color(0xFF37474F), // Slate Grey
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (descriptives.isEmpty) return;

    // Discover groups and subgroups
    final orderedGroups = <String>[];
    final orderedSubgroups = <String>[];
    for (final d in descriptives) {
      final g = d['group'] as String;
      if (!orderedGroups.contains(g)) orderedGroups.add(g);
      final s = d['subgroup'] as String?;
      if (s != null && s.isNotEmpty && !orderedSubgroups.contains(s)) {
        orderedSubgroups.add(s);
      }
    }
    final hasSubgroups = orderedSubgroups.isNotEmpty;

    // Geometry margins
    final hasTitle = title != null && title!.isNotEmpty;
    const marginLeft = 65.0;
    final marginRight = size.width - 20.0;
    final marginTop = hasTitle ? 48.0 : 20.0;
    final marginBottom = size.height - (showLegend ? 76.0 : (hasSubgroups ? 64.0 : 48.0));

    final plotWidth = marginRight - marginLeft;
    final plotHeight = marginBottom - marginTop;

    // Build positioned items & cluster headers
    final plotItems = <_PlotItem>[];
    final clusterInfoList = <_ClusterInfo>[];

    if (hasSubgroups && clusterMode == GroupStatsClusterMode.bySubgroup) {
      // CLUSTER BY REGION/SUBGROUP (Snapshot 1: Frontal [CNT][MCI], Central [CNT][MCI]...)
      final cCount = orderedSubgroups.length;
      final kCount = orderedGroups.length;
      final clusterGap = math.min(32.0, math.max(14.0, plotWidth * 0.04));
      final totalClusterW = plotWidth - (cCount - 1) * clusterGap;
      final clusterW = totalClusterW / cCount;

      final itemGap = (plotType == GroupStatsPlotType.barChart) ? 4.0 : 6.0;
      final maxItemW = (plotType == GroupStatsPlotType.barChart) ? 48.0 : 42.0;
      final itemW = math.min(maxItemW, math.max(12.0, (clusterW - (kCount - 1) * itemGap) / kCount));
      final innerW = kCount * itemW + (kCount - 1) * itemGap;

      for (var c = 0; c < cCount; c++) {
        final subgrp = orderedSubgroups[c];
        final clusterStartX = marginLeft + c * (clusterW + clusterGap) + (clusterW - innerW) / 2;
        final clusterCenterX = marginLeft + c * (clusterW + clusterGap) + clusterW / 2;
        clusterInfoList.add(_ClusterInfo(
          label: subgrp,
          startX: clusterStartX,
          endX: clusterStartX + innerW,
          centerX: clusterCenterX,
        ));

        for (var k = 0; k < kCount; k++) {
          final grp = orderedGroups[k];
          final itemCx = clusterStartX + k * (itemW + itemGap) + itemW / 2;
          final key = '$grp|$subgrp';
          Map<String, dynamic>? matchDesc;
          for (final it in descriptives) {
            if (it['group'] == grp && it['subgroup'] == subgrp) {
              matchDesc = it;
              break;
            }
          }
          if (matchDesc != null) {
            plotItems.add(_PlotItem(
              descriptive: matchDesc,
              lookupKey: key,
              color: _palette[k % _palette.length],
              groupIndex: k,
              clusterIndex: c,
              itemSubLabel: '$grp\n(n=${matchDesc['n']})',
              cx: itemCx,
              width: itemW,
            ));
          }
        }
      }
    } else if (hasSubgroups && clusterMode == GroupStatsClusterMode.byGroup) {
      // CLUSTER BY COHORT/GROUP (Snapshot 2: CNT [Frontal, Central...], MCI [Frontal, Central...])
      final cCount = orderedGroups.length;
      final kCount = orderedSubgroups.length;
      final clusterGap = math.min(36.0, math.max(16.0, plotWidth * 0.05));
      final totalClusterW = plotWidth - (cCount - 1) * clusterGap;
      final clusterW = totalClusterW / cCount;

      final itemGap = (plotType == GroupStatsPlotType.barChart) ? 4.0 : 6.0;
      final maxItemW = (plotType == GroupStatsPlotType.barChart) ? 44.0 : 38.0;
      final itemW = math.min(maxItemW, math.max(10.0, (clusterW - (kCount - 1) * itemGap) / kCount));
      final innerW = kCount * itemW + (kCount - 1) * itemGap;

      for (var c = 0; c < cCount; c++) {
        final grp = orderedGroups[c];
        final clusterStartX = marginLeft + c * (clusterW + clusterGap) + (clusterW - innerW) / 2;
        final clusterCenterX = marginLeft + c * (clusterW + clusterGap) + clusterW / 2;
        clusterInfoList.add(_ClusterInfo(
          label: grp,
          startX: clusterStartX,
          endX: clusterStartX + innerW,
          centerX: clusterCenterX,
        ));

        for (var k = 0; k < kCount; k++) {
          final subgrp = orderedSubgroups[k];
          final itemCx = clusterStartX + k * (itemW + itemGap) + itemW / 2;
          final key = '$grp|$subgrp';
          Map<String, dynamic>? matchDesc;
          for (final it in descriptives) {
            if (it['group'] == grp && it['subgroup'] == subgrp) {
              matchDesc = it;
              break;
            }
          }
          if (matchDesc != null) {
            plotItems.add(_PlotItem(
              descriptive: matchDesc,
              lookupKey: key,
              color: _palette[k % _palette.length],
              groupIndex: k,
              clusterIndex: c,
              itemSubLabel: '$subgrp\n(n=${matchDesc['n']})',
              cx: itemCx,
              width: itemW,
            ));
          }
        }
      }
    } else {
      // SINGLE-LEVEL FACTOR (No Subgroups)
      final nCells = descriptives.length;
      final cellW = plotWidth / nCells;
      final itemW = math.min(plotType == GroupStatsPlotType.barChart ? 60.0 : 52.0, cellW * 0.60);

      for (var i = 0; i < nCells; i++) {
        final d = descriptives[i];
        final itemCx = marginLeft + (i + 0.5) * cellW;
        final grp = d['group'] as String;
        plotItems.add(_PlotItem(
          descriptive: d,
          lookupKey: grp,
          color: _palette[i % _palette.length],
          groupIndex: i,
          clusterIndex: 0,
          itemSubLabel: '$grp\n(n=${d['n']})',
          cx: itemCx,
          width: itemW,
        ));
      }
    }

    if (plotItems.isEmpty) return;

    // Determine value range
    var globalMin = double.infinity;
    var globalMax = -double.infinity;

    for (final it in plotItems) {
      final d = it.descriptive;
      final minVal = (d['min'] as num).toDouble();
      final maxVal = (d['max'] as num).toDouble();
      final mean = (d['mean'] as num).toDouble();
      final std = ((d['std'] ?? d['sd'] ?? 0.0) as num).toDouble();
      final sem = ((d['sem'] ?? (std / math.sqrt(math.max(1, (d['n'] as num? ?? 1).toDouble())))) as num).toDouble();
      final err = useSem ? sem : std;

      if (minVal < globalMin) globalMin = minVal;
      if (maxVal > globalMax) globalMax = maxVal;
      if (mean + err > globalMax) globalMax = mean + err;
      if (mean - err < globalMin) globalMin = mean - err;
    }

    if (globalMin == globalMax) {
      globalMin -= 1.0;
      globalMax += 1.0;
    }

    double yMin;
    double yMax;
    if (plotType == GroupStatsPlotType.barChart) {
      // Bar charts baseline from zero if strictly non-negative
      if (globalMin >= 0) {
        yMin = 0.0;
        final topPad = (globalMax > 0) ? globalMax * 0.24 : 1.0;
        yMax = globalMax + topPad;
      } else {
        final valRange = globalMax - globalMin;
        yMin = globalMin - valRange * 0.06;
        yMax = globalMax + valRange * 0.24;
      }
    } else {
      final valRange = globalMax - globalMin;
      yMin = globalMin - valRange * 0.05;
      yMax = globalMax + valRange * 0.22;
    }

    double mapY(double val) {
      final frac = (val - yMin) / (yMax - yMin);
      return marginBottom - frac * plotHeight;
    }

    // Title
    if (hasTitle) {
      final titleTp = TextPainter(
        text: TextSpan(
          text: title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F4E79),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width - marginLeft - 20);
      titleTp.paint(canvas, const Offset(marginLeft, 16));
    }

    // ─── 1. DRAW GRID & Y-AXIS ──────────────────────────────────
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0;
    final gridPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.8;

    const numTicks = 5;
    for (var i = 0; i <= numTicks; i++) {
      final frac = i / numTicks;
      final val = yMin + frac * (yMax - yMin);
      final y = marginBottom - frac * plotHeight;

      canvas.drawLine(Offset(marginLeft, y), Offset(marginRight, y), gridPaint);
      canvas.drawLine(Offset(marginLeft - 4, y), Offset(marginLeft, y), axisPaint);

      final valStr = val.abs() >= 100 ? val.toStringAsFixed(0) : val.toStringAsFixed(1);
      final tp = TextPainter(
        text: TextSpan(text: valStr, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(marginLeft - tp.width - 7, y - tp.height / 2));
    }

    // Y-axis label
    final yLabel = unit.isNotEmpty ? '$metric ($unit)' : metric;
    final yLabelPainter = TextPainter(
      text: TextSpan(
        text: yLabel,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.translate(14, marginTop + plotHeight / 2 + yLabelPainter.width / 2);
    canvas.rotate(-math.pi / 2);
    yLabelPainter.paint(canvas, Offset.zero);
    canvas.restore();

    // Axes lines
    canvas.drawLine(Offset(marginLeft, marginTop), Offset(marginLeft, marginBottom), axisPaint);
    canvas.drawLine(Offset(marginLeft, marginBottom), Offset(marginRight, marginBottom), axisPaint);

    // ─── 2. DRAW PLOT ITEMS (BARS OR BOXES) ─────────────────────
    final yZero = mapY(0.0).clamp(marginTop, marginBottom);

    for (final item in plotItems) {
      final d = item.descriptive;
      final cx = item.cx;
      final color = item.color;
      final itemW = item.width;

      final mean = (d['mean'] as num).toDouble();
      final std = ((d['std'] ?? d['sd'] ?? 0.0) as num).toDouble();
      final sem = ((d['sem'] ?? (std / math.sqrt(math.max(1, (d['n'] as num? ?? 1).toDouble())))) as num).toDouble();
      final err = useSem ? sem : std;
      final rawVals = (d['raw_values'] as List<dynamic>? ?? []).map((e) => (e as num).toDouble()).toList();

      if (plotType == GroupStatsPlotType.barChart) {
        // ─── GROUPED BAR CHART (Mean ± Error + Jitter) ─────────
        final yMean = mapY(mean);
        final barTop = math.min(yZero, yMean);
        final barBottom = math.max(yZero, yMean);
        final barRect = Rect.fromLTRB(cx - itemW / 2, barTop, cx + itemW / 2, barBottom);

        // Fill: group 0 solid translucent; group 1 (e.g. MCI) diagonal hatched like Snapshot 1!
        final isHatched = (item.groupIndex % 2 == 1 && clusterInfoList.isNotEmpty);

        final fillPaint = Paint()
          ..color = color.withOpacity(isHatched ? 0.20 : 0.40)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(2)), fillPaint);

        if (isHatched) {
          canvas.save();
          canvas.clipRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(2)));
          final hatchPaint = Paint()
            ..color = color.withOpacity(0.60)
            ..strokeWidth = 1.4;
          final bW = barRect.width;
          final bH = barRect.height;
          for (double offset = -bH; offset < bW + bH; offset += 6.5) {
            canvas.drawLine(
              Offset(barRect.left + offset, barRect.bottom),
              Offset(barRect.left + offset + bH, barRect.top),
              hatchPaint,
            );
          }
          canvas.restore();
        }

        // Bar Outline
        final outlinePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(2)), outlinePaint);

        // Error Bar (Whisker + Caps)
        final yErrTop = mapY(mean + err);
        final yErrBottom = mapY(math.max(0.0, mean - err));
        final errPaint = Paint()
          ..color = Colors.black87
          ..strokeWidth = 1.6;

        canvas.drawLine(Offset(cx, yMean), Offset(cx, yErrTop), errPaint);
        if (mean - err >= 0) {
          canvas.drawLine(Offset(cx, yMean), Offset(cx, yErrBottom), errPaint);
        }

        final capW = itemW * 0.42;
        canvas.drawLine(Offset(cx - capW / 2, yErrTop), Offset(cx + capW / 2, yErrTop), errPaint);
        if (mean - err >= 0) {
          canvas.drawLine(Offset(cx - capW / 2, yErrBottom), Offset(cx + capW / 2, yErrBottom), errPaint);
        }

        // Overlay Individual Observation Points (Jittered)
        final pointPaint = Paint()
          ..color = Colors.black.withOpacity(0.40)
          ..style = PaintingStyle.fill;
        final rnd = math.Random(item.groupIndex * 71 + item.clusterIndex * 13);
        for (final rv in rawVals) {
          final jitter = (rnd.nextDouble() - 0.5) * (itemW * 0.55);
          final py = mapY(rv);
          canvas.drawCircle(Offset(cx + jitter, py), 2.2, pointPaint);
        }
      } else {
        // ─── BOX-AND-WHISKER PLOT ─────────────────────────────
        final q1 = (d['q1'] as num).toDouble();
        final q3 = (d['q3'] as num).toDouble();
        final median = (d['median'] as num).toDouble();
        final minVal = (d['min'] as num).toDouble();
        final maxVal = (d['max'] as num).toDouble();

        final yQ1 = mapY(q1);
        final yQ3 = mapY(q3);
        final yMedian = mapY(median);
        final yMean = mapY(mean);
        final yMinVal = mapY(minVal);
        final yMaxVal = mapY(maxVal);

        final boxRect = Rect.fromLTRB(cx - itemW / 2, yQ3, cx + itemW / 2, yQ1);

        // Box Fill
        final fillPaint = Paint()
          ..color = color.withOpacity(0.20)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(3)), fillPaint);

        // Box Outline
        final outlinePaint = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
        canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(3)), outlinePaint);

        // Median Line
        final medianPaint = Paint()
          ..color = Colors.black87
          ..strokeWidth = 2.4;
        canvas.drawLine(Offset(cx - itemW / 2, yMedian), Offset(cx + itemW / 2, yMedian), medianPaint);

        // Whiskers
        final whiskerPaint = Paint()
          ..color = color
          ..strokeWidth = 1.2;
        canvas.drawLine(Offset(cx, yQ3), Offset(cx, yMaxVal), whiskerPaint);
        canvas.drawLine(Offset(cx, yQ1), Offset(cx, yMinVal), whiskerPaint);

        // Whisker caps
        final capWidth = itemW * 0.4;
        canvas.drawLine(Offset(cx - capWidth / 2, yMaxVal), Offset(cx + capWidth / 2, yMaxVal), whiskerPaint);
        canvas.drawLine(Offset(cx - capWidth / 2, yMinVal), Offset(cx + capWidth / 2, yMinVal), whiskerPaint);

        // Jittered scatter points
        final pointPaint = Paint()
          ..color = color.withOpacity(0.55)
          ..style = PaintingStyle.fill;
        final rnd = math.Random(item.groupIndex * 71 + item.clusterIndex * 13);
        for (final rv in rawVals) {
          final jitter = (rnd.nextDouble() - 0.5) * (itemW * 0.65);
          final py = mapY(rv);
          canvas.drawCircle(Offset(cx + jitter, py), 2.5, pointPaint);
        }

        // Mean indicator (triangle)
        final meanPath = Path()
          ..moveTo(cx, yMean - 5)
          ..lineTo(cx - 5, yMean + 4)
          ..lineTo(cx + 5, yMean + 4)
          ..close();
        canvas.drawPath(meanPath, Paint()..color = const Color(0xFFD32F2F));
      }
    }

    // ─── 3. DRAW X-AXIS LABELS & CLUSTER BRACKETS ────────────────
    if (clusterInfoList.isNotEmpty) {
      // Row 1: Sub-item labels (e.g. CNT (n=17), MCI (n=14))
      for (final item in plotItems) {
        final xTp = TextPainter(
          text: TextSpan(
            text: item.itemSubLabel,
            style: const TextStyle(fontSize: 8.8, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.15),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: item.width + 12);
        xTp.paint(canvas, Offset(item.cx - xTp.width / 2, marginBottom + 6));
      }

      // Row 2: Cluster Header Label & Grouping Line (e.g. Frontal, Central, Parietal...)
      for (final cluster in clusterInfoList) {
        final clusterBracketPaint = Paint()
          ..color = Colors.grey.shade400
          ..strokeWidth = 1.0;
        canvas.drawLine(
          Offset(cluster.startX, marginBottom + 24),
          Offset(cluster.endX, marginBottom + 24),
          clusterBracketPaint,
        );

        final clTp = TextPainter(
          text: TextSpan(
            text: cluster.label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79)),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();
        clTp.paint(canvas, Offset(cluster.centerX - clTp.width / 2, marginBottom + 28));
      }
    } else {
      for (final item in plotItems) {
        final xTp = TextPainter(
          text: TextSpan(
            text: item.itemSubLabel,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.15),
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: item.width + 20);
        xTp.paint(canvas, Offset(item.cx - xTp.width / 2, marginBottom + 8));
      }
    }

    // ─── 4. SIGNIFICANCE BRACKETS ──────────────────────────────
    final sigPosthocs = posthocs.where((p) => p['significant'] == true).take(4).toList();
    var bracketLevel = 0;

    for (final ph in sigPosthocs) {
      final grpA = ph['group_a'] as String;
      final grpB = ph['group_b'] as String;

      int idxA = plotItems.indexWhere((it) => it.lookupKey == grpA);
      int idxB = plotItems.indexWhere((it) => it.lookupKey == grpB);
      if (idxA < 0) {
        idxA = plotItems.indexWhere((it) => '${it.descriptive['subgroup']}|${it.descriptive['group']}' == grpA);
      }
      if (idxB < 0) {
        idxB = plotItems.indexWhere((it) => '${it.descriptive['subgroup']}|${it.descriptive['group']}' == grpB);
      }

      if (idxA < 0 || idxB < 0 || idxA == idxB) continue;
      if (idxA > idxB) {
        final t = idxA;
        idxA = idxB;
        idxB = t;
      }

      final x1 = plotItems[idxA].cx;
      final x2 = plotItems[idxB].cx;
      final bracketY = marginTop + 6 + bracketLevel * 20;

      final bracketPaint = Paint()
        ..color = const Color(0xFF16A34A)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;

      final path = Path()
        ..moveTo(x1, bracketY + 4)
        ..lineTo(x1, bracketY)
        ..lineTo(x2, bracketY)
        ..lineTo(x2, bracketY + 4);
      canvas.drawPath(path, bracketPaint);

      final pVal = (ph['p_fdr'] ?? ph['p_adj'] ?? 0.05) as double;
      final star = pVal < 0.001 ? '***' : (pVal < 0.01 ? '**' : '*');
      final starTp = TextPainter(
        text: TextSpan(
          text: star,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      starTp.paint(canvas, Offset((x1 + x2) / 2 - starTp.width / 2, bracketY - starTp.height));

      bracketLevel++;
    }

    // ─── 5. OFFSCREEN CANVAS LEGEND ─────────────────────────────
    if (showLegend) {
      var curX = marginLeft;
      final legendY = size.height - 24.0;

      if (hasSubgroups && clusterMode == GroupStatsClusterMode.bySubgroup) {
        for (var k = 0; k < orderedGroups.length; k++) {
          final g = orderedGroups[k];
          final col = _palette[k % _palette.length];
          final isH = (k % 2 == 1 && plotType == GroupStatsPlotType.barChart);

          final boxPaint = Paint()
            ..color = col.withOpacity(isH ? 0.25 : 0.40)
            ..style = PaintingStyle.fill;
          final outlineP = Paint()
            ..color = col
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4;
          final legR = Rect.fromLTWH(curX, legendY + 2, 12, 10);
          canvas.drawRect(legR, boxPaint);
          if (isH) {
            canvas.save();
            canvas.clipRect(legR);
            final hP = Paint()..color = col..strokeWidth = 1.0;
            canvas.drawLine(Offset(legR.left - 4, legR.bottom), Offset(legR.left + 8, legR.top), hP);
            canvas.drawLine(Offset(legR.left + 2, legR.bottom), Offset(legR.left + 14, legR.top), hP);
            canvas.restore();
          }
          canvas.drawRect(legR, outlineP);
          curX += 16;

          final tp = TextPainter(
            text: TextSpan(text: isH ? '$g (Hatched)' : g, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(curX, legendY));
          curX += tp.width + 16;
        }
      }

      final legendItems = (plotType == GroupStatsPlotType.barChart)
          ? [
              (Colors.black87, useSem ? 'Error Bar (±SEM)' : 'Error Bar (±SD)'),
              (Colors.black54, 'Observations (•)'),
              (const Color(0xFF16A34A), 'Sig Contrast (* p<0.05)'),
            ]
          : [
              (const Color(0xFF1F4E79), 'Box (IQR: Q1–Q3)'),
              (Colors.black87, 'Median Line (—)'),
              (const Color(0xFFD32F2F), 'Mean Marker (▲)'),
              (Colors.grey.shade600, 'Observations (•)'),
              (const Color(0xFF16A34A), 'Sig Contrast (* p<0.05)'),
            ];

      for (final item in legendItems) {
        final boxPaint = Paint()..color = item.$1;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(curX, legendY + 2, 11, 9), const Radius.circular(2)),
          boxPaint,
        );
        curX += 15;
        final tp = TextPainter(
          text: TextSpan(text: item.$2, style: TextStyle(fontSize: 9.5, color: Colors.grey.shade800)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(curX, legendY));
        curX += tp.width + 15;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoxplotPainter oldDelegate) => true;
}

/// Interactive 10-20 Scalp Topoplot widget rendered natively in Flutter.
class GroupStatsTopoplotWidget extends StatefulWidget {
  const GroupStatsTopoplotWidget({
    super.key,
    required this.etfceChannels,
    this.posthocTopoplots = const [],
  });

  final List<Map<String, dynamic>> etfceChannels;
  final List<Map<String, dynamic>> posthocTopoplots;

  /// Renders scalp topoplot to PNG image bytes offscreen.
  static Future<Uint8List> renderTopoplotImage({
    required List<Map<String, dynamic>> channels,
    required String title,
    double size = 520,
  }) async {
    final recorder = ui.PictureRecorder();
    final totalH = size + 80.0;
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, totalH));
    canvas.drawRect(Rect.fromLTWH(0, 0, size, totalH), Paint()..color = const Color(0xFFFFFFFF));

    final titleTp = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79)),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size - 32);
    titleTp.paint(canvas, Offset((size - titleTp.width) / 2, 16));

    canvas.save();
    canvas.translate(0, 44);
    final painter = _TopoplotPainter(etfceChannels: channels);
    painter.paint(canvas, Size(size, size));
    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), totalH.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  @override
  State<GroupStatsTopoplotWidget> createState() => _GroupStatsTopoplotWidgetState();
}

class _GroupStatsTopoplotWidgetState extends State<GroupStatsTopoplotWidget> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.etfceChannels.isEmpty && widget.posthocTopoplots.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('No spatial channel data available.')));
    }

    final hasPostHocs = widget.posthocTopoplots.isNotEmpty;
    final List<Map<String, dynamic>> activeChannels;
    final String currentTitle;

    if (_selectedIndex == 0 || !hasPostHocs || _selectedIndex > widget.posthocTopoplots.length) {
      activeChannels = widget.etfceChannels;
      currentTitle = 'Omnibus / Spatial eTFCE Cluster Map (* p<0.05)';
    } else {
      final pair = widget.posthocTopoplots[_selectedIndex - 1];
      activeChannels = (pair['channels'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      currentTitle = 'Post-Hoc Contrast: ${pair['contrast']} (* p<0.05)';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = math.min(constraints.maxWidth, 360.0);
        return Center(
          child: Column(
            children: [
              if (hasPostHocs) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Omnibus eTFCE Map', style: TextStyle(fontSize: 11)),
                      selected: _selectedIndex == 0,
                      onSelected: (v) => setState(() => _selectedIndex = 0),
                    ),
                    for (var i = 0; i < widget.posthocTopoplots.length; i++)
                      ChoiceChip(
                        label: Text('Post-Hoc: ${widget.posthocTopoplots[i]['contrast']}', style: const TextStyle(fontSize: 11)),
                        selected: _selectedIndex == i + 1,
                        onSelected: (v) => setState(() => _selectedIndex = i + 1),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Text(
                currentTitle,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1F4E79)),
              ),
              const SizedBox(height: 8),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
                  ],
                ),
                child: CustomPaint(
                  size: Size(size, size),
                  painter: _TopoplotPainter(etfceChannels: activeChannels),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFFD32F2F), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('Positive Difference (+Δ)', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 14, decoration: const BoxDecoration(color: Color(0xFF1F4E79), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text('Negative Difference (-Δ)', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF59E0B), width: 3),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Significant Channel (* p<0.05)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopoplotPainter extends CustomPainter {
  _TopoplotPainter({required this.etfceChannels});

  final List<Map<String, dynamic>> etfceChannels;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.40;

    // Head outline circle
    final headPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, headPaint);

    // Nose
    final nosePath = Path()
      ..moveTo(center.dx - 12, center.dy - radius + 2)
      ..lineTo(center.dx, center.dy - radius - 14)
      ..lineTo(center.dx + 12, center.dy - radius + 2);
    canvas.drawPath(nosePath, headPaint);

    // Ears
    final leftEar = Rect.fromCenter(center: Offset(center.dx - radius - 3, center.dy), width: 8, height: 26);
    final rightEar = Rect.fromCenter(center: Offset(center.dx + radius + 3, center.dy), width: 8, height: 26);
    canvas.drawOval(leftEar, headPaint);
    canvas.drawOval(rightEar, headPaint);

    // Find min and max t-stat
    var maxAbsT = 1.0;
    for (final ch in etfceChannels) {
      final t = ((ch['t_stat'] ?? 0.0) as num).abs().toDouble();
      if (t > maxAbsT) maxAbsT = t;
    }

    // Channel values map
    final chanMap = {
      for (final ch in etfceChannels)
        (ch['channel'] as String).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), ''): ch
    };

    for (final entry in kElectrode1020Positions.entries) {
      final normName = entry.key.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final chData = chanMap[normName];

      final nx = entry.value.$1;
      final ny = entry.value.$2;

      // Map to canvas coordinates
      final px = center.dx + nx * radius * 0.92;
      final py = center.dy - ny * radius * 0.92;

      final tVal = chData != null ? ((chData['t_stat'] ?? 0.0) as num).toDouble() : 0.0;
      final isSig = chData != null && chData['significant'] == true;

      Color color;
      if (tVal > 0) {
        final frac = (tVal / maxAbsT).clamp(0.1, 1.0);
        color = Color.lerp(Colors.orange.shade200, const Color(0xFFD32F2F), frac)!;
      } else if (tVal < 0) {
        final frac = (tVal.abs() / maxAbsT).clamp(0.1, 1.0);
        color = Color.lerp(Colors.blue.shade200, const Color(0xFF1F4E79), frac)!;
      } else {
        color = Colors.grey.shade300;
      }

      // Outer highlight ring for significant channels
      if (isSig) {
        final sigRingPaint = Paint()
          ..color = const Color(0xFFF59E0B)
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(Offset(px, py), 15.0, sigRingPaint);
      }

      // Electrode disc
      canvas.drawCircle(Offset(px, py), 11.0, Paint()..color = color);
      canvas.drawCircle(Offset(px, py), 11.0, Paint()..color = Colors.black54..style = PaintingStyle.stroke..strokeWidth = 1.0);

      // Electrode name label
      final tp = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, py - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _TopoplotPainter oldDelegate) => true;
}
