%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%*****Description : Automated Batch Testing for Volume Weight Trade-off
%*****Author : Liwei Zhu & Assistant
%*****Date : Mar. 10, 2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; clc;

%% 0. 测试网格与全局设置定义
test_stopPos   = 0;                             % 光阑位置 (这里按您的要求固定测试后置 5，可自行改为 [0, 5] 测两组)
test_F_numbers = [3,4, 5, 6];                  % F 数数组
test_hfovs     = [1, 2, 3, 4];                  % 半视场角数组
test_w_vols    = [0.02, 0.04, 0.06, 0.08, 0.10]; % 体积权重数组 

total_tests = length(test_stopPos) * length(test_F_numbers) * length(test_hfovs) * length(test_w_vols);

% =========================================================================
% 🌟 智能自适应并行池配置
% =========================================================================
physical_cores = feature('numcores'); 
if physical_cores >= 16
    num_workers = physical_cores - 12; 
elseif physical_cores > 4
    num_workers = physical_cores - 1; 
else
    num_workers = physical_cores;     
end

fprintf('\n>>> 🖥️ 硬件检测: 发现本机器共有 %d 个物理核心。\n', physical_cores);
fprintf('>>> ⚙️ 并行调度: 最大并行线程数锁定为 %d。\n', num_workers);

myCluster = parcluster('local'); 
myCluster.NumWorkers = num_workers; 
saveProfile(myCluster); 

p = gcp('nocreate');
if isempty(p)
    parpool('local', num_workers);
elseif p.NumWorkers ~= num_workers
    delete(p);
    parpool('local', num_workers);
end
% =========================================================================

% 创建批量实验的【总文件夹】
master_time_str = datestr(now, 'yyyymmdd_HHMMSS');
master_dir = sprintf('Batch_Weight_Study_%s', master_time_str);
if ~exist(master_dir, 'dir'), mkdir(master_dir); end

fprintf('\n>>> 🚀 体积权重对比批量测试启动！总目录: %s\n', master_dir);
fprintf('>>> 预计将进行 %d 种参数组合的测试...\n\n', total_tests);

% 初始化汇总表 (增加 Weight_Vol 列)
summary_results = cell(total_tests + 1, 8); 
summary_results(1, :) = {'Stop_Pos', 'F_number', 'HFOV', 'Weight_Vol', 'Global_Best_Fit', 'Best_Wavefront', 'Best_Line', 'Best_Volume_mm3'};
test_count = 1;

%% 1. 开始四层嵌套循环
for sp_idx = 1:length(test_stopPos)
    for f_idx = 1:length(test_F_numbers)
        for h_idx = 1:length(test_hfovs)
            for w_idx = 1:length(test_w_vols)
                
                % 提取当前组合的参数
                curr_Stop = test_stopPos(sp_idx);
                curr_F    = test_F_numbers(f_idx);
                curr_HFOV = test_hfovs(h_idx);
                curr_Wvol = test_w_vols(w_idx);
                
                % 🌟 核心修改：为光阑位置赋予明确的中英文标识
                if curr_Stop == 0
                    str_stop_cn = '前置(0)';
                    str_stop_en = 'StopFront'; % 用于文件夹命名，英文防止路径报错
                else
                    str_stop_cn = '后置(5)';
                    str_stop_en = 'StopRear';
                end
                
                fprintf('\n=================================================================\n');
                fprintf('【总进度 %d/%d】当前测试: 光阑=%s | F=%d | HFOV=%d° | 体积权重=%.2f\n', ...
                        test_count, total_tests, str_stop_cn, curr_F, curr_HFOV, curr_Wvol);
                fprintf('=================================================================\n');
                
                % 🌟 核心修改：文件夹名称直接带上明确的光阑位置标识
                sub_dir_name = sprintf('%s_F%d_HFOV%d_Wvol%.2f', str_stop_en, curr_F, curr_HFOV, curr_Wvol);
                sub_dir = fullfile(master_dir, sub_dir_name);
                if ~exist(sub_dir, 'dir'), mkdir(sub_dir); end
                
                %% 2. 构建系统参数
                sysParam = struct();
                sysParam.move = 2;
                
                base_f        = -100;   
                target_max_f  = -200;   
                sysParam.N_pos = 3;     % 3个变焦组态
                f_list = linspace(base_f, target_max_f, sysParam.N_pos);
                
                for i = 1:sysParam.N_pos
                    sysParam.pos(i).F_number = curr_F;
                    sysParam.pos(i).f        = f_list(i);
                    sysParam.pos(i).hfov     = curr_HFOV * (base_f / f_list(i)); 
                    sysParam.pos(i).epd      = abs(f_list(i) / curr_F);
                end
                
                sysParam.stopPosition = curr_Stop;  
                sysParam.stopToImage  = 40;         
                sysParam.surfaceType  = 'CON'; 
                sysParam.field_grid_size = 5;  
                sysParam.show_iter_details = false; % 关闭细碎打印提升速度
                
                sysParam.bounds.xmin = [-8000; -8000; -8000; -8000; 50; -600; 100; -600; 100; 6; -30; -30; -30; -20; -20; -20; -20];
                sysParam.bounds.xmax = [ 8000; 8000; 8000; 8000; 600; -100; 600; -100; 600; 30; 30; 30; 30; 20; 20; 20; 20];
                
                % 算法超参设置
                sysParam.algo.aco.N_pop     = 300;   
                sysParam.algo.aco.T_aco_min = 30;    
                sysParam.algo.aco.T_aco_max = 31;    
                sysParam.algo.aco.m         = 50;    
                sysParam.algo.aco.q         = 0.02;  
                sysParam.algo.aco.xi        = 0.85;  
                sysParam.algo.nm.T_nm_max   = 300;   
                sysParam.algo.nm.tol_nm     = 1e-7;  
                
                sysParam.weight.line = 0.1;  
                sysParam.weight.wave = 1.0;  
                sysParam.weight.vol  = curr_Wvol;  % 动态赋值当前体积权重
                
                sysParam.iteration = 10; % 外层大循环
                N_runs = 10;             % 内层独立并发优选
                
                if strcmpi(sysParam.surfaceType, 'CON')
                    numParams = 17;
                else
                    numParams = 13;
                end
                
                solutionData = zeros(sysParam.iteration * N_runs, sysParam.N_pos * numParams + 1);
                
                combo_best_fitness = inf;
                combo_best_wave = inf;
                combo_best_line = inf;
                combo_best_vol  = inf;
                
                %% 3. 执行嵌套优化机制
                for it = 1:sysParam.iteration
                    aco_bests = zeros(N_runs, 1);
                    aco_all_list = cell(N_runs, 1);
                    aco_pos1_list = cell(N_runs, 1);
                    
                    % [阶段 A] 串行 ACO 探索
                    for r = 1:N_runs
                        [g_aco_all, gbest_aco, ~] = run_ACO(sysParam);
                        aco_bests(r) = gbest_aco;
                        aco_all_list{r} = g_aco_all;
                        aco_pos1_list{r} = g_aco_all(1, :);
                    end
                    
                    % [阶段 B] 并发 NM 局部优化
                    nm_bests = zeros(N_runs, 1);
                    nm_opt_all_list = cell(N_runs, 1);
                    parfor r = 1:N_runs
                        if aco_bests(r) > 12 
                            nm_opt_all_list{r} = aco_all_list{r};
                            nm_bests(r) = aco_bests(r);
                        else
                            [g_opt_all_nm, gbest_nm, ~] = run_NM(aco_pos1_list{r}, sysParam);
                            if gbest_nm < aco_bests(r)
                                nm_opt_all_list{r} = g_opt_all_nm;
                                nm_bests(r) = gbest_nm;
                            else
                                nm_opt_all_list{r} = aco_all_list{r};
                                nm_bests(r) = aco_bests(r);
                            end
                        end
                    end
                    
                    % [阶段 C] 数据提取与批量 2D 出图
                    for r = 1:N_runs
                        g_opt_all = nm_opt_all_list{r};
                        gbest_opt = nm_bests(r);
                        
                        [~, final_line_avg, final_wave_avg, final_vol_unit] = calc_MeritFunction(g_opt_all, sysParam);
                        
                        if gbest_opt < combo_best_fitness
                            combo_best_fitness = gbest_opt;
                            combo_best_wave = final_wave_avg;
                            combo_best_line = final_line_avg;
                            combo_best_vol  = final_vol_unit * 1e6;
                        end
                        
                        % 2D 绘图并保存至子文件夹
                        [fig_2d, ~] = plot_2D_zoom_overlay(g_opt_all, sysParam, 'off');
                        drawnow; 
                        img_2d_name = sprintf('Iter%02d_Run%02d.png', it, r);
                        exportgraphics(fig_2d, fullfile(sub_dir, img_2d_name), 'Resolution', 300, 'BackgroundColor', 'w');
                        close(fig_2d);         
                        
                        % 存入记录
                        row_idx = (it - 1) * N_runs + r;
                        for pos_idx = 1:sysParam.N_pos
                            start_col = (pos_idx - 1) * numParams + 1;
                            end_col   = pos_idx * numParams;
                            solutionData(row_idx, start_col:end_col) = g_opt_all(pos_idx, :);
                        end
                        solutionData(row_idx, end) = gbest_opt;
                    end
                end % 结束 iteration 循环
                
                %% 4. 保存当前组合详细数据
                save(fullfile(sub_dir, 'Full_Data.mat'), 'sysParam', 'solutionData');
                
                %% 5. 登记汇总表 (在汇总表中也保存明确的中文位置)
                summary_results(test_count + 1, :) = {str_stop_cn, curr_F, curr_HFOV, curr_Wvol, combo_best_fitness, combo_best_wave, combo_best_line, combo_best_vol};
                test_count = test_count + 1;
                
            end % 结束 体积权重 循环
        end % 结束 HFOV 循环
    end % 结束 F 数循环
end % 结束 光阑 循环

%% 6. 生成全局汇总数据表
summary_table = cell2table(summary_results(2:end, :), 'VariableNames', summary_results(1, :));
writetable(summary_table, fullfile(master_dir, 'A_Weight_Study_Summary.xlsx'));
save(fullfile(master_dir, 'A_Weight_Study_Summary.mat'), 'summary_table', 'summary_results');

fprintf('\n🎉🎉🎉 所有 %d 组参数组合测试全部完成！\n', total_tests);
fprintf('👉 全局汇总对比表已保存为: A_Weight_Study_Summary.xlsx\n');