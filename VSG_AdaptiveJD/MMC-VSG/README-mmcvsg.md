# MMC-VSG verification model

Supplementary model for Section 5.6 of the manuscript. It reproduces the switching-level
verification: the same metric-shaping law applied to the active-power loop of a 6.6 kV/1 MVA
modular multilevel converter.

## Requirements

- MATLAB R2023b with Simulink, Simscape Electrical and Stateflow.
  Stateflow is needed only because the adaptive law is entered through a MATLAB Function
  block; no Stateflow chart is used.
- The model was saved with R2023b.

## Files

| File | Role |
| --- | --- |
| `MMC_30_VSG_AD.slx` | Model: 30 submodules per arm, NLM modulation, dq current loop, circulating-current suppression, VSG outer loop with the adaptive law inserted |
| `build_mmc_ad.m` | Regenerates the modified model from a copy of the original; also re-parameterises it (scheme 1 = fixed, 5 = proposed) |
| `run_mmc_ad.m` | Runs one case, records waveforms, writes `res_<tag>.mat` |
| `plot_mmc.py` | Produces `fig_mmc_response.png/pdf` and `fig_mmc_internal.png/pdf` |
| `res_msca.mat`, `res_fixed.mat` | Waveforms of the two cases (already included, so the figures can be replotted without re-simulating) |
| `fig_mmc_response.*` | Frequency deviation, active power, J, D |
| `fig_mmc_internal.*` | Capacitor voltage mean, module-to-module spread, circulating current |

## How to run

```matlab
cd <this folder>
build_mmc_ad(5);  run_mmc_ad('msca');    % proposed law  (~13 min)
build_mmc_ad(1);  run_mmc_ad('fixed');   % fixed parameters (~11 min)
```

Then, from a shell:

```bash
python plot_mmc.py
```

`build_mmc_ad` must be called before each case because it rewrites the model's `InitFcn`
(which carries the scheme index). Both runs use a 1.0 → 1.1 MW step at t = 1.3 s.

## What was changed with respect to the original model

Only the VSG active-power loop. The two gains that carried `1/J` and `D` were replaced by
signal inputs, and a MATLAB Function block computes `J` and `D` from the measured speed
deviation. Modulation, current control and circulating-current suppression are untouched.

The original model uses `J = 4.5`, `D = 850`, which places the power loop at ω_n ≈ 100 rad/s.
For the verification the metric references of the paper are imposed instead (ω_n0 = 14.14
rad/s, ζ₀ = 0.707), which gives `J = 223.6`, `D = 4472` in the units of this model, i.e. an
inertia constant of 10.5 s. `build_mmc_ad` sets these values in `InitFcn`.

Note that this model writes the swing equation in torque form,
`J dω/dt = [(P_ref − k_f Δω − P_e)/ω₀] − D Δω`, so its `J` and `D` are the paper's `J_p` and
`D_p` divided by ω₀. The ratio λ = D/(2J) is unaffected.

## Expected results

| Quantity | Fixed (S1) | Proposed |
| --- | --- | --- |
| Peak frequency deviation | 9.06 mHz | 6.54 mHz |
| Time to peak | 0.127 s | 0.111 s |
| Peak RoCoF (5 ms smoothed) | 0.209 Hz/s | 0.249 Hz/s |
| J range | 223.6 (constant) | 114.4–298.3 |

Capacitor-voltage behaviour and circulating current are essentially identical between the two
cases; that is the point of the verification.
