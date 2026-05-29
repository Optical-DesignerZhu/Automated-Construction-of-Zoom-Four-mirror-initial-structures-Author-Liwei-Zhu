function Render_Champion_3D()
    % =========================================================================
    % 🌟 离轴四反变焦系统 3D 全景渲染后处理独立脚本 (终极排版与配置前置版)
    % =========================================================================
    clear; clc; close all;
    
    % =========================================================================
    % 🎨 绘图全局参数配置区 (在这里随意修改颜色、厚度、透明度等，即改即用)
    % =========================================================================
    plotParams = struct();
    
    % 1. 颜色配置 (RGB)
    plotParams.classic_colors = [0.0, 0.3, 0.8;   % Config 1: 蓝
                                 0.8, 0.1, 0.1;   % Config 2: 红
                                 0.1, 0.6, 0.2;   % Config 3: 绿
                                 0.5, 0.0, 0.5];  % Config 4: 紫
    plotParams.fixed_mirror_color = [0.85, 0.85, 0.85];   % 固定镜基础银灰色
    plotParams.moving_mirror_gray_range = [0.85, 0.45];   % 移动镜灰度渐变范围
    plotParams.moving_mirror_tint = 0.6;                  % 移动镜染色比例
    plotParams.env_face_color = [0.90, 0.90, 0.90];       % 扫掠体积包络面颜色
    plotParams.env_edge_color = 'none';                   % 包络面网格线颜色
    
    % 2. 尺寸与厚度
    plotParams.mirror_thickness = 3;         % 镜片物理厚度 (mm)
    plotParams.ray_width = 0.3;              % 光线线宽
    plotParams.env_edge_width = 0.5;         % 包络面网格线宽
    plotParams.canvas_width_ratio = 0.9;     % 窗口占屏幕宽度的比例
    plotParams.canvas_height_ratio = 0.85;   % 窗口占屏幕高度的比例
    
    % 3. 透明度与渲染密度
    plotParams.mirror_alpha = 0.60;          % 镜片透明度 (0-1)
    plotParams.ray_alpha = 0.85;             % 光线透明度 (0-1)
    plotParams.env_face_alpha = 0.10;        % 包络面透明度 (0-1)
    plotParams.env_edge_alpha = 0.05;        % 包络面边线透明度 (0-1)
    plotParams.ray_density_step = 150;       % 光线稀疏化步长 (越大光线越少)
    plotParams.env_mesh_density = 0.5;       % 包络面网格简化密度 (0-1)
    
    % 4. 视角控制
    plotParams.view_angle = [0, 0];          % 初始观察视角 [方位角, 仰角]
    plotParams.zoom_factor = 0.9;            % 视角缩放因子
    % =========================================================================

    % 指定你的 .mat 文件绝对路径
    mat_filepath ="D:\OneDrive\PhD\Other\UndergraduateThesis_LinJvnPeng\DataResult\Batch_AZFM_Results_withoutvolWeight\Stop0\Stop0_F3_HFOV1\Data_Stop0_F3_HFOV1.mat";
    
    if ~exist(mat_filepath, 'file')
        error('🚨 找不到指定的文件，请检查路径: \n%s', mat_filepath);
    end
    
    fprintf('>> 正在加载数据: %s...\n', mat_filepath);
    data = load(mat_filepath);
    sysParam = data.sysParam;
    solutionData = data.solutionData;
    
    if strcmpi(sysParam.surfaceType, 'CON')
        numParams = 17;
    else
        numParams = 13;
    end
    N_pos = sysParam.N_pos;
    num_solutions = size(solutionData, 1); 
    num_render = min(16, num_solutions);
    
    base_dir = fileparts(mat_filepath);
    export_dir = fullfile(base_dir, 'Paper_Quality_3D_Renderings');
    if ~exist(export_dir, 'dir')
        mkdir(export_dir);
    end
    
    fprintf('>> 数据加载成功！共检测到 %d 组独立优化解。\n', num_solutions);
    fprintf('>> 正在启动 SCI 级 3D 渲染引擎...\n\n');
    
    scrn = get(0, 'ScreenSize');
    fig_size = min(scrn(3) * 0.98, scrn(4) * 0.98);
    pos_X = (scrn(3) - fig_size) / 2;
    pos_Y = (scrn(4) - fig_size) / 2;
    big_fig = figure('Name', 'Top 16 Solutions - 4x4 Rendering', 'Color', 'w', ...
                     'Position', [pos_X, pos_Y, fig_size, fig_size], 'Visible', 'off');
    tile_obj = tiledlayout(big_fig, 4, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
    ax_list = gobjects(num_render, 1);
    axis_bounds_all = NaN(num_render, 6);
    
    for r = 1:num_render
        g_opt_all = zeros(N_pos, numParams);
        for pos_idx = 1:N_pos
            start_col = (pos_idx - 1) * numParams + 1;
            end_col   = pos_idx * numParams;
            g_opt_all(pos_idx, :) = solutionData(r, start_col:end_col);
        end
        merit_val = solutionData(r, end);
        
        fprintf('  ├─ 正在渲染第 %03d/%03d 个解 (Merit: %.4f)...\n', r, num_render, merit_val);
        
        % 🌟 传入配置参数，调用核心绘图函数
        ax = nexttile(tile_obj, r);
        [~, ax, vol_3d_render, vol_merit_func, axis_bounds] = plot_3D_zoom_overlay_paper(g_opt_all, sysParam, plotParams, 'off', ax, r);
        ax_list(r) = ax;
        axis_bounds_all(r, :) = axis_bounds;
        
        % 后台打印对账面板（不在图片上显示）
        fprintf('  │   └─ [后台对账] 评价函数原生调用 (calc_MeritFunction) : %12.1f mm^3\n', vol_merit_func);
        fprintf('  │   └─ [后台对账] 3D渲染独立提取点云计算 (convhull)       : %12.1f mm^3\n', vol_3d_render);
        
        if vol_merit_func >= 9e7
            fprintf('  │   └─ [状态警报] 底层优化器追迹失败 (is_valid=false)，触发 1e8 死刑惩罚！\n');
        else
            fprintf('  │   └─ [后台对账] 偏差率: %10.6f %%\n', abs(vol_3d_render - vol_merit_func)/vol_merit_func * 100);
        end
        
    end
    
    valid_bounds = axis_bounds_all(all(isfinite(axis_bounds_all), 2), :);
    if ~isempty(valid_bounds)
        z_span_all = valid_bounds(:, 2) - valid_bounds(:, 1);
        x_span_all = valid_bounds(:, 4) - valid_bounds(:, 3);
        y_span_all = valid_bounds(:, 6) - valid_bounds(:, 5);
        shared_z_half = 0.5 * max(z_span_all) * 1.05;
        shared_x_half = 0.5 * max(x_span_all) * 1.05;
        shared_y_half = 0.5 * max(y_span_all) * 1.05;
        
        for ii = 1:num_render
            zc = mean(valid_bounds(ii, 1:2));
            xc = mean(valid_bounds(ii, 3:4));
            yc = mean(valid_bounds(ii, 5:6));
            xlim(ax_list(ii), [zc - shared_z_half, zc + shared_z_half]);
            ylim(ax_list(ii), [xc - shared_x_half, xc + shared_x_half]);
            zlim(ax_list(ii), [yc - shared_y_half, yc + shared_y_half]);
            set(ax_list(ii), 'XLimMode', 'manual', 'YLimMode', 'manual', 'ZLimMode', 'manual');
            set(ax_list(ii), 'DataAspectRatio', [1 1 1], 'PlotBoxAspectRatio', [1 1 1]);
            axis(ax_list(ii), 'vis3d');
            
            if ii <= num_render - 4
                xlabel(ax_list(ii), '');
            end
            if mod(ii - 1, 4) ~= 0
                zlabel(ax_list(ii), '');
            end
            ylabel(ax_list(ii), '');
        end
    end
    
    img_name = sprintf('Top_%02d_Solutions_4x4_600DPI.png', num_render);
    img_path = fullfile(export_dir, img_name);
    exportgraphics(big_fig, img_path, 'Resolution', 600, 'BackgroundColor', 'w');
    close(big_fig);
    
    fprintf('\n✅ 渲染结束！清爽版学术图纸已保存至:\n👉 [%s]\n', export_dir);
end

% =========================================================================
% 🌟 学术论文级渲染引擎
% =========================================================================
function [fig, ax, hull_vol_3d, hull_vol_merit, axis_bounds] = plot_3D_zoom_overlay_paper(g_opt_all, sysParam, p, isVisible, ax, solution_idx)
    if nargin < 4, isVisible = 'on'; end
    if nargin < 5, ax = []; end
    if nargin < 6, solution_idx = []; end
    axis_bounds = NaN(1, 6);
    
    if isfield(sysParam, 'stopPosition'), stopPos = sysParam.stopPosition; else, stopPos = 0; end
    N_pos = sysParam.N_pos;
    
    configs = struct();
    for i = 1:N_pos
        r_new = g_opt_all(i, :);
        configs(i).name = sprintf('Config %d (f = %.1f mm)', i, sysParam.pos(i).f);
        configs(i).r = r_new(1:4); 
        if stopPos == 5
            d_stop_img = sysParam.stopToImage;   
            dex = r_new(9) - d_stop_img;         
            configs(i).d = [r_new(6:8), dex, d_stop_img]; 
        else
            configs(i).d = r_new(5:9); 
        end
        configs(i).alpha = r_new(10:13); 
        if length(r_new) >= 17, configs(i).K_conic = r_new(14:17); else, configs(i).K_conic = [0,0,0,0]; end
        configs(i).epd = sysParam.pos(i).epd; configs(i).hfov = sysParam.pos(i).hfov;
        configs(i).fieldAnglesDeg = [configs(i).hfov, 0, -configs(i).hfov];  
    end
    
    % =========================================================================
    % 1. 执行【评价函数原生体积】调用对账
    % =========================================================================
    try
        [~, ~, ~, f_vol_unit, ~] = calc_MeritFunction(g_opt_all, sysParam);
        hull_vol_merit = f_vol_unit * 1e6;
    catch
        hull_vol_merit = NaN;
    end

    % =========================================================================
    % 2. 3D 光线追迹与光瞳构建
    % =========================================================================
    global_footprint = zeros(1, 4); 
    sim_data = struct();            
    grid_size = 5; % 光瞳基准网格
    
    for conf_idx = 1:length(configs)
        cfg = configs(conf_idx);
        r = cfg.r; d = cfg.d; alpha = cfg.alpha; K_conic = cfg.K_conic;
        epd = cfg.epd; fieldAnglesDeg = cfg.fieldAnglesDeg; N_flds = length(fieldAnglesDeg);
        
        if stopPos == 5
            O1 = [0, 0, 400]; t_gaps = [d(1), d(2), d(3), d(4)+d(5)]; 
        else
            O1 = [0, 0, d(1)]; t_gaps = [d(2), d(3), d(4), d(5)]; 
        end
        
        a12 = alpha(1) + alpha(2); a123 = a12 + alpha(3);
        O2 = O1(2:3) + t_gaps(1) * [sind(2 * alpha(1)), cosd(2 * alpha(1))];
        O3 = O2 + t_gaps(2) * [sind(2 * a12), cosd(2 * a12)];
        O4 = O3 + t_gaps(3) * [sind(2 * a123), cosd(2 * a123)];
        dir_out_global = [sind(2 * sum(alpha)), cosd(2 * sum(alpha))]; Oim = O4 + t_gaps(4) * dir_out_global;
        O_2D = [O1(2:3); O2; O3; O4]; O_3D = [zeros(4, 1), O_2D]; Oim_3D = [0, Oim];
        
        N_2D = zeros(4, 2);
        for k = 1:4
            if k == 1, u_in = [0, 1]; else, u_in = (O_2D(k,:) - O_2D(k-1,:)) / norm(O_2D(k,:) - O_2D(k-1,:)); end
            if k == 4, u_out = (Oim - O_2D(4,:)) / norm(Oim - O_2D(4,:)); else, u_out = (O_2D(k+1,:) - O_2D(k,:)) / norm(O_2D(k+1,:) - O_2D(k,:)); end
            N_bisect = u_in - u_out; N_2D(k, :) = N_bisect / norm(N_bisect);
        end
        
        if stopPos == 5
            O_stop_2D = O4 + d(4) * dir_out_global; O_stop_3D = [0, O_stop_2D];
            if isfield(sysParam, 'pos') && numel(sysParam.pos) >= conf_idx && isfield(sysParam.pos(conf_idx), 'f')
                f_curr = abs(sysParam.pos(conf_idx).f);
            else
                f_curr = abs(d(5));
            end
            F_num_ideal = f_curr / max(epd, 1e-9);
            r_stop_design = d(5) / (2 * max(F_num_ideal, 1e-9));
            v_y = dir_out_global(1); v_z = dir_out_global(2);
            M_rot_stop = [1, 0, 0; 0, v_z, -v_y; 0, v_y, v_z];
        elseif stopPos >= 1 && stopPos <= 4
            O_stop_3D = O_3D(stopPos, :); r_stop_design = epd / 2; 
            Nz_s = N_2D(stopPos, 2); Ny_s = N_2D(stopPos, 1);
            M_rot_stop = [1, 0, 0; 0, Nz_s, -Ny_s; 0, Ny_s, Nz_s];
        else
            O_stop_3D = [0, 0, 0]; r_stop_design = epd / 2; M_rot_stop = eye(3);
        end
        
        if stopPos == 0, min_z = min([O_2D(:,2); 0]); else, min_z = min(O_2D(:,2)); end
        zStart = min_z - 60;
        
        u = linspace(-1, 1, grid_size); [X_grid, Y_grid] = meshgrid(u, u); mask = (X_grid.^2 + Y_grid.^2) <= 1 + 1e-12;
        UV = [X_grid(mask), Y_grid(mask)];
        if stopPos == 0
            UV = [UV; 0, 1; 0, -1; 1, 0; -1, 0];
            [~, ia] = unique(round(UV*1e10)/1e10, 'rows', 'stable'); UV = UV(ia, :);
        end
        X_pupil = UV(:,1) * (epd / 2); Y_pupil = UV(:,2) * (epd / 2); N_rays_per_field = numel(X_pupil);
        
        P_all = []; V_all = []; Field_ID = []; 
        for fld_idx = 1:N_flds
            fld = fieldAnglesDeg(fld_idx); v_chief_2D = [sind(fld), cosd(fld)];
            
            if stopPos == 0
                X_start = X_pupil; Y_start = Y_pupil + zStart * tand(fld);
            else
                targ_X = UV(:,1) * r_stop_design; targ_Y = UV(:,2) * r_stop_design;
                y_test = linspace(-400, 400, 81)'; X_test = zeros(size(y_test));
                [errX_test, errY_test, vm_test] = trace_3D_to_stop_target(X_test, y_test, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, 0, 0, dir_out_global);
                
                err_mag = errX_test.^2 + errY_test.^2; err_mag(~vm_test) = inf; 
                [~, min_idx] = min(err_mag);
                if isinf(err_mag(min_idx)), Y_chief_guess = zStart * tand(fld); else, Y_chief_guess = y_test(min_idx); end
                X_chief_guess = 0;
                
                for iter = 1:20
                    [eX, eY, vm] = trace_3D_to_stop_target(X_chief_guess, Y_chief_guess, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, 0, 0, dir_out_global);
                    if max(abs(eX), abs(eY)) < 1e-4 || ~vm, break; end
                    h_step = 1e-4;
                    [eXx, eYx, ~] = trace_3D_to_stop_target(X_chief_guess+h_step, Y_chief_guess, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, 0, 0, dir_out_global);
                    [eXy, eYy, ~] = trace_3D_to_stop_target(X_chief_guess, Y_chief_guess+h_step, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, 0, 0, dir_out_global);
                    J11 = (eXx - eX)/h_step; J12 = (eXy - eX)/h_step; J21 = (eYx - eY)/h_step; J22 = (eYy - eY)/h_step;
                    detJ = J11*J22 - J12*J21; if abs(detJ)<1e-12, detJ=1e-12*sign(detJ+1e-16); end
                    dX = (J22*eX - J12*eY)/detJ; dY = (-J21*eX + J11*eY)/detJ;
                    X_chief_guess = X_chief_guess - dX; Y_chief_guess = Y_chief_guess - dY;
                end
                
                X_start = X_pupil + X_chief_guess; Y_start = Y_chief_guess + Y_pupil / max(cosd(fld), 1e-9);
                for iter = 1:15
                    [errX, errY, v_m] = trace_3D_to_stop_target(X_start, Y_start, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, targ_X, targ_Y, dir_out_global);
                    if max(max(abs(errX(v_m))), max(abs(errY(v_m)))) < 1e-4, break; end
                    h_step = 1e-4;
                    [eXx, eYx, ~] = trace_3D_to_stop_target(X_start+h_step, Y_start, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, targ_X, targ_Y, dir_out_global);
                    [eXy, eYy, ~] = trace_3D_to_stop_target(X_start, Y_start+h_step, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, targ_X, targ_Y, dir_out_global);
                    J11 = (eXx - errX) / h_step; J12 = (eXy - errX) / h_step; J21 = (eYx - errY) / h_step; J22 = (eYy - errY) / h_step;
                    detJ = J11 .* J22 - J12 .* J21; detJ(abs(detJ) < 1e-12) = 1e-12; 
                    dX = (J22 .* errX - J12 .* errY) ./ detJ; dY = (-J21 .* errX + J11 .* errY) ./ detJ;
                    X_start(v_m) = X_start(v_m) - dX(v_m); Y_start(v_m) = Y_start(v_m) - dY(v_m);
                end
            end
            P_all = [P_all; [X_start, Y_start, repmat(zStart, N_rays_per_field, 1)]];
            V_all = [V_all; repmat([0, v_chief_2D], N_rays_per_field, 1)]; Field_ID = [Field_ID; repmat(fld_idx, N_rays_per_field, 1)];
        end
        
        N_total_rays = size(P_all, 1); P = P_all; V = V_all; Traj = NaN(N_total_rays, 3, 6); Traj(:, :, 1) = P;
        valid_mask = true(N_total_rays, 1); 
        for k = 1:4
            R_eff = r(k); if k == 2 || k == 4, R_eff = -r(k); end
            Nz = N_2D(k, 2); Ny = N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz]; 
            P_loc = (P - O_3D(k, :)) * M_g2l'; V_loc = V * M_g2l'; c = 1 / R_eff; K = K_conic(k);
            A = c * (V_loc(:,1).^2 + V_loc(:,2).^2) + c * (1+K) * V_loc(:,3).^2;
            B = 2 * c * (P_loc(:,1).*V_loc(:,1) + P_loc(:,2).*V_loc(:,2)) - 2 * V_loc(:,3) + 2 * c * (1+K) * P_loc(:,3).*V_loc(:,3);
            C = c * (P_loc(:,1).^2 + P_loc(:,2).^2) - 2 * P_loc(:,3) + c * (1+K) * P_loc(:,3).^2;
            delta_r = B.^2 - 4 * A .* C; 
            
            t = NaN(N_total_rays, 1); is_flat = abs(c) < 1e-12; 
            if is_flat, t(valid_mask) = -P_loc(valid_mask, 3) ./ V_loc(valid_mask, 3);
            else
                sgn = sign(B); sgn(sgn == 0) = 1; q = -0.5 .* (B + sgn .* sqrt(delta_r));
                t1 = C ./ q; t2 = q ./ A;
                Z1 = P_loc(:, 3) + t1 .* V_loc(:, 3); Z2 = P_loc(:, 3) + t2 .* V_loc(:, 3);
                t_best = NaN(size(t1)); pick1 = abs(Z1) < abs(Z2);
                t_best(pick1) = t1(pick1); t_best(~pick1) = t2(~pick1);
                t(valid_mask) = t_best(valid_mask);
            end
            
            valid_mask = valid_mask & ~isnan(t) & (delta_r >= 0);
            P_hit_loc = P_loc + t .* V_loc;
            N_loc = [c * P_hit_loc(:,1), c * P_hit_loc(:,2), c * (1+K) * P_hit_loc(:,3) - 1]; N_loc = N_loc ./ sqrt(sum(N_loc.^2, 2));
            flip = sum(V_loc .* N_loc, 2) > 0; N_loc(flip, :) = -N_loc(flip, :);
            V_out_loc = V_loc - 2 .* sum(V_loc .* N_loc, 2) .* N_loc;
            P_hit_glob = P_hit_loc * M_g2l + O_3D(k, :); V = V_out_loc * M_g2l; Traj(valid_mask, :, k+1) = P_hit_glob(valid_mask, :); P = P_hit_glob;
            hits_loc_valid = P_hit_loc(valid_mask, :);
            if ~isempty(hits_loc_valid), global_footprint(k) = max(global_footprint(k), max(sqrt(hits_loc_valid(:,1).^2 + hits_loc_valid(:,2).^2))); end
        end
        N_im = [0, dir_out_global]; t_im = sum((Oim_3D - P) .* N_im, 2) ./ sum(V .* N_im, 2);
        P_im = P + t_im .* V; Traj(valid_mask, :, 6) = P_im(valid_mask, :);
        
        if any(valid_mask), dP_im = P_im(valid_mask, :) - repmat(Oim_3D, sum(valid_mask), 1); sim_data(conf_idx).r_im = max(sqrt(sum(dP_im.^2, 2)));
        else, sim_data(conf_idx).r_im = 1; end
        sim_data(conf_idx).O_3D = O_3D; sim_data(conf_idx).Oim_3D = Oim_3D; sim_data(conf_idx).Traj = Traj; sim_data(conf_idx).valid_mask = valid_mask;
        sim_data(conf_idx).P_im = P_im; sim_data(conf_idx).Field_ID = Field_ID; sim_data(conf_idx).N_2D = N_2D;
        sim_data(conf_idx).dir_out_global = dir_out_global; sim_data(conf_idx).r_stop = r_stop_design; 
        sim_data(conf_idx).O_stop_3D = O_stop_3D; sim_data(conf_idx).M_rot_stop = M_rot_stop;
    end
    mech_apertures = max(global_footprint, 1e-3); 

    % =========================================================================
    % 3. 提取独立的 3D 渲染点云进行体积计算 (包含光阑与像面)
    % =========================================================================
    vol_pts_full_path = [];
    num_rim_pts = 40;
    theta = linspace(0, 2*pi, num_rim_pts)';
    cos_theta = cos(theta);
    sin_theta = sin(theta);
    
    for conf_idx = 1:N_pos
        cfg = configs(conf_idx);
        data = sim_data(conf_idx);
        
        for k = 1:4
            c_rim = 1 / (cfg.r(k) * (1 - 2*(k==2 || k==4))); K_rim = cfg.K_conic(k); 
            Nz = data.N_2D(k, 2); Ny = data.N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz];
            
            R_rim = mech_apertures(k); 
            Xl_rim = R_rim * cos_theta; 
            Yl_rim = R_rim * sin_theta; 
            
            v_s_rim = 1 - (1+K_rim)*c_rim^2*(R_rim^2) >= 0; 
            Zl_f_rim = NaN(size(Xl_rim));
            if v_s_rim, Zl_f_rim(:) = (c_rim * R_rim^2) / (1 + sqrt(1 - (1+K_rim)*c_rim^2*R_rim^2)); 
            else, Zl_f_rim(:) = 0; end
            Zl_b_rim = Zl_f_rim + p.mirror_thickness;
            
            p_f_rim = [Xl_rim(:), Yl_rim(:), Zl_f_rim(:)] * M_g2l + data.O_3D(k, :);
            p_b_rim = [Xl_rim(:), Yl_rim(:), Zl_b_rim(:)] * M_g2l + data.O_3D(k, :);
            
            vol_pts_full_path = [vol_pts_full_path; p_f_rim(~isnan(p_f_rim(:,3)), :); p_b_rim(~isnan(p_b_rim(:,3)), :)];
        end
        
        pts_stop = [data.r_stop*cos_theta, data.r_stop*sin_theta, zeros(num_rim_pts, 1)] * data.M_rot_stop + repmat(data.O_stop_3D, num_rim_pts, 1);
        vol_pts_full_path = [vol_pts_full_path; pts_stop];
        
        M_rot_im = [1, 0, 0; 0, data.dir_out_global(2), -data.dir_out_global(1); 0, data.dir_out_global(1), data.dir_out_global(2)];
        r_im_render = data.r_im; if r_im_render < 1e-3, r_im_render = 1; end
        pts_im = [r_im_render*cos_theta, r_im_render*sin_theta, zeros(num_rim_pts, 1)] * M_rot_im + repmat(data.Oim_3D, num_rim_pts, 1);
        vol_pts_full_path = [vol_pts_full_path; pts_im];
    end
    
    hull_vol_3d = NaN;
    if size(vol_pts_full_path, 1) > 4
        N_pts = size(vol_pts_full_path, 1);
        perturb = (1:N_pts)' * 1e-8; 
        pts_f_p = vol_pts_full_path;
        pts_f_p(:,1) = pts_f_p(:,1) + perturb;
        pts_f_p(:,2) = pts_f_p(:,2) - perturb;
        pts_f_p(:,3) = pts_f_p(:,3) + perturb;
        
        [K_hull, hull_vol_3d] = convhull(pts_f_p(:,3), pts_f_p(:,1), pts_f_p(:,2), 'Simplify', false);
    end

    % =========================================================================
    % 4. 绘制图形 (纯净学术极简风格)
    % =========================================================================
    if isempty(ax) || ~isvalid(ax)
        scrn = get(0, 'ScreenSize'); 
        fig_W = scrn(3) * p.canvas_width_ratio; 
        fig_H = scrn(4) * p.canvas_height_ratio;    
        pos_X = (scrn(3) - fig_W) / 2; pos_Y = (scrn(4) - fig_H) / 2;
        
        fig = figure('Name', 'Zoom System - Publication Quality Rendering', 'Color', 'w', ...
                     'Position', [pos_X, pos_Y, fig_W, fig_H], 'Visible', isVisible); 
                     
        ax = axes('Parent', fig, 'Position', [0.10, 0.12, 0.85, 0.75]); 
    else
        fig = ancestor(ax, 'figure');
    end
    hold(ax, 'on'); grid(ax, 'on'); 
    if isempty(solution_idx)
        axis_font_size = 12;
        label_font_size = 14;
        title_font_size = 12;
    else
        axis_font_size = 7;
        label_font_size = 8;
        title_font_size = 7;
    end
    set(ax, 'FontName', 'Times New Roman', 'FontSize', axis_font_size, 'LineWidth', 0.8, 'TickDir', 'in');
    set(ax, 'GridColor', [0.6 0.6 0.6], 'GridAlpha', 0.15); 
    
    xlabel(ax, 'Optical Z (mm)', 'FontName', 'Times New Roman', 'FontSize', label_font_size, 'FontWeight', 'bold'); 
    ylabel(ax, 'Optical X (mm)', 'FontName', 'Times New Roman', 'FontSize', label_font_size, 'FontWeight', 'bold'); 
    zlabel(ax, 'Optical Y (mm)', 'FontName', 'Times New Roman', 'FontSize', label_font_size, 'FontWeight', 'bold');
    
    all_global_pts = []; h_leg = zeros(1, N_pos); leg_str = cell(1, N_pos);
    
    for conf_idx = 1:N_pos
        cfg = configs(conf_idx); data = sim_data(conf_idx); N_flds = length(cfg.fieldAnglesDeg);
        conf_color = p.classic_colors(mod(conf_idx-1, size(p.classic_colors,1))+1, :); 
        
        theta_s = linspace(0, 2*pi, 40)'; 
        pts_stop = [data.r_stop*cos(theta_s), data.r_stop*sin(theta_s), zeros(40,1)] * data.M_rot_stop + repmat(data.O_stop_3D, 40, 1);
        plot3(ax, pts_stop(:,3), pts_stop(:,1), pts_stop(:,2), '-', 'Color', conf_color, 'LineWidth', 2.0); 
        all_global_pts = [all_global_pts; pts_stop]; 
        
        M_rot_im = [1, 0, 0; 0, data.dir_out_global(2), -data.dir_out_global(1); 0, data.dir_out_global(1), data.dir_out_global(2)];
        pts_im = [data.r_im*cos(theta_s), data.r_im*sin(theta_s), zeros(40,1)] * M_rot_im + repmat(data.Oim_3D, 40, 1);
        plot3(ax, pts_im(:,3), pts_im(:,1), pts_im(:,2), '-', 'LineWidth', 1.0); 
        all_global_pts = [all_global_pts; pts_im];
        
        for fld_idx = 1:N_flds
            fld_mask = data.valid_mask & (data.Field_ID == fld_idx); valid_idx = find(fld_mask); if isempty(valid_idx), continue; end
            plot_idx = valid_idx(1:ceil(length(valid_idx)/p.ray_density_step):end); 
            X_lines = squeeze(data.Traj(plot_idx, 1, :))'; Y_lines = squeeze(data.Traj(plot_idx, 2, :))'; Z_lines = squeeze(data.Traj(plot_idx, 3, :))'; 
            X_lines(end+1, :) = NaN; Y_lines(end+1, :) = NaN; Z_lines(end+1, :) = NaN;
            plot3(ax, Z_lines(:), X_lines(:), Y_lines(:), '-', 'Color', [conf_color, p.ray_alpha], 'LineWidth', p.ray_width);
        end
        
        for k = 1:4
            c = 1 / (cfg.r(k) * (1 - 2*(k==2 || k==4))); K = cfg.K_conic(k); 
            Nz = data.N_2D(k, 2); Ny = data.N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz];
            
            [RHO, THETA] = meshgrid(linspace(0, mech_apertures(k), 60), linspace(0, 2*pi, 120)); 
            Xl = RHO .* cos(THETA); Yl = RHO .* sin(THETA); v_s = 1 - (1+K)*c^2*(Xl.^2 + Yl.^2) >= 0; Zl_f = NaN(size(Xl));
            Zl_f(v_s) = (c * (Xl(v_s).^2 + Yl(v_s).^2)) ./ (1 + sqrt(1 - (1+K)*c^2.*(Xl(v_s).^2 + Yl(v_s).^2))); Zl_b = Zl_f + p.mirror_thickness;
            
            if k == 1 || k == 3
                m_face_f = p.fixed_mirror_color; 
                m_face_b = p.fixed_mirror_color - 0.1; 
                m_edge   = p.fixed_mirror_color - 0.05;
            else
                gray_val = p.moving_mirror_gray_range(1) - (p.moving_mirror_gray_range(1) - p.moving_mirror_gray_range(2)) * ((conf_idx - 1) / max(1, N_pos - 1));
                base_c = [gray_val, gray_val, gray_val] * (1 - p.moving_mirror_tint) + conf_color * p.moving_mirror_tint;
                m_face_f = base_c; 
                m_face_b = max(0, base_c - 0.15); 
                m_edge   = max(0, base_c - 0.05);
            end
            
            p_f = [Xl(:), Yl(:), Zl_f(:)] * M_g2l + data.O_3D(k, :); surf(ax, reshape(p_f(:,3), size(Zl_f)), reshape(p_f(:,1), size(Xl)), reshape(p_f(:,2), size(Yl)), 'FaceColor', m_face_f, 'EdgeColor', 'none', 'FaceAlpha', p.mirror_alpha);
            p_b = [Xl(:), Yl(:), Zl_b(:)] * M_g2l + data.O_3D(k, :); surf(ax, reshape(p_b(:,3), size(Zl_b)), reshape(p_b(:,1), size(Xl)), reshape(p_b(:,2), size(Yl)), 'FaceColor', m_face_b, 'EdgeColor', 'none', 'FaceAlpha', p.mirror_alpha);
            
            theta_edge = linspace(0, 2*pi, 80)'; r_edge = mech_apertures(k); X_edge_c = r_edge * cos(theta_edge); Y_edge_c = r_edge * sin(theta_edge);
            Z_edge_c_f = (c * r_edge^2) ./ (1 + sqrt(1 - (1+K)*c^2*r_edge^2)); if ~isreal(Z_edge_c_f) || isnan(Z_edge_c_f), Z_edge_c_f = 0; end 
            Z_edge_c_b = Z_edge_c_f + p.mirror_thickness;
            pts_edge_f = [X_edge_c, Y_edge_c, repmat(Z_edge_c_f, length(theta_edge), 1)] * M_g2l + data.O_3D(k, :);
            pts_edge_b = [X_edge_c, Y_edge_c, repmat(Z_edge_c_b, length(theta_edge), 1)] * M_g2l + data.O_3D(k, :);
            Z_cyl = [pts_edge_f(:,3), pts_edge_b(:,3)]; X_cyl = [pts_edge_f(:,1), pts_edge_b(:,1)]; Y_cyl = [pts_edge_f(:,2), pts_edge_b(:,2)];
            surf(ax, Z_cyl, X_cyl, Y_cyl, 'FaceColor', m_edge, 'EdgeColor', 'none', 'FaceAlpha', p.mirror_alpha);
            
            all_global_pts = [all_global_pts; p_f(~isnan(p_f(:,3)),:); p_b(~isnan(p_b(:,3)),:)];
        end
        if any(data.valid_mask), all_global_pts = [all_global_pts; data.P_im(data.valid_mask, :)]; end
        all_global_pts = [all_global_pts; data.O_3D; data.O_stop_3D; data.Oim_3D];
        h_leg(conf_idx) = plot3(ax, NaN, NaN, NaN, '-', 'Color', conf_color, 'LineWidth', 3); leg_str{conf_idx} = cfg.name;
    end
    
    % 绘制包络面 (严格使用 3D 渲染独立算出的 K_hull)
    if ~isnan(hull_vol_3d) && exist('K_hull', 'var')
        fv.faces = K_hull; fv.vertices = vol_pts_full_path;
        try
            fv_reduced = reducepatch(fv, p.env_mesh_density); 
            trisurf(fv_reduced.faces, fv_reduced.vertices(:, 3), fv_reduced.vertices(:, 1), fv_reduced.vertices(:, 2), ...
                    'Parent', ax, 'FaceColor', p.env_face_color, 'EdgeColor', p.env_edge_color, 'FaceAlpha', p.env_face_alpha, 'EdgeAlpha', p.env_edge_alpha, 'LineWidth', p.env_edge_width);
        catch
            trisurf(fv.faces, fv.vertices(:, 3), fv.vertices(:, 1), fv.vertices(:, 2), ...
                    'Parent', ax, 'FaceColor', p.env_face_color, 'EdgeColor', p.env_edge_color, 'FaceAlpha', p.env_face_alpha, 'EdgeAlpha', p.env_edge_alpha, 'LineWidth', p.env_edge_width);
        end
    end
    
    % 🌟 极简图纸标题：只留下 3D Sweep Volume，剔除繁杂的对账信息
    if isempty(solution_idx)
        if isnan(hull_vol_3d)
            title_str = 'Sweep Volume: N/A';
        else
            title_str = sprintf('Sweep Volume: %.1f mm^3', hull_vol_3d);
        end
    else
        if isnan(hull_vol_3d)
            title_str = sprintf('S%02d, V=N/A', solution_idx);
        else
            title_str = sprintf('S%02d, V=%.2e mm^3', solution_idx, hull_vol_3d);
        end
    end
    title(ax, title_str, 'FontName', 'Times New Roman', 'FontSize', title_font_size, 'FontWeight', 'bold', 'Color', 'k');

    if ~isempty(all_global_pts)
        z_min = min(all_global_pts(:,3)); z_max = max(all_global_pts(:,3));
        x_min = min(all_global_pts(:,1)); x_max = max(all_global_pts(:,1));
        y_min = min(all_global_pts(:,2)); y_max = max(all_global_pts(:,2));
        
        visible_span = max([z_max - z_min, y_max - y_min, x_max - x_min, 1]) * 1.03;
        cz = (z_max + z_min)/2;
        cx = (x_max + x_min)/2;
        cy = (y_max + y_min)/2;
        
        xlim(ax, [cz - visible_span / 2, cz + visible_span / 2]); 
        ylim(ax, [cx - visible_span / 2, cx + visible_span / 2]); 
        zlim(ax, [cy - visible_span / 2, cy + visible_span / 2]);
        axis_bounds = [z_min, z_max, x_min, x_max, y_min, y_max];
    end
    
    set(ax, 'DataAspectRatio', [1 1 1], 'PlotBoxAspectRatio', [1 1 1]);
    set(ax, 'CameraViewAngleMode', 'manual');
    view(ax, p.view_angle(1), p.view_angle(2)); camzoom(ax, p.zoom_factor); 
    camlight(ax); lighting(ax, 'gouraud'); 
    if isempty(solution_idx)
        legend(ax, h_leg, leg_str, 'Location', 'southwest', 'FontName', 'Times New Roman', 'FontSize', 12, 'Box', 'on');
    end
end

function [errX, errY, valid_mask] = trace_3D_to_stop_target(X0, Y0, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, targ_X, targ_Y, dir_out_global)
    P = [X0, Y0, repmat(zStart, length(X0), 1)]; V = repmat([0, sind(fld), cosd(fld)], length(X0), 1); valid_mask = true(length(X0), 1);
    target_k = 4; if stopPos >= 1 && stopPos <= 4, target_k = stopPos; end
    
    for k = 1:target_k
        R_eff = r(k); if k == 2 || k == 4, R_eff = -R_eff; end
        Nz = N_2D(k, 2); Ny = N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz];
        P_loc = (P - O_3D(k, :)) * M_g2l'; V_loc = V * M_g2l'; c = 1 / R_eff; K = K_conic(k);
        
        A = c * (V_loc(:,1).^2 + V_loc(:,2).^2) + c * (1+K) * V_loc(:,3).^2;
        B = 2 * c * (P_loc(:,1).*V_loc(:,1) + P_loc(:,2).*V_loc(:,2)) - 2 * V_loc(:,3) + 2 * c * (1+K) * P_loc(:,3).*V_loc(:,3);
        C = c * (P_loc(:,1).^2 + P_loc(:,2).^2) - 2 * P_loc(:,3) + c * (1+K) * P_loc(:,3).^2;
        delta = B.^2 - 4 * A .* C; valid_mask = valid_mask & (delta >= 0);
        
        t = NaN(size(X0)); is_flat = abs(c) < 1e-12;
        if is_flat, t(valid_mask) = -P_loc(valid_mask, 3) ./ V_loc(valid_mask, 3);
        else
            sgn = sign(B); sgn(sgn == 0) = 1; q = -0.5 .* (B + sgn .* sqrt(delta));
            t1 = C ./ q; t2 = q ./ A; 
            Z1 = P_loc(:, 3) + t1 .* V_loc(:, 3); Z2 = P_loc(:, 3) + t2 .* V_loc(:, 3);
            t_best = NaN(size(t1)); pick1 = abs(Z1) < abs(Z2);
            t_best(pick1) = t1(pick1); t_best(~pick1) = t2(~pick1);
            t(valid_mask) = t_best(valid_mask);
        end
        valid_mask = valid_mask & ~isnan(t) & (t > 0); P_hit_loc = P_loc + t .* V_loc; P = P_hit_loc * M_g2l + O_3D(k, :);
        if k == target_k && stopPos >= 1 && stopPos <= 4, break; end
        N_loc = [c * P_hit_loc(:,1), c * P_hit_loc(:,2), c * (1+K) * P_hit_loc(:,3) - 1]; 
        N_loc = N_loc ./ sqrt(sum(N_loc.^2, 2)); flip = sum(V_loc .* N_loc, 2) > 0; N_loc(flip, :) = -N_loc(flip, :);
        V_out_loc = V_loc - 2 .* sum(V_loc .* N_loc, 2) .* N_loc; V = V_out_loc * M_g2l;
    end
    
    if stopPos == 5
        N_stop_plane = [0, dir_out_global]; den = sum(V .* N_stop_plane, 2); valid_mask = valid_mask & (abs(den) > 1e-12);
        t_stop = sum((repmat(O_stop_3D, length(X0), 1) - P) .* N_stop_plane, 2) ./ den; P_stop = P + t_stop .* V;
    else, P_stop = P; end
    
    P_s_loc = (P_stop - repmat(O_stop_3D, length(X0), 1)) * M_rot_stop'; errX = P_s_loc(:, 1) - targ_X; errY = P_s_loc(:, 2) - targ_Y;
    errX(~valid_mask) = 0; errY(~valid_mask) = 0;
end
