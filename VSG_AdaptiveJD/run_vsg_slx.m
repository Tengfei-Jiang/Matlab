function run_vsg_slx(doSave)

%
%     overshoot  阶跃段超调
%     settling   调节时间
%     rocof_max  最大频率变化率
%     dfmax      最大频率偏差
%     zeta_viol  阻尼比越限时间占比，越限判据 ζ < 0.707 或 ζ > 1
%     J_TV       惯量总变差 Φ_J = Σ|ΔJ| / (Jmax − Jmin)
%     IAE        功率指令跟踪绝对误差积分

if nargin < 1, doSave = true; end

mdl   = 'VSG_AdaptiveJD';
cases = {'case1', 'case2', 'case3'};
names = {'Fixed', 'Wen', 'Wang', 'Ban', 'MSCA'};
here  = fileparts(mfilename('fullpath'));

load_system(mdl);
init_vsg_params('case1', 1);

R = struct();
for ci = 1:numel(cases)
    assignin('base', 'VSG_CASE', cases{ci});
    for si = 1:numel(names)
        assignin('base', 'VSG_SCHEME', si);
        out = sim(mdl);
        y   = out.yout;
        t   = y.Time;
        D   = y.Data;
        rec = struct('t', t, 'delta', D(:,1), 'omega', D(:,2), 'Pe', D(:,3), ...
                     'J', D(:,4), 'Dsig', D(:,5), 'zeta', D(:,6));
        R.(cases{ci}).(names{si}) = rec;
        fprintf('  %s / %-5s  done (%d 点)\n', cases{ci}, names{si}, numel(t));
    end
end

M = struct();
for ci = 1:numel(cases)
    for si = 1:numel(names)
        M.(cases{ci}).(names{si}) = metrics(R.(cases{ci}).(names{si}), cases{ci});
    end
end


for ci = 1:numel(cases)
    fprintf('\n=== %s ===\n', cases{ci});
    for si = 1:numel(names)
        m = M.(cases{ci}).(names{si});
        fprintf(['%-5s  sigma%%= %-12s ts= %-16s ROCOF= %.3f Hz/s  ' ...
                 '|df|= %.4f Hz  IAE= %.4f  zeta越限= %.1f%%  J_TV= %.2f\n'], ...
                names{si}, mat2str(round(m.overshoot,2)), mat2str(round(m.settling,3)), ...
                m.rocof_max, m.dfmax, m.IAE, m.zeta_viol, m.J_TV);
    end
end

if doSave
    save(fullfile(here, 'slx_results.mat'), 'R', 'M', '-v7.3');
    fid = fopen(fullfile(here, 'slx_metrics.json'), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s', jsonencode(M, 'PrettyPrint', true));
    fclose(fid);
    fprintf('\n已写出 slx_results.mat / slx_metrics.json\n');
end
end

% ======================================================================
function m = metrics(r, caseName)
dt = r.t(2) - r.t(1);
y  = r.zeta;  J = r.J;  Pe = r.Pe;  f = r.omega/(2*pi);

Pdn = evalin('base', 'Pdn');
switch caseName
    case 'case1'
        steps = [1.0 25e3 Pdn; 2.0 Pdn 25e3];
    otherwise
        steps = [1.0 25e3 30e3; 2.0 30e3 20e3];
end

ov = zeros(1, size(steps,1));
ts = zeros(1, size(steps,1));
for k = 1:size(steps,1)
    i0 = min(max(round(steps(k,1)/dt)+1, 1), numel(r.t));
    if k < size(steps,1)
        i1 = min(round(steps(k+1,1)/dt)+1, numel(r.t));
    else
        i1 = numel(r.t);
    end
    seg  = Pe(i0:i1);
    Pinf = steps(k,3);
    dP   = Pinf - steps(k,2);
    if dP > 0
        ov(k) = max((max(seg) - Pinf)/dP*100, 0);
    else
        ov(k) = max((Pinf - min(seg))/abs(dP)*100, 0);
    end
    bad = find(abs(seg - Pinf) > 0.02*abs(dP));
    if isempty(bad)
        ts(k) = 0;
    else
        ts(k) = min(r.t(i0 + bad(end) - 1) - steps(k,1), 3.0);
    end
end

m.overshoot = ov;
m.settling  = ts;
m.zeta_viol = mean((y < 0.707 - 1e-3) | (y > 1.0))*100;
m.zeta_min  = min(y);
m.zeta_max  = max(y);
m.rocof_max = max(abs(gradient(f, r.t)));
m.dfmax     = max(abs(f - 50));
m.J_TV      = sum(abs(diff(J)))/evalin('base', 'Jmax - Jmin');
m.IAE       = trapz(r.t, abs(Pe - pref_of(r.t, caseName)))/1e3;
end

function p = pref_of(t, caseName)
switch caseName
    case 'case1'
        p = 25e3*ones(size(t));
    otherwise
        p = 25e3*ones(size(t));
        p(t >= 1.0) = 30e3;
        p(t >= 2.0) = 20e3;
end
end
