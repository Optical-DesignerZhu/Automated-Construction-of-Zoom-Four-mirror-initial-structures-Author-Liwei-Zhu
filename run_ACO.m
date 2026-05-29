function [g_opt_all, gbest, gb] = run_ACO(sysParam)
    disp('========== 启动 ACO 全局寻优 ==========');
    
    isStopAfter = false; isStopOnMirror = false;
    if isfield(sysParam, 'stopPosition')
        if sysParam.stopPosition == 5, isStopAfter = true; disp('>> [ACO] 光阑后置(实出瞳) ...');
        elseif sysParam.stopPosition >= 1 && sysParam.stopPosition <= 4, isStopOnMirror = true; disp(['>> [ACO] M', num2str(sysParam.stopPosition), '光阑...']);
        else, disp('>> [ACO] 光阑前置 ...'); end
    else, disp('>> [ACO] 光阑前置 ...'); end
    
    if isfield(sysParam, 'move') && sysParam.move == 1, isMovingImage = true; disp('>> [ACO] 动像模式 ...');
    else, isMovingImage = false; disp('>> [ACO] 稳像模式 ...'); end
    
    isConic = isfield(sysParam, 'surfaceType') && strcmpi(sysParam.surfaceType, 'CON');
    if isConic, D_full = 17; disp('>> [ACO] 圆锥面(CON) 模式...');
    else, D_full = 13; disp('>> [ACO] 球面(SPH) 模式...'); end
    
    if isfield(sysParam, 'N_pos'), N_pos = sysParam.N_pos; else, N_pos = 2; end
    
    N_pop = sysParam.algo.aco.N_pop; T_aco_min = sysParam.algo.aco.T_aco_min; T_aco_max = sysParam.algo.aco.T_aco_max;
    m = sysParam.algo.aco.m; q = sysParam.algo.aco.q; xi = sysParam.algo.aco.xi;
    
    Xmin = sysParam.bounds.xmin(:)'; Xmax = sysParam.bounds.xmax(:)';
    if isStopAfter || isStopOnMirror
        if isConic, D_red = 13; idx_active_bounds = [1, 6:13, 14:17]; else, D_red = 9; idx_active_bounds = [1, 6:13]; end
    else
        if isConic, D_red = 14; idx_active_bounds = [1, 5:13, 14:17]; else, D_red = 10; idx_active_bounds = [1, 5:13]; end
    end
    Xmin_red = Xmin(idx_active_bounds); Xmax_red = Xmax(idx_active_bounds);
    TotalNumber = round(1.5 * N_pop); 
    
    fprintf('\n========== 阶段 1：构建初始种群 (Parfor 批量加速) ==========\n');
    t_init_start = tic; 
    valid_data = cell(0, 1); valid_red = zeros(0, D_red); valid_fit = zeros(0, 1); valid_metrics = zeros(0, 3); 
    valid_count = 0; attempt_count = 0; max_attempts = TotalNumber * 50; 
    
    % 🌟 优化点 1：将单线程 while 改为 parfor 批量并发生成
    batch_size = TotalNumber * 2; % 每次超量生成一批
    while valid_count < TotalNumber
        attempt_count = attempt_count + batch_size;
        batch_red = Xmin_red + rand(batch_size, D_red) .* (Xmax_red - Xmin_red);
        
        b_data = cell(batch_size, 1); b_fit = inf(batch_size, 1); b_metrics = inf(batch_size, 3);
        
        parfor b = 1:batch_size
            ant_red = batch_red(b, :);
            if isStopAfter || isStopOnMirror
                R1_fixed = ant_red(1); d_pos1 = ant_red(2:5); alpha_pos1 = ant_red(6:9); O1_pos1_z = 400; 
                if isConic, K_pos1 = ant_red(10:13); else, K_pos1 = [0, 0, 0, 0]; end
            else
                R1_fixed = ant_red(1); O1_pos1_z = ant_red(2); d_pos1 = ant_red(3:6); alpha_pos1 = ant_red(7:10); 
                if isConic, K_pos1 = ant_red(11:14); else, K_pos1 = [0, 0, 0, 0]; end
            end
            
            if isMovingImage, d_zoom = Cal_offAxis_Zoom_MovingImage(sysParam, R1_fixed, d_pos1, alpha_pos1, O1_pos1_z, K_pos1);
            else, d_zoom = Cal_offAxis_Zoom_FixedImage(sysParam, R1_fixed, d_pos1, alpha_pos1, O1_pos1_z, K_pos1); end
            
            if ~isempty(d_zoom)
                [fit, l_avg, w_avg, v_unit, ~] = calc_MeritFunction(d_zoom, sysParam);
                b_data{b} = d_zoom; b_fit(b) = fit; b_metrics(b, :) = [l_avg, w_avg, v_unit];
            end
        end
        
        % 提取合法数据
        valid_idx = find(b_fit < inf);
        if ~isempty(valid_idx)
            valid_data = [valid_data; b_data(valid_idx)];
            valid_red = [valid_red; batch_red(valid_idx, :)];
            valid_fit = [valid_fit; b_fit(valid_idx)];
            valid_metrics = [valid_metrics; b_metrics(valid_idx, :)];
            valid_count = length(valid_fit);
            fprintf('  -> [进度] 已获取 %d / %d 个合法种子...\n', valid_count, TotalNumber);
        end
        if attempt_count > max_attempts, break; end
    end
    
    fprintf('初始种群构建完成，耗时: %.2f 秒\n', toc(t_init_start));
    [~, sort_idx] = sort(valid_fit, 'ascend'); N = min(N_pop, valid_count); actual_m = min(m, N);
    archive_data = valid_data(sort_idx(1:actual_m)); archive_red = valid_red(sort_idx(1:actual_m), :);
    archive_fit = valid_fit(sort_idx(1:actual_m)); archive_metrics = valid_metrics(sort_idx(1:actual_m), :); 
    g_opt_all = archive_data{1}; gbest = archive_fit(1); gb = zeros(T_aco_max + 1, 1); gb(1) = gbest;
    
    fprintf('\n========== 阶段 2：ACO 迭代寻优 ==========\n');
    for i = 1:T_aco_max
        iter_tic = tic; 
        weights = zeros(actual_m, 1);
        for r = 1:actual_m, weights(r) = 1 / (q * actual_m * sqrt(2*pi)) * exp(- (r-1)^2 / (2 * q^2 * actual_m^2)); end
        weights = weights / sum(weights); 
        
        % 🌟 优化点 2：将必定重复的 cumsum 提取到 parfor 外部
        cum_weights = cumsum(weights);
        
        new_ants_data = cell(N, 1); new_ants_red = zeros(N, D_red); new_fitness = zeros(N, 1); new_metrics = zeros(N, 3); 
        t_mut_ants = zeros(N, 1); t_kin_ants = zeros(N, 1); t_merit_ants = zeros(N, 1);
        t_trace_arr = zeros(N,1); t_obs_arr = zeros(N,1); t_vol_arr = zeros(N,1); t_wave_arr = zeros(N,1);
        
        t_parfor_start = tic;
        parfor j = 1:N
            t_m_s = tic;
            l = find(rand <= cum_weights, 1);
            
            % 🌟 优化点 3：抛弃 for 循环，使用矩阵向量化计算 sigma
            sigma = xi * sum(abs(archive_red - archive_red(l, :)), 1) / (actual_m - 1);
            ant_red_new = archive_red(l,:) + randn(1, D_red) .* sigma;
            
            % 🌟 优化点 4：抛弃 for 循环，原生 max/min 矩阵截断
            ant_red_new = max(min(ant_red_new, Xmax_red), Xmin_red);
            new_ants_red(j, :) = ant_red_new;
            
            if isStopAfter || isStopOnMirror
                R1_fixed_new = ant_red_new(1); d_pos1_new = ant_red_new(2:5); alpha_pos1_new = ant_red_new(6:9); O1_pos1_z_new = 400; 
                if isConic, K_pos1_new = ant_red_new(10:13); else, K_pos1_new = [0, 0, 0, 0]; end
            else
                R1_fixed_new = ant_red_new(1); O1_pos1_z_new = ant_red_new(2); d_pos1_new = ant_red_new(3:6); alpha_pos1_new = ant_red_new(7:10); 
                if isConic, K_pos1_new = ant_red_new(11:14); else, K_pos1_new = [0, 0, 0, 0]; end
            end
            t_mut_ants(j) = toc(t_m_s);
           
            t_k_s = tic;
            if isMovingImage, data_zoom_all_new = Cal_offAxis_Zoom_MovingImage(sysParam, R1_fixed_new, d_pos1_new, alpha_pos1_new, O1_pos1_z_new, K_pos1_new);
            else, data_zoom_all_new = Cal_offAxis_Zoom_FixedImage(sysParam, R1_fixed_new, d_pos1_new, alpha_pos1_new, O1_pos1_z_new, K_pos1_new); end
            t_kin_ants(j) = toc(t_k_s);
            
            t_e_s = tic;
            if ~isempty(data_zoom_all_new)
                [fit, l_avg, w_avg, v_unit, t_details] = calc_MeritFunction(data_zoom_all_new, sysParam);
                new_fitness(j) = fit; new_metrics(j, :) = [l_avg, w_avg, v_unit]; new_ants_data{j} = data_zoom_all_new;
                t_trace_arr(j) = t_details(1); t_obs_arr(j) = t_details(2); t_vol_arr(j) = t_details(3); t_wave_arr(j) = t_details(4);
            else
                new_fitness(j) = inf; new_metrics(j, :) = [inf, inf, inf]; new_ants_data{j} = zeros(N_pos, D_full);
            end
            t_merit_ants(j) = toc(t_e_s);
        end
        t_parfor = toc(t_parfor_start);
        
        all_data = [archive_data; new_ants_data]; all_red = [archive_red; new_ants_red]; all_fit = [archive_fit; new_fitness]; all_metrics = [archive_metrics; new_metrics]; 
        [~, sort_idx] = sort(all_fit);
        archive_data = all_data(sort_idx(1:actual_m)); archive_red = all_red(sort_idx(1:actual_m), :); archive_fit = all_fit(sort_idx(1:actual_m)); archive_metrics = all_metrics(sort_idx(1:actual_m), :); 
        
        if archive_fit(1) < gbest, g_opt_all = archive_data{1}; gbest = archive_fit(1); end
        gb(i+1) = gbest;
        
        fprintf('\n-- ACO Iter %d/%d 耗时拆解 (挂钟时间: %.2fs) --\n', i, T_aco_max, toc(iter_tic));
        fprintf('  ├─ Parfor 核心池总挂钟时间: %.2fs\n', t_parfor);
        fprintf('  │   ├─ 变焦运动学(fmincon)均值: %.4fs / 蚁\n', mean(t_kin_ants));
        fprintf('  │   └─ 评价函数总耗时均值:      %.4fs / 蚁\n', mean(t_merit_ants));
        fprintf('  │       ├─ [光线追迹] 均值:     %.4fs / 蚁\n', mean(t_trace_arr));
        fprintf('  │       ├─ [遮拦干涉] 均值:     %.4fs / 蚁\n', mean(t_obs_arr));
        fprintf('  │       ├─ [扫掠体积] 均值:     %.4fs / 蚁\n', mean(t_vol_arr));
        fprintf('  │       └─ [波前像差] 均值:     %.4fs / 蚁\n', mean(t_wave_arr));
        fprintf('>>> 当前最优 | Merit: %.6f | Wave: %.4f | Obs: %.4f\n', gbest, archive_metrics(1, 2), archive_metrics(1, 1));
        
        if (i > T_aco_min) && ((gb(i-7) - gb(i+1)) / gb(i+1) < 0.05), fprintf('\n[ACO] 收敛。\n'); break; end
    end
    gb = gb(1:find(gb, 1, 'last')); disp('========== ACO 优化结束 ==========');
end