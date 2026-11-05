import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ccs_sleep_studio/src/mat_loader.dart';

void main() {
  test('loads ScoringHero EEGLAB v5 MAT example when available', () {
    final customPath = Platform.environment['SCORINGHERO_EXAMPLE_MAT'] ?? '';
    final file = File(customPath);
    if (!file.existsSync()) {
      return;
    }

    final loaded = MatLoader().load(file.path);

    expect(loaded.channelLabels.first, 'F3-A2');
    expect(loaded.sampleRateHz, 125);
    expect(loaded.channelSamples, hasLength(9));
    expect(loaded.channelSamples.first, hasLength(2877448));
  });
}
