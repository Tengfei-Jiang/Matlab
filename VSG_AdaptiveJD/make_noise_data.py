

import os

import numpy as np
from scipy.io import savemat

HERE = os.path.dirname(os.path.abspath(__file__))

DT = 2e-4
TSIM = 4.0
SEED = 7
TAU_N = 4e-3

N = int(round(TSIM / DT))
rng = np.random.default_rng(SEED)
raw = rng.standard_normal(N + 2)

# 与 vsg_sim5.simulate() 相同的 AR(1) 整形，用于自检
a = np.exp(-DT / TAU_N)
b = np.sqrt(1 - a * a)
nz = np.empty(N + 2)
acc = 0.0
for i in range(N + 2):
    acc = a * acc + b * raw[i]
    nz[i] = acc

t = np.arange(N + 2) * DT
savemat(os.path.join(HERE, 'noise_raw.mat'),
        {'noise_raw': np.column_stack([t, raw]),
         'noise_shaped': np.column_stack([t, nz]),
         'noise_seed': float(SEED),
         'noise_tau': float(TAU_N)})

print('N + 2      =', N + 2)
print('raw  std   = %.4f  (期望 1.0000)' % raw.std())
print('nz   std   = %.4f  (AR(1) 后)' % nz.std())
print('a_n        = %.6f, b_n = %.6f' % (a, b))
print('写入 noise_raw.mat')
