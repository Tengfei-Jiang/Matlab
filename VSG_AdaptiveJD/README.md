# Supplementary material — Simulink model

Companion model for the manuscript **"Metric-Shaping Coordinated Adaptive Control
of Inertia and Damping for Virtual Synchronous Generators"**.

The model implements the reduced-order swing equation used throughout the paper
(synchronous power coefficient Kδ = 3EUp/X). It contains no switching-level
circuit, so each simulated trajectory can be compared point by point with the
values reported in the figures.

## Requirements

- MATLAB R2023b with Simulink. No additional toolbox is required to **run** the model.
- The model is provided as a saved `.slx` file; no model-building script is included,
  because none is needed to reproduce the results. The file was saved with R2023b:
  opening it in a newer release prompts to resave, and a substantially older release
  may not open it. Please contact the authors if a different release is required.

## Contents

| File | Role | Needed to run |
| --- | --- | --- |
| `VSG_AdaptiveJD.slx` | Top level plus four subsystems | yes |
| `init_vsg_params.m` | Parameters, case excitations, calibration constants | yes |
| `noise_raw.mat` | Gaussian drive sequence for Case 3 | Case 3 only |
| `run_vsg_slx.m` | Batch run: 3 cases × 5 schemes, computes all metrics | to reproduce tables |
| `plot_vsg_slx.m` | Redraws Figs. 6, 8, 9 and 10 from the batch results | to reproduce figures |
| `slx_metrics.json` | Metrics produced by `run_vsg_slx.m` | reference output |
| `make_noise_data.py` | Regenerates `noise_raw.mat` (needs NumPy/SciPy) | optional |

## Quick start

Change the MATLAB working directory to this folder, then:

```matlab
run_vsg_slx        % 15 simulations, about 1 min; writes slx_results.mat + slx_metrics.json
plot_vsg_slx       % writes figs_slx/*.png and *.pdf
```

`plot_vsg_slx` reads `slx_results.mat`, so it must be called after `run_vsg_slx`.

A single case can be run without the batch script:

```matlab
init_vsg_params('case2', 5);   % case name, scheme number
out = sim('VSG_AdaptiveJD');
y   = out.yout;                % columns: delta, omega, Pe, J, D_Sigma, zeta_Sigma
t   = y.Time;
```

The model initialization callback calls `init_vsg_params(VSG_CASE, VSG_SCHEME)`
at the start of every simulation. `init_vsg_params` writes both variables back to
the base workspace, so a case selected by a direct call is not overridden.

## Cases and schemes

| Case | Excitation | Corresponding figure |
| --- | --- | --- |
| `case1` | Grid frequency drop to 49.8 Hz for t ∈ [1, 2) s; P_ref = 25 kW | Fig. 6 |
| `case2` | Power reference steps 25 → 30 → 20 kW at t = 1 s and 2 s | Figs. 8, 9 |
| `case3` | Same as Case 2 with band-limited measurement noise, σω = 0.2 rad/s | Fig. 10 |

| Scheme | Rule | Label in figures |
| --- | --- | --- |
| 1 | Fixed parameters (baseline) | Fixed |
| 2 | Exponential J–D coupling | Wen |
| 3 | Arctangent smoothing with inertia reduction on recovery | Wang |
| 4 | Piecewise scheduling of J, D and droop | Ban |
| 5 | Closed-loop metric shaping (proposed) | MSCA |

## Numerical settings

Fixed-step ode4 solver with Ts = 2×10⁻⁴ s. The adaptive law is executed through a
zero-order hold at the same rate, and J and D are updated once per step — the
same discretization as the reference implementation used to produce the tables.
The constraint layer enforces J ∈ [0.3J0, 2J0], DΣ ∈ [0.3DΣ0, 2.2DΣ0] and
|dJ/dt| ≤ μJ, with D = max(DΣ − Kω, 0).

## Reference output

`slx_metrics.json` was produced by `run_vsg_slx.m`. For the proposed scheme:

| Case | σ% (each step) | ts (s) | RoCoF (Hz/s) | \|Δf\|max (Hz) | Φ_J |
| --- | --- | --- | --- | --- | --- |
| Case 1 | 60.10 / 28.22 | 0.388 / 0.273 | 2.96 | 0.218 | 1.08 |
| Case 2 | 3.58 / 1.26 | 0.420 / 0.269 | 1.72 | 0.050 | 0.73 |
| Case 3 | 3.38 / 3.10 | 0.429 / 0.430 | 1.72 | 0.049 | 5.85 |

A quick sanity check after a fresh run: in Case 1 the active power settles at
about 31.7 kW during the frequency dip (primary-frequency support of KωΔω ≈ 6.7 kW)
and returns to 25 kW afterwards; in Case 2 it settles at 30 kW and 20 kW.

## Note on Case 3

The measurement-noise sequence is supplied as `noise_raw.mat` so that Case 3 is
reproducible on any machine: MATLAB and NumPy use different random generators,
so a random-number block seeded with the same integer would not reproduce the
paper. If the file is missing, `init_vsg_params` issues a warning and falls back
to `randn`, in which case the Case 3 statistics differ slightly while Cases 1
and 2 remain unaffected.

The 4 ms first-order (AR(1)) shaping filter is kept inside the model
(`Controller/Noise`), so the supplied file only contains the raw Gaussian sequence.
