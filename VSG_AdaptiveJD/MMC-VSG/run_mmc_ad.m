function run_mmc_ad(tag)
%RUN_MMC_AD  运行改造后的 MMC-VSG 模型并保存波形
%   run_mmc_ad('msca')   % 本文方案
%   run_mmc_ad('fixed')  % 固定参数（scheme=1，需先 build_mmc_ad(1)）

if nargin < 1, tag = 'msca'; end
d = 'C:/Users/Lenovo/WorkBuddy/2026-09-18-17-03-29/git/mmc_vsg';
cd(d); addpath(d);
mdlName = 'MMC_30_VSG_AD';
fid = fopen([d '/run_' tag '.log'], 'w', 'n', 'UTF-8');

try
    load_system([d '/' mdlName '.slx']);

    % 连线自检
    p = [mdlName '/VSG控制/VSG有功控制-频率调节-一次调频'];
    for b = {'Gain1', 'Gain2', 'adap_law', 'ZOH_dw'}
        bb = [p '/' b{1}];
        if getSimulinkBlockHandle(bb) < 0
            fprintf(fid, '!! 缺块 %s\n', b{1});
            continue;
        end
        pc = get_param(bb, 'PortConnectivity');
        fprintf(fid, '--- %s ---\n', b{1});
        for j = 1:numel(pc)
            s = ''; t = '';
            if ~isempty(pc(j).SrcBlock) && pc(j).SrcBlock(1) > 0
                s = get_param(pc(j).SrcBlock(1), 'Name');
            end
            if ~isempty(pc(j).DstBlock) && pc(j).DstBlock(1) > 0
                t = get_param(pc(j).DstBlock(1), 'Name');
            end
            fprintf(fid, '   #%d [%s] <- %-14s -> %s\n', j, pc(j).Type, s, t);
        end
    end

    % 附加量测：子模块电容电压与桥臂电流（顶层 Goto 标签）
    extra = {'VcP','VcP'; 'iAP','iAP'; 'iAL','iAL'; 'VcL','VcL'};
    for k = 1:size(extra, 1)
        fr = [mdlName '/FR_' extra{k,2}];
        tw = [mdlName '/TW_' extra{k,2}];
        if getSimulinkBlockHandle(tw) < 0
            add_block('simulink/Signal Routing/From', fr, 'GotoTag', extra{k,1}, ...
                'Position', [1150 300+70*k 1200 320+70*k]);
            add_block('simulink/Sinks/To Workspace', tw, ...
                'VariableName', extra{k,2}, 'SaveFormat', 'timeseries', ...
                'SampleTime', 'Ts', 'Position', [1230 300+70*k 1310 320+70*k]);
            add_line(mdlName, ['FR_' extra{k,2} '/1'], ['TW_' extra{k,2} '/1']);
            fprintf(fid, '附加通道 %s\n', extra{k,2});
        end
    end

    fprintf(fid, 'StopTime = %s\n', get_param(mdlName, 'StopTime'));
    t0 = tic;
    out = sim(mdlName, 'ReturnWorkspaceOutputs', 'on');
    el = toc(t0);
    fprintf(fid, 'SIM OK, wall = %.1f s\n', el);

    res = struct();
    vars = {'omega_vsg', 'Pe_vsg', 'J_vsg', 'D_vsg', 'VcP', 'VcL', 'iAP', 'iAL'};
    for k = 1:numel(vars)
        try
            ts = out.get(vars{k});
            res.(vars{k}) = [ts.Time, ts.Data];
            fprintf(fid, '%-10s %d 点  范围 [%.4g, %.4g]\n', vars{k}, ...
                numel(ts.Time), min(ts.Data(:)), max(ts.Data(:)));
        catch ME
            fprintf(fid, '%-10s 未取到：%s\n', vars{k}, ME.message);
        end
    end
    try
        ts = out.get('xi_vsg');
        res.xi_vsg = [ts.Time, ts.Data];
        fprintf(fid, 'xi_vsg     %d 点  范围 [%.4g, %.4g]\n', ...
            numel(ts.Time), min(ts.Data(:)), max(ts.Data(:)));
    catch
    end
    save([d '/res_' tag '.mat'], '-struct', 'res');

    % 指标
    if isfield(res, 'omega_vsg')
        t = res.omega_vsg(:, 1); w = res.omega_vsg(:, 2);
        w0 = 2*pi*50;
        df = (w - w0)/(2*pi);
        i0 = find(t >= 1.3, 1);
        pre = mean(df(max(1, i0-50):i0));
        post = df(i0:end);
        dev = post - pre;
        fprintf(fid, '\n--- 频率响应 ---\n');
        fprintf(fid, '阶跃前 df = %.5f Hz\n', pre);
        fprintf(fid, '最大偏差 = %.5f Hz（%.2f mHz）\n', max(abs(dev)), 1000*max(abs(dev)));
        fprintf(fid, 'RoCoF 峰值 = %.4f Hz/s\n', max(abs(diff(dev)))/mean(diff(t(i0:end))));
        % 稳态与调节时间（2% 带）
        fin = mean(dev(end-min(400, numel(dev))+1:end));
        band = 0.02*max(abs(dev));
        idx = find(abs(dev) > band, 1, 'last');
        if isempty(idx), ts2 = 0; else, ts2 = t(i0-1+idx) - t(i0); end
        fprintf(fid, '终值偏差 = %.5f Hz, 调节时间(2%%) = %.4f s\n', fin, ts2);
        if abs(fin) > 1e-9
            fprintf(fid, '超调 = %.2f %%\n', 100*(max(abs(dev)) - abs(fin))/abs(fin));
        end
    end
    if isfield(res, 'J_vsg')
        J = res.J_vsg(:, 2); D = res.D_vsg(:, 2);
        fprintf(fid, '\nJ 范围 [%.2f, %.2f]，D 范围 [%.1f, %.1f]\n', min(J), max(J), min(D), max(D));
        fprintf(fid, 'J 总变差 = %.2f\n', sum(abs(diff(J))));
    end
catch ME
    fprintf(fid, 'ERR %s : %s\n', ME.identifier, ME.message);
    for k = 1:numel(ME.stack)
        fprintf(fid, '  at %s line %d\n', ME.stack(k).name, ME.stack(k).line);
    end
    for c = 1:numel(ME.cause)
        fprintf(fid, '  -- %s\n', ME.cause{c}.message);
    end
end
fclose(fid);
end
