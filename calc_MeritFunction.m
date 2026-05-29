function [fitness, f_line_avg, f_wave_avg, f_vol_unit, timings, max_D, stroke_M2, stroke_M4] = calc_MeritFunction(data_zoom_all, sysParam)
    if isfield(sysParam, 'stopPosition'), stopPos = sysParam.stopPosition; else, stopPos = 0; end
    if isfield(sysParam, 'N_pos'), N_pos = sysParam.N_pos; else, N_pos = size(data_zoom_all, 1); end
    if isfield(sysParam, 'field_grid_size'), grid_n = sysParam.field_grid_size; else, grid_n = 3; end
    
    % =========================================================================
    % 🌟 【动态评价模式与超参数解析】
    % =========================================================================
    % 提取模式 (1: 线性权重, 2: 阈值平方惩罚)
    if isfield(sysParam, 'mode') && isfield(sysParam.mode, 'vol'), mode_vol = sysParam.mode.vol; else, mode_vol = 1; end
    if isfield(sysParam, 'mode') && isfield(sysParam.mode, 'aperture'), mode_aperture = sysParam.mode.aperture; else, mode_aperture = 2; end
    if isfield(sysParam, 'mode') && isfield(sysParam.mode, 'stroke'), mode_stroke = sysParam.mode.stroke; else, mode_stroke = 2; end

    % 提取线性权重 (模式 1)
    if isfield(sysParam, 'weight') && isfield(sysParam.weight, 'vol'), w_vol_linear = sysParam.weight.vol; else, w_vol_linear = 0.1; end
    if isfield(sysParam, 'weight') && isfield(sysParam.weight, 'aperture_linear'), w_apt_linear = sysParam.weight.aperture_linear; else, w_apt_linear = 0.05; end
    if isfield(sysParam, 'weight') && isfield(sysParam.weight, 'stroke_linear'), w_str_linear = sysParam.weight.stroke_linear; else, w_str_linear = 0.05; end

    % 提取阈值硬约束 (模式 2)
    if isfield(sysParam, 'bounds') && isfield(sysParam.bounds, 'max_vol_limit'), limit_vol = sysParam.bounds.max_vol_limit; else, limit_vol = 100; end
    if isfield(sysParam, 'bounds') && isfield(sysParam.bounds, 'max_aperture_limit'), limit_apt = sysParam.bounds.max_aperture_limit; else, limit_apt = 450; end
    if isfield(sysParam, 'bounds') && isfield(sysParam.bounds, 'max_stroke_M2'), limit_str_m2 = sysParam.bounds.max_stroke_M2; else, limit_str_m2 = 150; end
    if isfield(sysParam, 'bounds') && isfield(sysParam.bounds, 'max_stroke_M4'), limit_str_m4 = sysParam.bounds.max_stroke_M4; else, limit_str_m4 = 150; end

    % 提取模式2的惩罚系数
    if isfield(sysParam, 'weight') && isfield(sysParam.weight, 'penalty_vol'), wp_vol = sysParam.weight.penalty_vol; else, wp_vol = 1.0; end
    if isfield(sysParam, 'weight') && isfield(sysParam.weight, 'penalty_aperture'), wp_apt = sysParam.weight.penalty_aperture; else, wp_apt = 1.0; end
    if isfield(sysParam, 'weight') && isfield(sysParam.weight, 'penalty_stroke'), wp_str = sysParam.weight.penalty_stroke; else, wp_str = 1.0; end
    % =========================================================================

    % 极速缓存：避免重复生成视场网格
    persistent H_array_cached grid_n_cached;
    if isempty(H_array_cached) || isempty(grid_n_cached) || grid_n_cached ~= grid_n
        H_array_local = []; v_grid = linspace(-1, 1, grid_n);
        for hx = v_grid(v_grid >= -1e-8) 
            for hy = v_grid
                if hx^2 + hy^2 <= 1.0001, H_array_local = [H_array_local; hx, hy]; end
            end
        end
        H_array_cached = H_array_local;
        grid_n_cached = grid_n;
    end
    H_array = H_array_cached;
    
    r_configs_cell = cell(1, N_pos); r_wave_cell = cell(1, N_pos);
    epd_array = zeros(1, N_pos); fa_cell = cell(1, N_pos);
    
    for i = 1:N_pos
        r_new = data_zoom_all(i, :);
        if stopPos == 5
            d_stop_img = sysParam.stopToImage; dex = r_new(9) - d_stop_img; 
            if length(r_new) >= 17, K_pos = r_new(14:17); else, K_pos = []; end
            r_trace = [r_new(1:4), r_new(6:8), dex, d_stop_img, r_new(10:13), K_pos];
            r_wave = [r_new(1:4), dex, r_new(6:9), r_new(10:13), K_pos];
        else
            r_trace = r_new; r_wave = r_new;
        end
        r_configs_cell{i} = r_trace; r_wave_cell{i} = r_wave;
        epd_array(i) = sysParam.pos(i).epd; fa_cell{i} = [-sysParam.pos(i).hfov, 0, sysParam.pos(i).hfov];
    end
    
    % --- 阶段 1：追迹与遮拦 ---
    [f_line_total, ~, ~, is_valid, traces, D_max, t_trace, t_obs] = funObscurationZoom(r_configs_cell, epd_array, fa_cell, stopPos);
    
    if ~is_valid
        fitness = 10000; f_line_avg = 1000; f_wave_avg = 1000; f_vol_unit = 1e8; 
        timings = [t_trace, t_obs, 0, 0]; max_D = 1000; stroke_M2 = 999; stroke_M4 = 999;
        return; 
    end
    
    % --- 阶段 2：计算体积与多模式得分计算 ---
    t_v_s = tic;
    vol_2D = calc_SystemVolume_Precise(traces, D_max, sysParam);
    t_vol = toc(t_v_s);
    f_vol_unit = 1e-6 * vol_2D; % 转换为 L

    % 📦 [策略应用] 体积
    if mode_vol == 1
        cost_vol = w_vol_linear * f_vol_unit;
    else
        if f_vol_unit > limit_vol
            cost_vol = wp_vol * (f_vol_unit - limit_vol)^2 + 50; % 加50基础惩罚避免边界停滞
        else
            cost_vol = 0;
        end
    end

    % 🔍 [策略应用] 最大口径
    system_max_D = max(D_max); 
    if mode_aperture == 1
        cost_aperture = w_apt_linear * system_max_D;
    else
        if system_max_D > limit_apt
            cost_aperture = wp_apt * (system_max_D - limit_apt)^2 + 50; 
        else
            cost_aperture = 0; 
        end
    end

    % ⚙️ [策略应用] 变焦行程
    stroke_M2 = abs( abs(data_zoom_all(1, 6)) - abs(data_zoom_all(end, 6)) );
    stroke_M4 = abs( abs(data_zoom_all(1, 9)) - abs(data_zoom_all(end, 9)) );
    
    if mode_stroke == 1
        % 线性模式下，同时压制两个镜片的行程总和
        cost_stroke = w_str_linear * (stroke_M2 + stroke_M4);
    else
        cost_stroke = 0;
        if stroke_M2 > limit_str_m2
            cost_stroke = cost_stroke + wp_str * (stroke_M2 - limit_str_m2)^2 + 50;
        end
        if stroke_M4 > limit_str_m4
            cost_stroke = cost_stroke + wp_str * (stroke_M4 - limit_str_m4)^2 + 50;
        end
    end
    
    % --- 阶段 3：计算波前 ---
    t_w_s = tic;
    f_wave_total = 0;
    for i = 1:N_pos
        r_w = r_wave_cell{i}; U1 = sysParam.pos(i).hfov * pi/180; y1 = sysParam.pos(i).epd / 2;
        if stopPos >= 1 && stopPos <= 4
            switch stopPos
                case 1, f_wave_c = funWavefront_SM1(r_w, U1, y1, H_array) / 10;
                case 2, f_wave_c = funWavefront_SM2(r_w, U1, y1, H_array) / 10;
                case 3, f_wave_c = funWavefront_SM3(r_w, U1, y1, H_array) / 10;
                case 4, f_wave_c = funWavefront_SM4(r_w, U1, y1, H_array) / 10;
            end
        elseif stopPos == 5
            f_wave_c = funWavefront_afterM4(r_w, U1, y1, H_array) / 10;
        else
            f_wave_c = funWavefront_beforeM1(r_w, U1, y1, H_array) / 10;
        end
        f_wave_total = f_wave_total + f_wave_c;
    end
    t_wave = toc(t_w_s);
    f_wave_avg = f_wave_total / N_pos;
    f_line_avg = f_line_total / N_pos;
  
    % --- 阶段 4：合并最终适应度 (Fitness) ---
    % 基础像差与遮拦保持线性比例，其他项则根据选定的策略自动转换为线性权重或0/二次方惩罚
    fitness = sysParam.weight.line * f_line_avg + ...
              sysParam.weight.wave * f_wave_avg + ...
              cost_vol + ...
              cost_aperture + ...
              cost_stroke; 
    
    timings = [t_trace, t_obs, t_vol, t_wave];
    max_D = system_max_D;
end