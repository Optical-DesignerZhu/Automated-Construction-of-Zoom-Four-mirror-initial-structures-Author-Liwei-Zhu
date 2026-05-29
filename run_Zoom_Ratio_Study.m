%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%*****Description : Automated Study for Zoom Ratio & Stop Position
%*****Author : Lei Yang & Assistant
%*****Date : May. 1, 2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; clc;

%% 0. 测试网格与全局设置定义
test_stopPos     = [0, 5];                  % 0: 前置, 5: 后置
test_zoom_ratios = [2, 2.5, 3, 3.5, 4, 4.5, 5]; % 变倍比测试范围
test_F_number    = 5.0;                     % 固定 F 数
test_base_hfov   = 3.0;                     % 短焦位固定半视场角
total_configs    = length(test_stopPos) * length(test_zoom_ratios);

% =========================================================================
% 🌟 智能自适应并行池配置
% =========================================================================
physical_cores = feature('numcores');
num_workers = max(1, physical_cores - 2);
fprintf('\n>>> 🖥️ 硬件检测: 物理核心 %d，锁定并行线程 %d。\n', physical_cores, num_workers);

myCluster = parcluster('local');
myCluster.NumWorkers = num_workers;
saveProfile(myCluster);

p = gcp('nocreate');
if isempty(p)
    parpool('local', num_workers);
end

% 创建本次实验的总时间戳根目录
master_root = sprintf('Batch_DualStop_Study_%s', datestr(now, 'yyyymmdd_HHMMSS'));
if ~exist(master_root, 'dir'), mkdir(master_root); end

fprintf('\n>>> 🚀 实验启动！总计测试 %d 种组合 \n', total_configs);

%% 1. 外层循环：光阑位置
for sp_idx = 1:length(test_stopPos)
    curr_stop = test_stopPos(sp_idx);

    % 确定光阑位置文件夹名称
    if curr_stop == 0
        stop_dir_name = 'StopFront_Results';
        str_stop_cn = '前置(0)';
    else
        stop_dir_name = 'StopRear_Results';
        str_stop_cn = '后置(5)';
    end

    stop_master_dir = fullfile(master_root, stop_dir_name);
    if ~exist(stop_master_dir, 'dir'), mkdir(stop_master_dir); end

    % 初始化当前光阑下的汇总表
    summary_results = cell(length(test_zoom_ratios) + 1, 7);
    summary_results(1, :) = {'Zoom_Ratio', 'Max_Focal_Length', 'Best_Fitness', 'Best_Wavefront', 'Best_Line', 'Best_Volume_mm3', 'Data_File'};

    %% 2. 内层循环：变倍比
    for z_idx = 1:length(test_zoom_ratios)
        curr_ratio = test_zoom_ratios(z_idx);
        base_f = -100;
        max_f  = base_f * curr_ratio;

        fprintf('\n-----------------------------------------------------------------\n');
        fprintf('【光阑: %s】进度 %d/%d | 变倍比: %.1f× (%d ~ %d)\n', ...
            str_stop_cn, z_idx, length(test_zoom_ratios), curr_ratio, base_f, max_f);
        fprintf('-----------------------------------------------------------------\n');

        % 创建变倍比子文件夹
        sub_dir_name = sprintf('ZoomRatio_%.1fX', curr_ratio);
        sub_dir = fullfile(stop_master_dir, sub_dir_name);
        if ~exist(sub_dir, 'dir'), mkdir(sub_dir); end

        %% 3. 构建系统参数 (sysParam)
        sysParam = struct();
        sysParam.move = 2;
        sysParam.N_pos = 3;
        f_list = linspace(base_f, max_f, sysParam.N_pos);
        for i = 1:sysParam.N_pos
            sysParam.pos(i).F_number = test_F_number;
            sysParam.pos(i).f        = f_list(i);
            sysParam.pos(i).hfov     = test_base_hfov * (base_f / f_list(i));
            sysParam.pos(i).epd      = abs(f_list(i) / test_F_number);
        end

        sysParam.stopPosition = curr_stop;
        sysParam.stopToImage  = 40;
        sysParam.surfaceType  = 'CON';
        sysParam.field_grid_size = 5;
        sysParam.show_iter_details = false;

        % 边界限制
        sysParam.bounds.xmin = [-8000; -8000; -8000; -8000; 50; -600; 100; -600; 100; 6; -30; -30; -30; -20; -20; -20; -20];
        sysParam.bounds.xmax = [ 8000; 8000; 8000; 8000; 600; -100; 600; -100; 600; 30; 30; 30; 30; 20; 20; 20; 20];

        % 权重设置
        sysParam.weight.line = 0.1;
        sysParam.weight.wave = 1.0;
        sysParam.weight.vol  = 0.02;

        % 算法超参
        sysParam.algo.aco.N_pop = 300;
        sysParam.algo.aco.T_aco_min = 30;
        sysParam.algo.aco.T_aco_max = 31;
        sysParam.algo.nm.T_nm_max = 300;
        sysParam.algo.aco.m         = 50;
        sysParam.algo.aco.q         = 0.02;
        sysParam.algo.aco.xi        = 0.85;
        sysParam.algo.nm.tol_nm     = 1e-7;

        sysParam.iteration = 10;
        N_runs = 10;
        numParams = 17;
        solutionData = zeros(sysParam.iteration * N_runs, sysParam.N_pos * numParams + 1);

        combo_best_fitness = inf; combo_best_wave = inf;
        combo_best_line = inf; combo_best_vol = inf;

        %% 4. 执行优化核心
        for it = 1:sysParam.iteration
            aco_bests = zeros(N_runs, 1); aco_all_list = cell(N_runs, 1); aco_pos1_list = cell(N_runs, 1);
            for r = 1:N_runs
                [g_aco_all, gbest_aco, ~] = run_ACO(sysParam);
                aco_bests(r) = gbest_aco; aco_all_list{r} = g_aco_all; aco_pos1_list{r} = g_aco_all(1, :);
            end
            nm_bests = zeros(N_runs, 1); nm_opt_all_list = cell(N_runs, 1);
            parfor r = 1:N_runs
                if aco_bests(r) > 12
                    nm_opt_all_list{r} = aco_all_list{r}; nm_bests(r) = aco_bests(r);
                else
                    [g_opt_all_nm, gbest_nm, ~] = run_NM(aco_pos1_list{r}, sysParam);
                    if gbest_nm < aco_bests(r)
                        nm_opt_all_list{r} = g_opt_all_nm; nm_bests(r) = gbest_nm;
                    else
                        nm_opt_all_list{r} = aco_all_list{r}; nm_bests(r) = aco_bests(r);
                    end
                end
            end

            % 择优渲染与内存释放
            [~, best_run_idx] = min(nm_bests);
            for r = 1:N_runs
                g_opt_all = nm_opt_all_list{r}; gbest_opt = nm_bests(r);
                [~, final_line_avg, final_wave_avg, final_vol_unit] = calc_MeritFunction(g_opt_all, sysParam);

                if gbest_opt < combo_best_fitness
                    combo_best_fitness = gbest_opt; combo_best_wave = final_wave_avg;
                    combo_best_line = final_line_avg; combo_best_vol = final_vol_unit * 1e6;
                end

                if r == best_run_idx && gbest_opt < 15
                    [fig_2d, ~] = plot_2D_zoom_overlay(g_opt_all, sysParam, 'off');
                    img_name = sprintf('Iter%02d_Fit%.2f.png', it, gbest_opt);
                    exportgraphics(fig_2d, fullfile(sub_dir, img_name), 'Resolution', 300);
                    delete(fig_2d);
                end
                row_idx = (it - 1) * N_runs + r;
                solutionData(row_idx, 1:sysParam.N_pos*numParams) = g_opt_all(:)';
                solutionData(row_idx, end) = gbest_opt;
            end
        end

        %% 5. 存储单个变倍比数据
        mat_name = sprintf('Data_Stop%d_Zoom%.1fX.mat', curr_stop, curr_ratio);
        save(fullfile(sub_dir, mat_name), 'sysParam', 'solutionData');

        summary_results(z_idx + 1, :) = {curr_ratio, max_f, combo_best_fitness, ...
            combo_best_wave, combo_best_line, combo_best_vol, mat_name};
    end

    %% 6. 保存当前光阑位置的 Excel 报告
    summary_table = cell2table(summary_results(2:end, :), 'VariableNames', summary_results(1, :));
    writetable(summary_table, fullfile(stop_master_dir, 'A_Summary_Results.xlsx'));
end

fprintf('\n🎉 双维度对比测试全部完成！\n根目录: %s\n', master_root);