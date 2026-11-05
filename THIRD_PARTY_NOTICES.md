# Third-party notices

CCS Sleep Studio itself is released under the [MIT licence](LICENSE). It builds on, ports, re-implements, or bundles the third-party open-source work listed below.

## Ported Algorithms and Code

| Item | Where used | Upstream | Licence | Attribution & Notes |
|:---|:---|:---|:---|:---|
| **NeuroLoopGain 2.x** (Kemp & Roessen) | `analyseNidra/src/nlg.rs` | https://github.com/NeuroloopGain/neuroloopgain | Apache-2.0 | Full notice preserved in `analyseNidra/THIRD_PARTY_NeuroLoopGain.md`. Port of C# reference implementation. |
| **YASA** (spindle, slow-wave detection, LightGBM stager, filters) | `analyseNidra/src/events.rs`, `staging/yasa.rs`, `assets/models/yasa/` | https://github.com/raphaelvallat/yasa | BSD-3-Clause | Copyright (c) 2018-2024 Raphael Vallat. Algorithms ported with exact sample-boundary parity. |
| **ScoringHero** (UI concepts, scoring JSON schema, display filter architecture) | `frontend/`, `bridge/`, `docs/PORTING_PLAN.md` | https://github.com/SvennoNito/ScoringHero | MIT | Copyright (c) 2024 Svenno Nito. UI layout and sidecar architecture inspired by ScoringHero. |
| **Luna POPS** stager (`s2` model and feature extraction) | `analyseNidra/src/staging/pops.rs`, `assets/models/pops/` | https://zzz.nyspi.org/luna/ | GPL-2.0 | Copyright (c) Shaun Purcell, Broad Institute / Brigham and Women's Hospital. |
| **TensorPAC** (modulation index & PAC reference) | `analyseNidra/src/pac.rs` | https://github.com/EtienneCmb/tensorpac | BSD-3-Clause | Copyright (c) 2017-2020 Etienne Combrisson. Reference implementation for modulation index calculations. |
| **FOOOF / specparam, IRASA** | `analyseNidra/src/spectral.rs` | https://github.com/fooof-tools/fooof | Apache-2.0 | Copyright (c) 2014-2020 VoytekLab. Native Rust Levenberg-Marquardt re-implementation; no original source code copied. |
| **MNE-Python** (FIR filter design and FFT resampling) | `analyseNidra/src/signal.rs` | https://github.com/mne-tools/mne-python | BSD-3-Clause | Copyright (c) 2011-2024 MNE Developers. Reference implementation for filter windowing and sample rate conversion. |
| **ACCS sleep-stage analyser** (MATLAB, NIMHANS) | `analyseNidra/src/accs.rs` | Local research code | MIT | Developed at Centre for Consciousness Studies, Department of Neurophysiology, NIMHANS. Licensed under MIT under this project. |

## Bundled Pretrained Staging Models (`analyseNidra/assets/models/`)

| Model | Upstream Architecture / Checkpoint | Licence | Description & Redistribution Terms |
|:---|:---|:---|:---|
| **YASA Classifiers** (`clf_*_lgb_0.5.0.json`) | https://github.com/raphaelvallat/yasa | BSD-3-Clause | Lightweight LightGBM decision tree ensembles for consensus sleep staging. |
| **SleepGPT** (`model.onnx`) | https://github.com/yuty2009/sleepgpt | Apache-2.0 | Copyright (c) 2024 Tianyou Yu et al. Sequence refinement model converted to ONNX. |
| **GSSC** (Greifswald Sleep Stage Classifier) | https://github.com/jshanna100/gssc | MIT | Copyright (c) 2023 Jevri Hanna & Agnes Flöel. Clinical CNN sleep stager converted to ONNX. |
| **U-Sleep** (Braindecode checkpoint) | https://github.com/braindecode/braindecode | BSD-3-Clause | Mathias Perslev et al. (2021). Deep 1D fully-convolutional segmentation network. |
| **TinySleepNet** (`model.onnx`, `psg_model.onnx`) | https://github.com/akaraspt/tinysleepnet | Apache-2.0 | Copyright (c) 2020 Akara Supratak. Compact temporal recurrent neural network. |
| **SeqSleepNet & SleepTransformer** (PhysioEx) | https://github.com/guidogagl/physioex | MIT | Copyright (c) 2023-2024 Guido Gagliardi. Pretrained sequence-to-sequence and self-attention transformer models. |
| **Luna POPS** (`s2` features & weights) | https://zzz.nyspi.org/luna/ | GPL-2.0 | Shaun Purcell. Multi-feature probabilistic sleep stager. |

Converted and re-exported weights are derivative works of the upstream trained models. Upstream licenses and attributions are preserved in accompanying asset metadata.

## Software Libraries & Dependencies

- **Rust compute core:** Cargo dependencies are documented in `bridge/Cargo.lock` and `analyseNidra/Cargo.lock`. All packages use permissive open-source licenses (MIT, Apache-2.0, BSD-2/3-Clause).
- **Dart / Flutter UI:** Managed in `frontend/pubspec.lock`.
- **Multimedia (`media_kit` / `libmpv`):** Video playback utilizes `media_kit`, which links dynamically against system `libmpv` (LGPL-2.1+ / GPL-2.0+ depending on distributor configuration).

## Sample Data

See [`SamplePSGData/README.md`](SamplePSGData/README.md).
