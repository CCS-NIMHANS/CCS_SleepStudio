# Sample PSG Data

A demonstration dataset for testing multi-channel polysomnography visualization, manual-scoring import, batch pipelines, scoring comparison, and AnalyseNidra report generation.

## Contents

| Path | Description |
|:---|:---|
| `Data/AS_CNT_08_Night1.edf`, `AS_CNT_08_Night2.edf` | Overnight PSG recordings, participant AS_CNT_08, two consecutive nights (EDF) |
| `Data/AS_CNT_10_Night1.edf`, `AS_CNT_10_Night2.edf` | Overnight PSG recordings, participant AS_CNT_10, two consecutive nights (EDF) |
| `ManualScorings/*.edf` | Clinical consensus sleep-stage scorings with matching base filenames (EDF+ Annotations) |
| `Template_config.json` | Reusable configuration template for montage display, scale, and filter preferences |

## How to Use

1. Load any recording from `Data/` via **File > Load EEG Recording**.
2. Import the matching file from `ManualScorings/` via **File > Load Scoring File** or **Compare > Import scoring for comparison**.
3. These recordings provide reference benchmarks for parity verification against reference implementations (NeuroLoopGain, sleep-cycle dynamics, YASA spindle and slow-wave detection).

## Provenance, Consent & Licence

- **Institutional Source:** Data acquired at the Centre for Consciousness Studies (CCS), Department of Neurophysiology, National Institute of Mental Health and Neurosciences (NIMHANS), Bengaluru, India.
- **Ethics & Consent:** Conducted with institutional ethics committee approval and written informed consent from participants permitting the open academic sharing of de-identified electrophysiological data.
- **De-identification:** All European Data Format (EDF) headers have undergone rigorous de-identification. Patient names, subject IDs, dates of birth, institutional hospital identifiers, and absolute recording dates have been stripped or pseudonymized.
- **Hardware & Montages:** Recorded at 200–256 Hz sampling rates using standardized scalp electrode placement (10-20 system: F3, F4, C3, C4, O1, O2 referenced to contralateral mastoids M1/M2), dual-channel electrooculography (LOC, ROC), and submental EMG.
- **Scoring Standard:** Scored epoch-by-epoch (30-second epochs) into Wake, N1, N2, N3, and REM in accordance with the American Academy of Sleep Medicine (AASM) Manual for the Scoring of Sleep and Associated Events.
- **Data Licence:** Distributed under the [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/) license. (Software code remains under the MIT License).

If you use these demonstration recordings in research or publications, please cite CCS Sleep Studio as described in [`CITATION.cff`](../CITATION.cff).
