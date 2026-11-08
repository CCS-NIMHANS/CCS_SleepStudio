import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ccs_sleep_studio/src/group_statistics_engine.dart';

void main() {
  test('GroupStatsEngine inspects CSV and computes statistical models in pure Dart', () async {
    final csvPath = Platform.environment['CCS_TEST_MASTER_CSV'] ?? '';
    if (csvPath.isEmpty || !File(csvPath).existsSync()) return;

    final insp = await GroupStatsEngine.inspectDataset(csvPath: csvPath);
    expect(insp['total_rows'], greaterThan(0));
    expect(insp['group_col'], isNotNull);
    expect(insp['channel_col'], 'Chan');

    final results = await GroupStatsEngine.runAnalysis(
      csvPath: csvPath,
      groupCol: 'ageID',
      subgroupCol: 'Status',
      channelCol: 'Chan',
      subjectIdCol: insp['subject_id'],
      targetMetrics: ['CAP_rate', 'N3_Gamma_Irasa'],
    );

    expect(results['output_dir'], isNotNull);
    final resList = results['results'] as List<dynamic>;
    expect(resList.length, 2);

    final capRes = resList.firstWhere((r) => r['metric'] == 'CAP_rate');
    expect(capRes['is_macroarchitecture'], isTrue);
    final capEffects = capRes['model_effects'] as List<dynamic>;
    expect(capEffects.any((e) => e['term'] == 'ageID'), isTrue);
    expect(capEffects.any((e) => e['term'] == 'Status'), isTrue);

    final gammaRes = resList.firstWhere((r) => r['metric'] == 'N3_Gamma_Irasa');
    expect(gammaRes['is_macroarchitecture'], isFalse);
    expect(gammaRes['etfce_channels'], isNotEmpty);
  });

  test('GroupStatsEngine row filters correctly apply substring contains, include, and exclude rules', () async {
    final tempDir = Directory.systemTemp.createTempSync('stats_test_');
    final csvFile = File('${tempDir.path}/test_sheet.csv');
    await csvFile.writeAsString('''source_file,Subject Identifier,groupID,Chan,TST,sw_Count
CNT_01_nap.csv,Subj1,CNT,Central,120.0,45
CNT_02_nap.csv,Subj2,CNT,Frontal,115.0,40
MCI_01_nap.csv,Subj3,MCI,Central,90.0,20
MCI_02_nap.csv,Subj4,MCI,Frontal,85.0,15
''');

    // 1. Test exclude_contains on filename containing MCI
    final resExcludeMci = await GroupStatsEngine.runAnalysis(
      csvPath: csvFile.path,
      groupCol: 'groupID',
      targetMetrics: ['TST'],
      rowFilters: [
        {'column': 'source_file', 'op': 'exclude_contains', 'value': 'MCI'},
      ],
    );
    final resultsExclude = (resExcludeMci['results'] as List<dynamic>).first;
    expect(resultsExclude['n_obs'], 2); // only CNT rows remain
    final descExclude = (resultsExclude['descriptives'] as List<dynamic>).cast<Map<String, dynamic>>();
    expect(descExclude.any((d) => d['group'] == 'MCI'), isFalse);
    expect(descExclude.any((d) => d['group'] == 'CNT'), isTrue);

    // 2. Test include_eq on Chan == Central
    final resIncludeCentral = await GroupStatsEngine.runAnalysis(
      csvPath: csvFile.path,
      groupCol: 'groupID',
      targetMetrics: ['TST'],
      rowFilters: [
        {'column': 'Chan', 'op': 'include_eq', 'value': 'Central'},
      ],
    );
    final resultsCentral = (resIncludeCentral['results'] as List<dynamic>).first;
    expect(resultsCentral['n_obs'], 2); // only Central rows remain

    // 3. Test include_contains on filename containing CNT (case-insensitive)
    final resIncludeCnt = await GroupStatsEngine.runAnalysis(
      csvPath: csvFile.path,
      groupCol: 'groupID',
      targetMetrics: ['TST'],
      rowFilters: [
        {'column': 'source_file', 'op': 'include_contains', 'value': 'cnt'},
      ],
    );
    final resultsCnt = (resIncludeCnt['results'] as List<dynamic>).first;
    expect(resultsCnt['n_obs'], 2);

    // 4. Test interactive column value exclusion via excludedFactorLabels
    final resExcludedLabels = await GroupStatsEngine.runAnalysis(
      csvPath: csvFile.path,
      groupCol: 'groupID',
      targetMetrics: ['TST'],
      excludedFactorLabels: {
        'source_file': ['MCI_01_nap.csv', 'MCI_02_nap.csv'],
      },
    );
    final resultsExcludedLabels = (resExcludedLabels['results'] as List<dynamic>).first;
    expect(resultsExcludedLabels['n_obs'], 2);

    tempDir.deleteSync(recursive: true);
  });

  test('GroupStatsEngine supports 4+ factors in multi-factor ANOVA with interaction effects', () async {
    final tempDir = Directory.systemTemp.createTempSync('multi_factor_test_');
    final csvFile = File('${tempDir.path}/test_multi_factor.csv');
    await csvFile.writeAsString('''Subject,Cohort,Condition,Sex,Session,MetricVal
S1,YNG,Nap,M,Pre,10.0
S2,YNG,Nap,F,Pre,12.0
S3,YNG,Nap,M,Post,15.0
S4,YNG,Nap,F,Post,18.0
S5,OLD,Nap,M,Pre,8.0
S6,OLD,Nap,F,Pre,9.0
S7,OLD,Nap,M,Post,11.0
S8,OLD,Nap,F,Post,12.0
S9,YNG,Rest,M,Pre,6.0
S10,YNG,Rest,F,Pre,7.0
S11,YNG,Rest,M,Post,8.0
S12,YNG,Rest,F,Post,9.0
S13,OLD,Rest,M,Pre,4.0
S14,OLD,Rest,F,Pre,5.0
S15,OLD,Rest,M,Post,5.5
S16,OLD,Rest,F,Post,6.0
''');

    final res = await GroupStatsEngine.runAnalysis(
      csvPath: csvFile.path,
      groupCol: 'Cohort',
      subgroupCol: 'Condition',
      extraFactors: ['Sex', 'Session'],
      subjectIdCol: 'Subject',
      includeInteractions: true,
      targetMetrics: ['MetricVal'],
    );

    final resMetric = (res['results'] as List<dynamic>).first;
    expect(resMetric['model_type'], contains('Multi-Factor'));
    final effects = (resMetric['model_effects'] as List<dynamic>).cast<Map<String, dynamic>>();

    // Check all 4 factors appear in model effects
    expect(effects.any((e) => e['term'] == 'Cohort'), isTrue);
    expect(effects.any((e) => e['term'] == 'Condition'), isTrue);
    expect(effects.any((e) => e['term'] == 'Sex'), isTrue);
    expect(effects.any((e) => e['term'] == 'Session'), isTrue);

    // Check interactions
    expect(effects.any((e) => e['term'] == 'Cohort × Condition'), isTrue);
    expect(effects.any((e) => e['term'] == 'Cohort × Sex'), isTrue);
    expect(effects.any((e) => e['term'] == 'Cohort × Session'), isTrue);

    tempDir.deleteSync(recursive: true);
  });

  test('GroupStatsEngine handles macro metrics and channel selection correctly', () async {
    // 1. Verify macro metric detection for N2_duration_min and other staging metrics
    expect(GroupStatsEngine.isMacroMetric('N2_duration_min'), isTrue);
    expect(GroupStatsEngine.isMacroMetric('N1_duration'), isTrue);
    expect(GroupStatsEngine.isMacroMetric('N3_duration'), isTrue);
    expect(GroupStatsEngine.isMacroMetric('W_duration'), isTrue);
    expect(GroupStatsEngine.isMacroMetric('R_percentage'), isTrue);
    expect(GroupStatsEngine.isMacroMetric('TST'), isTrue);
    expect(GroupStatsEngine.isMacroMetric('WASO'), isTrue);
    expect(GroupStatsEngine.isMacroMetric('sp_Count'), isFalse);
    expect(GroupStatsEngine.isMacroMetric('N3_Sigma_PSD'), isFalse);

    final tempDir = Directory.systemTemp.createTempSync('macro_chan_test_');
    final csvFile = File('${tempDir.path}/test_macro_channels.csv');
    // 2 subjects, 3 channels each (Central, Frontal, Occipital) = 6 rows total
    await csvFile.writeAsString('''source_file,Subject,Cohort,Chan,N2_duration_min,sp_Count
file1.edf,S1,Ctrl,Central,35.0,20
file1.edf,S1,Ctrl,Frontal,35.0,30
file1.edf,S1,Ctrl,Occipital,35.0,15
file2.edf,S2,Stim,Central,45.0,25
file2.edf,S2,Stim,Frontal,45.0,35
file2.edf,S2,Stim,Occipital,45.0,18
''');

    // 2. Test auto-deduplication for macro metrics: 6 rows should deduplicate to 2 observations
    final resAuto = await GroupStatsEngine.runAnalysis(
      csvPath: csvFile.path,
      groupCol: 'Cohort',
      channelCol: 'Chan',
      subjectIdCol: 'Subject',
      targetMetrics: ['N2_duration_min', 'sp_Count'],
      macroChannel: 'auto',
    );

    final resList = resAuto['results'] as List<dynamic>;
    final n2Auto = resList.firstWhere((r) => r['metric'] == 'N2_duration_min');
    expect(n2Auto['is_macroarchitecture'], isTrue);
    expect(n2Auto['n_obs'], 2); // exactly 2 subjects, not 6!

    final spAuto = resList.firstWhere((r) => r['metric'] == 'sp_Count');
    expect(spAuto['is_macroarchitecture'], isFalse);
    expect(spAuto['n_obs'], 6); // channel-dependent metric keeps all 6 observations

    // 3. Test explicit macroChannel selection (e.g. 'Central')
    final resCentral = await GroupStatsEngine.runAnalysis(
      csvPath: csvFile.path,
      groupCol: 'Cohort',
      channelCol: 'Chan',
      subjectIdCol: 'Subject',
      targetMetrics: ['N2_duration_min'],
      macroChannel: 'Central',
    );
    final n2Central = (resCentral['results'] as List<dynamic>).first;
    expect(n2Central['n_obs'], 2);

    tempDir.deleteSync(recursive: true);
  });
}
