function [fig, ax] = plot_3D_zoom_overlay(g_opt_all, sysParam, isVisible, target_ax)
% plot_3D_zoom_overlay - 连续变焦系统全景 3D 叠加渲染器
% 输出:
%   fig       : 渲染生成的图形窗口句柄 (Figure Handle)
%   ax        : 渲染生成的坐标轴句柄 (Axes Handle)
% 输入:
%   g_opt_all : 多组态优化解矩阵
%   sysParam  : 系统参数结构体
%   isVisible : 'on' (显示窗口) 或 'off' (后台静默渲染不弹窗)

    % ========================== ★ 参数处理 ★ ==========================
    % 如果未传入 isVisible 参数，则默认显示图形窗口
    if nargin < 3
        isVisible = 'on'; 
    end
    if nargin < 4
        target_ax = [];
    end

    % ========================== ★ 全局显示设置 (Global Display Settings) ★ ==========================
    canvas_width_ratio  = 0.9;     % 绘图窗口占屏幕宽度的比例 (0~1)
    canvas_height_ratio = 0.85;    % 绘图窗口占屏幕高度的比例 (0~1)
    mirror_alpha = 0.55;           % 反射镜实体的透明度 (0为全透明，1为不透明)
    mirror_thickness = 3;          % 反射镜的物理厚度 (mm)
    grid_size = 5;                 % 光瞳采样网格的尺寸 (如 5x5 的光线阵列)
    ray_density_step = 150;        % 渲染光线的稀疏化步长 (数值越大，画出的光线越少，防卡顿)
    ray_alpha = 0.85;              % 光线的透明度
    ray_width = 0.8;               % 光线的线宽
    moving_mirror_gray_range = [0.85, 0.35]; % 移动镜 (M2/M4) 在变焦不同组态下的灰度渐变范围 (模拟运动轨迹)
    moving_mirror_tint       = 0.8;          % 移动镜颜色中混入组态主题色的比例 (0~1)
    fixed_mirror_color       = [0.9 0.9 0.9];% 固定镜 (M1/M3) 的基础颜色 (浅灰色)
    env_face_color = [0.6 0.9 1.0]; % 扫掠体积外包络面的颜色 (浅蓝色)
    env_face_alpha = 0.15;          % 扫掠体积外包络面的透明度
    env_edge_color = 'none';        % 扫掠体积网格线颜色 ('none' 表示不显示网格线)
    env_edge_alpha = 0.1;           % 扫掠体积网格线的透明度
    env_edge_width = 0.5;           % 扫掠体积网格线的宽度
    env_mesh_density = 0.5;         % 扫掠体积网格的简化密度 (0~1，减小可以提升渲染流畅度)
    view_angle = [0, 0];            % 3D 视图的初始观察视角 (方位角与仰角，[0,0] 为 X-Z 正视图)
    zoom_factor = 0.9;              % 视角的初始缩放因子
    % =================================================================================
    
    if isfield(sysParam, 'stopPosition'), stopPos = sysParam.stopPosition; else, stopPos = 0; end
    N_pos = sysParam.N_pos;
    config_colors = jet(N_pos); 
    
    configs = struct();
    for i = 1:N_pos
        r_new = g_opt_all(i, :);
        configs(i).name = sprintf('Config %d: f=%.1f', i, sysParam.pos(i).f);
        configs(i).r = r_new(1:4); 
        
        if stopPos == 5
            d_stop_img = sysParam.stopToImage;   
            dex = r_new(9) - d_stop_img;         
            configs(i).d = [r_new(6:8), dex, d_stop_img]; 
        else
            configs(i).d = r_new(5:9); 
        end
        
        configs(i).alpha = r_new(10:13); 
        if isfield(sysParam, 'K_conic'), configs(i).K_conic = sysParam.K_conic; else, configs(i).K_conic = [0,0,0,0]; end
        configs(i).epd = sysParam.pos(i).epd;
        configs(i).hfov = sysParam.pos(i).hfov;
        configs(i).fieldAnglesDeg = [configs(i).hfov, 0, -configs(i).hfov];  
    end
    
    global_footprint = zeros(1, 4); 
    sim_data = struct();            
    fprintf('\n=== 正在计算 N 组态全局变焦空间轨迹 (搭载 3D 强力光线瞄准) ===\n');
    
    for conf_idx = 1:length(configs)
        cfg = configs(conf_idx);
        r = cfg.r; d = cfg.d; alpha = cfg.alpha; K_conic = cfg.K_conic;
        epd = cfg.epd; fieldAnglesDeg = cfg.fieldAnglesDeg; N_flds = length(fieldAnglesDeg);
        
        if stopPos == 5
            O1 = [0, 0, 400];
            t_gaps = [d(1), d(2), d(3), d(4)+d(5)]; 
        else
            O1 = [0, 0, d(1)];  
            t_gaps = [d(2), d(3), d(4), d(5)]; 
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
        
        % 🌟 光阑几何属性计算
        if stopPos == 5
            O_stop_2D = O4 + d(4) * dir_out_global;
            O_stop_3D = [0, O_stop_2D];
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
            O_stop_3D = O_3D(stopPos, :);
            r_stop_design = epd / 2; % 预估值，渲染用
            Nz_s = N_2D(stopPos, 2); Ny_s = N_2D(stopPos, 1);
            M_rot_stop = [1, 0, 0; 0, Nz_s, -Ny_s; 0, Ny_s, Nz_s];
        else
            O_stop_3D = [0, 0, 0];
            r_stop_design = epd / 2;
            M_rot_stop = eye(3);
        end
        
        if stopPos == 0
            min_z = min([O_2D(:,2); 0]);
        else
            min_z = min(O_2D(:,2));
        end
        zStart = min_z - 60;
        
        % 瞳面网格生成
        u = linspace(-1, 1, grid_size);
        [X_grid, Y_grid] = meshgrid(u, u);
        mask = (X_grid.^2 + Y_grid.^2) <= 1 + 1e-12;
        UV = [X_grid(mask), Y_grid(mask)];
        if stopPos == 0
            UV = [UV; 0, 1; 0, -1; 1, 0; -1, 0];
            [~, ia] = unique(round(UV*1e10)/1e10, 'rows', 'stable');
            UV = UV(ia, :);
        end
        X_pupil = UV(:,1) * (epd / 2);
        Y_pupil = UV(:,2) * (epd / 2);
        N_rays_per_field = numel(X_pupil);
        
        P_all = []; V_all = []; Field_ID = []; 
        for fld_idx = 1:N_flds
            fld = fieldAnglesDeg(fld_idx);
            v_chief_2D = [sind(fld), cosd(fld)];
            
            % =========================================================
            % 🌟 全矢量化 3D 牛顿迭代光线瞄准
            % =========================================================
            if stopPos == 0
                % 光阑前置，纯几何投射，无需迭代
                X_start = X_pupil;
                Y_start = Y_pupil + zStart * tand(fld);
            else
                % 光阑在内部或后置，计算物理靶心，进行 3D 双向制导
                targ_X = UV(:,1) * r_stop_design;
                targ_Y = UV(:,2) * r_stop_design;
                
                % 初始猜测
                X_start = X_pupil; 
                Y_start = zStart * tand(fld) + Y_pupil / max(cosd(fld), 1e-9);
                
                for iter = 1:15
                    [errX, errY, v_m] = trace_3D_to_stop_target(X_start, Y_start, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, targ_X, targ_Y, dir_out_global);
                    
                    if max(max(abs(errX(v_m))), max(abs(errY(v_m)))) < 1e-4
                        break;
                    end
                    
                    % 有限差分算雅可比矩阵
                    delta = 1e-4;
                    [eXx, eYx, ~] = trace_3D_to_stop_target(X_start+delta, Y_start, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, targ_X, targ_Y, dir_out_global);
                    [eXy, eYy, ~] = trace_3D_to_stop_target(X_start, Y_start+delta, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, targ_X, targ_Y, dir_out_global);
                    
                    J11 = (eXx - errX) / delta; J12 = (eXy - errX) / delta;
                    J21 = (eYx - errY) / delta; J22 = (eYy - errY) / delta;
                    
                    detJ = J11 .* J22 - J12 .* J21; 
                    detJ(abs(detJ) < 1e-12) = 1e-12; 
                    
                    dX = (J22 .* errX - J12 .* errY) ./ detJ;
                    dY = (-J21 .* errX + J11 .* errY) ./ detJ;
                    
                    X_start(v_m) = X_start(v_m) - dX(v_m);
                    Y_start(v_m) = Y_start(v_m) - dY(v_m);
                end
            end
            
            P_all = [P_all; [X_start, Y_start, repmat(zStart, N_rays_per_field, 1)]];
            V_all = [V_all; repmat([0, v_chief_2D], N_rays_per_field, 1)];
            Field_ID = [Field_ID; repmat(fld_idx, N_rays_per_field, 1)];
        end
        
        % --- 携带瞄准好的精准坐标，执行 3D 全局光路追迹 ---
        N_total_rays = size(P_all, 1); P = P_all; V = V_all; Traj = NaN(N_total_rays, 3, 6); Traj(:, :, 1) = P;
        valid_mask = true(N_total_rays, 1); 
        
        for k = 1:4
            R_eff = r(k); if k == 2 || k == 4, R_eff = -r(k); end
            Nz = N_2D(k, 2); Ny = N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz]; 
            P_loc = (P - O_3D(k, :)) * M_g2l'; V_loc = V * M_g2l'; c = 1 / R_eff; K = K_conic(k);
            A = c * (V_loc(:,1).^2 + V_loc(:,2).^2) + c * (1+K) * V_loc(:,3).^2;
            B = 2 * c * (P_loc(:,1).*V_loc(:,1) + P_loc(:,2).*V_loc(:,2)) - 2 * V_loc(:,3) + 2 * c * (1+K) * P_loc(:,3).*V_loc(:,3);
            C = c * (P_loc(:,1).^2 + P_loc(:,2).^2) - 2 * P_loc(:,3) + c * (1+K) * P_loc(:,3).^2;
            t = NaN(N_total_rays, 1); is_flat = abs(c) < 1e-12; t(is_flat) = -P_loc(is_flat, 3) ./ V_loc(is_flat, 3);
            curved = ~is_flat & valid_mask; delta = B.^2 - 4 * A .* C; val = curved & (delta >= 0);
            sgn = sign(B(val)); sgn(sgn == 0) = 1; q = -0.5 .* (B(val) + sgn .* sqrt(delta(val)));
            t1 = C(val) ./ q; t2 = q ./ A(val);
            t_best = NaN(size(t1)); m1 = t1 > 1e-6; m2 = t2 > 1e-6; both = m1 & m2; t_best(both) = min(t1(both), t2(both));
            t_best(m1 & ~m2) = t1(m1 & ~m2); t_best(m2 & ~m1) = t2(m2 & ~m1); t(val) = t_best;
            valid_mask = valid_mask & ~isnan(t) & (t > 0);
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
        
        if any(valid_mask)
            dP_im = P_im(valid_mask, :) - repmat(Oim_3D, sum(valid_mask), 1);
            sim_data(conf_idx).r_im = max(sqrt(sum(dP_im.^2, 2)));
        else
            sim_data(conf_idx).r_im = 1;
        end
        sim_data(conf_idx).O_3D = O_3D; sim_data(conf_idx).Oim_3D = Oim_3D; 
        sim_data(conf_idx).Traj = Traj; sim_data(conf_idx).valid_mask = valid_mask;
        sim_data(conf_idx).P_im = P_im; sim_data(conf_idx).Field_ID = Field_ID; sim_data(conf_idx).N_2D = N_2D;
        sim_data(conf_idx).dir_out_global = dir_out_global;
        sim_data(conf_idx).r_stop = r_stop_design; sim_data(conf_idx).O_stop_3D = O_stop_3D; sim_data(conf_idx).M_rot_stop = M_rot_stop;
    end
    mech_apertures = max(global_footprint, 1e-3); 
    
    % =========================================================================
    % [阶段 2: 全景 3D 渲染]
    % =========================================================================
    if isempty(target_ax) || ~isvalid(target_ax)
        scrn = get(0, 'ScreenSize'); screen_W = scrn(3); screen_H = scrn(4);
        fig_W = screen_W * canvas_width_ratio; fig_H = screen_H * canvas_height_ratio;    
        pos_X = (screen_W - fig_W) / 2; pos_Y = (screen_H - fig_H) / 2;
    
    % 🌟 在此处应用 isVisible 开关，控制窗口是否静默在后台
        fig = figure('Name', 'Zoom System - All Configurations Overlay', 'Color', 'w', ...
                     'Position', [pos_X, pos_Y, fig_W, fig_H], 'Visible', isVisible); 
        ax = axes('Parent', fig, 'Position', [0.10, 0.10, 0.85, 0.80]); 
    else
        ax = target_ax;
        fig = ancestor(ax, 'figure');
        cla(ax);
    end
    hold(ax, 'on'); grid(ax, 'on'); 
    axes(ax);
    xlabel(ax, 'Optical Z (mm)', 'FontSize', 12, 'FontWeight', 'bold'); 
    ylabel(ax, 'Optical X (Depth)', 'FontSize', 12, 'FontWeight', 'bold'); 
    zlabel(ax, 'Optical Y (mm)', 'FontSize', 12, 'FontWeight', 'bold');
    
    all_global_pts = []; h_leg = zeros(1, N_pos); leg_str = cell(1, N_pos);
    
    for conf_idx = 1:N_pos
        cfg = configs(conf_idx); data = sim_data(conf_idx); N_flds = length(cfg.fieldAnglesDeg);
        conf_color = config_colors(conf_idx, :);
        
        theta_s = linspace(0, 2*pi, 40)'; 
        
        % 画出最真实物理尺寸的光阑圆盘
        r_stop = data.r_stop;
        pts_stop = [r_stop*cos(theta_s), r_stop*sin(theta_s), zeros(40,1)] * data.M_rot_stop + repmat(data.O_stop_3D, 40, 1);
        plot3(ax, pts_stop(:,3), pts_stop(:,1), pts_stop(:,2), '-', 'Color', conf_color, 'LineWidth', 2.0); 
        all_global_pts = [all_global_pts; pts_stop]; 
        
        % 画出像面真实边界
        r_im = data.r_im;
        v_y = data.dir_out_global(1); v_z = data.dir_out_global(2);
        M_rot_im = [1, 0, 0; 0, v_z, -v_y; 0, v_y, v_z];
        pts_im = [r_im*cos(theta_s), r_im*sin(theta_s), zeros(40,1)] * M_rot_im + repmat(data.Oim_3D, 40, 1);
        plot3(ax, pts_im(:,3), pts_im(:,1), pts_im(:,2), 'k--', 'LineWidth', 1.0); 
        all_global_pts = [all_global_pts; pts_im];
        
        for fld_idx = 1:N_flds
            fld_mask = data.valid_mask & (data.Field_ID == fld_idx);
            valid_idx = find(fld_mask); if isempty(valid_idx), continue; end
            plot_idx = valid_idx(1:ceil(length(valid_idx)/ray_density_step):end); 
            X_lines = squeeze(data.Traj(plot_idx, 1, :))'; Y_lines = squeeze(data.Traj(plot_idx, 2, :))'; Z_lines = squeeze(data.Traj(plot_idx, 3, :))'; 
            X_lines(end+1, :) = NaN; Y_lines(end+1, :) = NaN; Z_lines(end+1, :) = NaN;
            plot3(ax, Z_lines(:), X_lines(:), Y_lines(:), '-', 'Color', [conf_color, ray_alpha], 'LineWidth', ray_width);
        end
        
        for k = 1:4
            c = 1 / (cfg.r(k) * (1 - 2*(k==2 || k==4))); K = cfg.K_conic(k); 
            Nz = data.N_2D(k, 2); Ny = data.N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz];
            [RHO, THETA] = meshgrid(linspace(0, mech_apertures(k), 20), linspace(0, 2*pi, 40)); 
            Xl = RHO .* cos(THETA); Yl = RHO .* sin(THETA);
            v_s = 1 - (1+K)*c^2*(Xl.^2 + Yl.^2) >= 0; Zl_f = NaN(size(Xl));
            Zl_f(v_s) = (c * (Xl(v_s).^2 + Yl(v_s).^2)) ./ (1 + sqrt(1 - (1+K)*c^2.*(Xl(v_s).^2 + Yl(v_s).^2)));
            Zl_b = Zl_f + mirror_thickness;
            
            if k == 1 || k == 3, m_face_f = fixed_mirror_color; m_face_b = fixed_mirror_color - 0.1; m_edge = fixed_mirror_color - 0.05;
            else
                gray_val = moving_mirror_gray_range(1) - (moving_mirror_gray_range(1) - moving_mirror_gray_range(2)) * ((conf_idx - 1) / max(1, N_pos - 1));
                base_c = [gray_val, gray_val, gray_val] * (1 - moving_mirror_tint) + conf_color * moving_mirror_tint;
                m_face_f = base_c; m_face_b = max(0, base_c - 0.15); m_edge = max(0, base_c - 0.05);
            end
            
            p_f = [Xl(:), Yl(:), Zl_f(:)] * M_g2l + data.O_3D(k, :);
            surf(ax, reshape(p_f(:,3), size(Zl_f)), reshape(p_f(:,1), size(Xl)), reshape(p_f(:,2), size(Yl)), 'FaceColor', m_face_f, 'EdgeColor', 'none', 'FaceAlpha', mirror_alpha);
            p_b = [Xl(:), Yl(:), Zl_b(:)] * M_g2l + data.O_3D(k, :);
            surf(ax, reshape(p_b(:,3), size(Zl_b)), reshape(p_b(:,1), size(Xl)), reshape(p_b(:,2), size(Yl)), 'FaceColor', m_face_b, 'EdgeColor', 'none', 'FaceAlpha', mirror_alpha);
            
            theta_edge = linspace(0, 2*pi, 60)'; r_edge = mech_apertures(k);
            X_edge_c = r_edge * cos(theta_edge); Y_edge_c = r_edge * sin(theta_edge);
            Z_edge_c_f = (c * r_edge^2) ./ (1 + sqrt(1 - (1+K)*c^2*r_edge^2));
            if ~isreal(Z_edge_c_f) || isnan(Z_edge_c_f), Z_edge_c_f = 0; end 
            Z_edge_c_b = Z_edge_c_f + mirror_thickness;
            
            pts_edge_f = [X_edge_c, Y_edge_c, repmat(Z_edge_c_f, length(theta_edge), 1)] * M_g2l + data.O_3D(k, :);
            pts_edge_b = [X_edge_c, Y_edge_c, repmat(Z_edge_c_b, length(theta_edge), 1)] * M_g2l + data.O_3D(k, :);
            Z_cyl = [pts_edge_f(:,3), pts_edge_b(:,3)]; X_cyl = [pts_edge_f(:,1), pts_edge_b(:,1)]; Y_cyl = [pts_edge_f(:,2), pts_edge_b(:,2)];
            surf(ax, Z_cyl, X_cyl, Y_cyl, 'FaceColor', m_edge, 'EdgeColor', 'none', 'FaceAlpha', mirror_alpha);
            
            all_global_pts = [all_global_pts; p_f(~isnan(p_f(:,3)),:); p_b(~isnan(p_b(:,3)),:)];
        end
        
        if any(data.valid_mask), all_global_pts = [all_global_pts; data.P_im(data.valid_mask, :)]; end
        h_leg(conf_idx) = plot3(ax, NaN, NaN, NaN, '-', 'Color', conf_color, 'LineWidth', 3);
        leg_str{conf_idx} = cfg.name;
    end
    
    if size(all_global_pts, 1) > 4
        [K_hull, hull_vol] = convhull(all_global_pts(:,3), all_global_pts(:,1), all_global_pts(:,2));
        fv.faces = K_hull; fv.vertices = all_global_pts;
        fv_reduced = reducepatch(fv, env_mesh_density); 
        trisurf(fv_reduced.faces, fv_reduced.vertices(:, 3), fv_reduced.vertices(:, 1), fv_reduced.vertices(:, 2), ...
                'Parent', ax, 'FaceColor', env_face_color, 'EdgeColor', env_edge_color, ...
                'FaceAlpha', env_face_alpha, 'EdgeAlpha', env_edge_alpha, 'LineWidth', env_edge_width);
        
        title_str = {sprintf('Continuous Zoom %d-Configurations Overlay 3D Layout', N_pos), ...
                     sprintf('\\color{red}Sweep Volume: %.1f mm^3', hull_vol)};
        title(ax, title_str, 'FontSize', 16, 'FontWeight', 'bold');
    else
        title(ax, sprintf('Continuous Zoom %d-Configurations Overlay 3D Layout', N_pos), 'FontSize', 16, 'FontWeight', 'bold');
    end
    
    axis(ax, 'equal'); axis(ax, 'tight'); 
    view(ax, view_angle(1), view_angle(2)); camzoom(ax, zoom_factor); 
    camlight(ax); lighting(ax, 'gouraud'); legend(ax, h_leg, leg_str, 'Location', 'best', 'FontSize', 12, 'Box', 'on');
    fprintf('>> 全局叠加渲染完成！\n');
end

% ==================== 专为 3D 瞄准打造的核心算法 ====================
function [errX, errY, valid_mask] = trace_3D_to_stop_target(X0, Y0, zStart, fld, r, K_conic, O_3D, N_2D, stopPos, O_stop_3D, M_rot_stop, targ_X, targ_Y, dir_out_global)
    P = [X0, Y0, repmat(zStart, length(X0), 1)];
    V = repmat([0, sind(fld), cosd(fld)], length(X0), 1);
    valid_mask = true(length(X0), 1);
    
    target_k = 4;
    if stopPos >= 1 && stopPos <= 4, target_k = stopPos; end
    
    for k = 1:target_k
        R_eff = r(k); if k == 2 || k == 4, R_eff = -R_eff; end
        Nz = N_2D(k, 2); Ny = N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz];
        P_loc = (P - O_3D(k, :)) * M_g2l'; V_loc = V * M_g2l'; c = 1 / R_eff; K = K_conic(k);
        
        A = c * (V_loc(:,1).^2 + V_loc(:,2).^2) + c * (1+K) * V_loc(:,3).^2;
        B = 2 * c * (P_loc(:,1).*V_loc(:,1) + P_loc(:,2).*V_loc(:,2)) - 2 * V_loc(:,3) + 2 * c * (1+K) * P_loc(:,3).*V_loc(:,3);
        C = c * (P_loc(:,1).^2 + P_loc(:,2).^2) - 2 * P_loc(:,3) + c * (1+K) * P_loc(:,3).^2;
        delta = B.^2 - 4 * A .* C; 
        valid_mask = valid_mask & (delta >= 0);
        
        t = NaN(size(X0)); is_flat = abs(c) < 1e-12;
        if is_flat, t(valid_mask) = -P_loc(valid_mask, 3) ./ V_loc(valid_mask, 3);
        else
            sgn = sign(B); sgn(sgn == 0) = 1; q = -0.5 .* (B + sgn .* sqrt(delta));
            t1 = C ./ q; t2 = q ./ A; 
            t_best = NaN(size(t1)); m1 = t1 > 1e-6; m2 = t2 > 1e-6;
            both = m1 & m2; t_best(both) = min(t1(both), t2(both)); 
            t_best(m1 & ~m2) = t1(m1 & ~m2); t_best(m2 & ~m1) = t2(m2 & ~m1);
            t(valid_mask) = t_best(valid_mask);
        end
        valid_mask = valid_mask & ~isnan(t) & (t > 0);
        
        P_hit_loc = P_loc + t .* V_loc;
        P = P_hit_loc * M_g2l + O_3D(k, :);
        
        if k == target_k && stopPos >= 1 && stopPos <= 4, break; end
        
        N_loc = [c * P_hit_loc(:,1), c * P_hit_loc(:,2), c * (1+K) * P_hit_loc(:,3) - 1]; 
        N_loc = N_loc ./ sqrt(sum(N_loc.^2, 2)); flip = sum(V_loc .* N_loc, 2) > 0; N_loc(flip, :) = -N_loc(flip, :);
        V_out_loc = V_loc - 2 .* sum(V_loc .* N_loc, 2) .* N_loc; V = V_out_loc * M_g2l;
    end
    
    if stopPos == 5
        N_stop_plane = [0, dir_out_global]; 
        den = sum(V .* N_stop_plane, 2);
        valid_mask = valid_mask & (abs(den) > 1e-12);
        t_stop = sum((repmat(O_stop_3D, length(X0), 1) - P) .* N_stop_plane, 2) ./ den;
        P_stop = P + t_stop .* V;
    else
        P_stop = P; 
    end
    
    P_s_loc = (P_stop - repmat(O_stop_3D, length(X0), 1)) * M_rot_stop'; 
    errX = P_s_loc(:, 1) - targ_X; 
    errY = P_s_loc(:, 2) - targ_Y;
    errX(~valid_mask) = 0; errY(~valid_mask) = 0;
end
