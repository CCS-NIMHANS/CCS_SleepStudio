import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ccs_sleep_studio/src/group_statistics.dart';
import 'package:ccs_sleep_studio/src/group_statistics_engine.dart';
import 'package:ccs_sleep_studio/src/group_statistics_plots.dart';

void main() {
  testWidgets('renders GroupStatisticsWorkbench shell properly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupStatisticsWorkbench(),
          ),
        ),
      ),
    );

    expect(find.text('Group-Level Statistical Analysis & Publishing Workbench'), findsOneWidget);
    expect(find.text('Data Source'), findsOneWidget);
    expect(find.text('Batch Analysis Master Sheet (CSV)'), findsOneWidget);
    expect(find.text('Inspect Data'), findsOneWidget);
  });

  test('GroupStatsEngine inspects master sheet in pure Dart without Python', () async {
    final csv1 = Platform.environment['CCS_TEST_MASTER_CSV_MED'] ?? '';
    final file = File(csv1);
    final String testPath;
    if (csv1.isNotEmpty && file.existsSync()) {
      testPath = csv1;
    } else {
      final tmp = File('${Directory.systemTemp.path}/test_group_stats.csv');
      tmp.writeAsStringSync('''subject,group,channel,alpha_power
s1,Ctrl,C3,10.5
s2,Ctrl,C3,11.2
s3,Stim,C3,15.8
s4,Stim,C3,16.2
''');
      testPath = tmp.path;
    }

    final inspection = await GroupStatsEngine.inspectDataset(csvPath: testPath);
    expect(inspection['total_rows'], greaterThan(0));
    expect(inspection['unique_subjects'], greaterThan(0));
    expect(inspection['metric_columns'], isNotEmpty);
  });

  testWidgets('GroupStatsBoxplotWidget renders grouped bar chart and boxplot with cluster modes', (tester) async {
    final sampleDescriptives = [
      {'group': 'CNT', 'subgroup': 'Frontal', 'n': 17, 'mean': 1.25, 'std': 0.35, 'sem': 0.08, 'median': 1.22, 'q1': 1.05, 'q3': 1.45, 'min': 0.65, 'max': 1.95, 'raw_values': [1.1, 1.2, 1.3, 1.4]},
      {'group': 'MCI', 'subgroup': 'Frontal', 'n': 14, 'mean': 1.10, 'std': 0.30, 'sem': 0.08, 'median': 1.08, 'q1': 0.95, 'q3': 1.28, 'min': 0.55, 'max': 1.75, 'raw_values': [1.0, 1.1, 1.2]},
      {'group': 'CNT', 'subgroup': 'Central', 'n': 17, 'mean': 1.60, 'std': 0.40, 'sem': 0.09, 'median': 1.58, 'q1': 1.35, 'q3': 1.85, 'min': 0.85, 'max': 2.35, 'raw_values': [1.5, 1.6, 1.7]},
      {'group': 'MCI', 'subgroup': 'Central', 'n': 14, 'mean': 1.45, 'std': 0.38, 'sem': 0.10, 'median': 1.42, 'q1': 1.20, 'q3': 1.70, 'min': 0.75, 'max': 2.15, 'raw_values': [1.4, 1.5]},
    ];
    final samplePosthocs = [
      {'group_a': 'CNT|Frontal', 'group_b': 'MCI|Frontal', 'significant': true, 'p_fdr': 0.02},
    ];

    // 1. Grouped Bar Chart clustered by Region (Snapshot 1)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupStatsBoxplotWidget(
              metric: 'sp_density',
              unit: 'sp/min',
              descriptives: sampleDescriptives,
              posthocs: samplePosthocs,
              plotType: GroupStatsPlotType.barChart,
              clusterMode: GroupStatsClusterMode.bySubgroup,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('CNT'), findsOneWidget);
    expect(find.text('MCI (Hatched)'), findsOneWidget);
    expect(find.text('Error Bar (±SEM)'), findsOneWidget);

    // 2. Boxplot clustered by Cohort (Snapshot 2)
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GroupStatsBoxplotWidget(
              metric: 'sp_density',
              unit: 'sp/min',
              descriptives: sampleDescriptives,
              posthocs: samplePosthocs,
              plotType: GroupStatsPlotType.boxplot,
              clusterMode: GroupStatsClusterMode.byGroup,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Box (IQR: Q1–Q3)'), findsOneWidget);
    expect(find.text('Median Line (—)'), findsOneWidget);
  });

  test('GroupStatsBoxplotWidget.renderPlotImage produces valid PNG bytes for bar chart and boxplot', () async {
    final sampleDescriptives = [
      {'group': 'CNT', 'subgroup': 'Frontal', 'n': 17, 'mean': 1.25, 'std': 0.35, 'sem': 0.08, 'median': 1.22, 'q1': 1.05, 'q3': 1.45, 'min': 0.65, 'max': 1.95, 'raw_values': [1.1, 1.2, 1.3]},
      {'group': 'MCI', 'subgroup': 'Frontal', 'n': 14, 'mean': 1.10, 'std': 0.30, 'sem': 0.08, 'median': 1.08, 'q1': 0.95, 'q3': 1.28, 'min': 0.55, 'max': 1.75, 'raw_values': [1.0, 1.1, 1.2]},
    ];
    final samplePosthocs = [
      {'group_a': 'CNT|Frontal', 'group_b': 'MCI|Frontal', 'significant': true, 'p_fdr': 0.03},
    ];

    // Bar Chart bytes
    final barBytes = await GroupStatsBoxplotWidget.renderPlotImage(
      descriptives: sampleDescriptives,
      posthocs: samplePosthocs,
      metric: 'sp_density',
      plotType: GroupStatsPlotType.barChart,
      clusterMode: GroupStatsClusterMode.bySubgroup,
    );
    expect(barBytes, isNotEmpty);
    // Verify PNG magic header: 0x89 0x50 0x4E 0x47
    expect(barBytes[0], 0x89);
    expect(barBytes[1], 0x50);
    expect(barBytes[2], 0x4E);
    expect(barBytes[3], 0x47);

    // Boxplot bytes
    final boxBytes = await GroupStatsBoxplotWidget.renderPlotImage(
      descriptives: sampleDescriptives,
      posthocs: samplePosthocs,
      metric: 'sp_density',
      plotType: GroupStatsPlotType.boxplot,
      clusterMode: GroupStatsClusterMode.bySubgroup,
    );
    expect(boxBytes, isNotEmpty);
    expect(boxBytes[0], 0x89);
    expect(boxBytes[1], 0x50);
    expect(boxBytes[2], 0x4E);
    expect(boxBytes[3], 0x47);
  });
}
