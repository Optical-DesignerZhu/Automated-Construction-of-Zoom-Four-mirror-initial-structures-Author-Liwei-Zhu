function trace_3D_wavefront_zemax_matched()
    % =========================================================================
    % 3D Vectorized Ray Tracing (CodeV Matched)
    % 完美细节版 (English UI)：
    % 1. 图内数据浮窗显示，完美支持 mm^3 上标 (TeX 解释器)。
    % 2. 镜片侧面采用强制闭合圆柱逻辑，彻底修复镂空现象，完美呈现 3D 玻璃质感。
    % 3. 包络体积采集包含所有光线在像面的实际落点，实现真正的全包裹 Convex Hull。
    % =========================================================================
    
    % ========================== ★ Global Display Settings ★ ==========================
    mirror_alpha = 0.5;         % Mirror Substrate Transparency (调高了一点透明度显得更实体)
    mirror_thickness = 7;      % Mirror Substrate Thickness (mm)
    
    box_face_alpha = 0.12;      % Envelope Volume Face Transparency (包络填充)
    box_edge_alpha = 0.25;      % Envelope Volume Edge Transparency (包络线框)
    
    grid_size = 64;             % Ray Sampling Grid Size
    % =================================================================================
    
    stopPos = 0;            
    lambda = 0.0005876;      
    field_colors = [0 0.4470 0.7410; 0.4660 0.6740 0.1880; 0.8500 0.3250 0.0980];
    
    % --- 1. Define Multi-Configurations ---
    configs(1).name = 'Config 1: Nominal (EPD=20, 3 Fields)';
    configs(1).r = [-2.223970000000000E+003, 1.008460000000000E+003, 2.416660000000000E+002, 3.708250000000000E+002]; 
    configs(1).d = [234.475, -6.800000000000000E+002, 6.756160000000000E+002, -3.284670000000000E+002, 3.298630000000000E+002]; 
    configs(1).alpha = [-2.199980000000000E+001, 2.207590000000000E+000, -1.234200000000000E+001, 1.477910000000000E+000]; 
    configs(1).K_conic = [0, 0, 0, 0]; 
    configs(1).epd = 20;                     
    configs(1).fieldAnglesDeg = [ 1, 0, -1];  
    
    % configs(2).name = 'Config 2: M4 Focused (EPD=40, 3 Fields)';
    % configs(2).r = [-2223.97, 1008.46, 241.666, 370.825]; 
    % configs(2).d = [234.475, -415.653, 412.556, -342.32, 343.733]; 
    % configs(2).alpha = [-21.9998, 3.62128, -13.6958, 1.4181];     
    % configs(2).K_conic = [0, 0, 0, 0]; 
    % configs(2).epd = 40;                     
    % configs(2).fieldAnglesDeg = [ 0.5, 0, -0.5];    

    % =========================================================================
    % [Phase 1: Ray Tracing Engine]
    % =========================================================================
    global_footprint = zeros(1, 4); 
    sim_data = struct();            
    
    fprintf('=== Starting Ray Tracing and Envelope Analysis ===\n');
    for conf_idx = 1:length(configs)
        cfg = configs(conf_idx);
        r = cfg.r; d = cfg.d; alpha = cfg.alpha; K_conic = cfg.K_conic;
        epd = cfg.epd; fieldAnglesDeg = cfg.fieldAnglesDeg;
        N_flds = length(fieldAnglesDeg);
        
        O1 = [0, 0, d(1)];  
        if stopPos == 5, t_gaps = [d(2), d(3), d(4), d(4)+d(5)];
        else, t_gaps = [d(2), d(3), d(4), d(5)]; end
        
        a12 = alpha(1) + alpha(2); a123 = a12 + alpha(3);
        O2 = O1(2:3) + t_gaps(1) * [sind(2 * alpha(1)), cosd(2 * alpha(1))];
        O3 = O2 + t_gaps(2) * [sind(2 * a12), cosd(2 * a12)];
        O4 = O3 + t_gaps(3) * [sind(2 * a123), cosd(2 * a123)];
        
        dir_out_global = [sind(2 * sum(alpha)), cosd(2 * sum(alpha))];
        Oim = O4 + t_gaps(4) * dir_out_global;
        
        O_2D = [O1(2:3); O2; O3; O4]; 
        O_3D = [zeros(4, 1), O_2D]; 
        Oim_3D = [0, Oim];
        
        N_2D = zeros(4, 2);
        for k = 1:4
            if k == 1, u_in = [0, 1]; else, u_in = (O_2D(k,:) - O_2D(k-1,:)) / norm(O_2D(k,:) - O_2D(k-1,:)); end
            if k == 4, u_out = (Oim - O_2D(4,:)) / norm(Oim - O_2D(4,:)); else, u_out = (O_2D(k+1,:) - O_2D(k,:)) / norm(O_2D(k+1,:) - O_2D(k,:)); end
            N_bisect = u_in - u_out; N_2D(k, :) = N_bisect / norm(N_bisect);
        end
        
        zStart = -60; 
        
        [R_ref_global, EXPD_global, z_EP_from_M4] = get_zemax_paraxial_data(r, d, epd);
        P_XP_global = O_3D(4, :) + z_EP_from_M4 * [0, dir_out_global]; 
        
        u = linspace(-1 + 1/grid_size, 1 - 1/grid_size, grid_size); 
        [X_grid, Y_grid] = meshgrid(u, u);
        mask = (X_grid.^2 + Y_grid.^2) <= 1; 
        X_pupil = X_grid(mask) * (epd / 2); Y_pupil = Y_grid(mask) * (epd / 2);
        N_rays_per_field = length(X_pupil);
        
        P_all = []; V_all = []; Field_ID = []; Pupil_UV = [];
        for fld_idx = 1:N_flds
            fld = fieldAnglesDeg(fld_idx); v_chief_2D = [sind(fld), cosd(fld)];
            y_chief = zStart * tand(fld);
            P_all = [P_all; [X_pupil, y_chief + Y_pupil, repmat(zStart, N_rays_per_field, 1)]];
            V_all = [V_all; repmat([0, v_chief_2D], N_rays_per_field, 1)];
            Field_ID = [Field_ID; repmat(fld_idx, N_rays_per_field, 1)];
            Pupil_UV = [Pupil_UV; [X_grid(mask), Y_grid(mask)]]; 
        end
        
        N_total_rays = size(P_all, 1);
        P = P_all; V = V_all; Traj = NaN(N_total_rays, 3, 6); Traj(:, :, 1) = P;
        valid_mask = true(N_total_rays, 1); OPL = zeros(N_total_rays, 1);
        
        for k = 1:4
            R_eff = r(k); if k == 2 || k == 4, R_eff = -r(k); end
            Nz = N_2D(k, 2); Ny = N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz]; 
            P_loc = (P - O_3D(k, :)) * M_g2l'; V_loc = V * M_g2l';
            c = 1 / R_eff; K = K_conic(k);
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
            OPL(valid_mask) = OPL(valid_mask) + t(valid_mask);
            P_hit_loc = P_loc + t .* V_loc;
            N_loc = [c * P_hit_loc(:,1), c * P_hit_loc(:,2), c * (1+K) * P_hit_loc(:,3) - 1];
            N_loc = N_loc ./ sqrt(sum(N_loc.^2, 2));
            flip = sum(V_loc .* N_loc, 2) > 0; N_loc(flip, :) = -N_loc(flip, :);
            V_out_loc = V_loc - 2 .* sum(V_loc .* N_loc, 2) .* N_loc;
            P_hit_glob = P_hit_loc * M_g2l + O_3D(k, :); V = V_out_loc * M_g2l; Traj(valid_mask, :, k+1) = P_hit_glob(valid_mask, :); P = P_hit_glob;
            hits_loc_valid = P_hit_loc(valid_mask, :);
            if ~isempty(hits_loc_valid)
                global_footprint(k) = max(global_footprint(k), max(sqrt(hits_loc_valid(:,1).^2 + hits_loc_valid(:,2).^2)));
            end
        end
        N_im = [0, dir_out_global]; t_im = sum((Oim_3D - P) .* N_im, 2) ./ sum(V .* N_im, 2);
        OPL(valid_mask) = OPL(valid_mask) + t_im(valid_mask); 
        P_im = P + t_im .* V; Traj(valid_mask, :, 6) = P_im(valid_mask, :);
        
        sim_data(conf_idx).O_3D = O_3D; sim_data(conf_idx).Traj = Traj; sim_data(conf_idx).valid_mask = valid_mask;
        sim_data(conf_idx).P_im = P_im; sim_data(conf_idx).V_im = V; sim_data(conf_idx).OPL = OPL;
        sim_data(conf_idx).Field_ID = Field_ID; sim_data(conf_idx).Pupil_UV = Pupil_UV; 
        sim_data(conf_idx).Oim_3D = Oim_3D; sim_data(conf_idx).P_XP_global = P_XP_global; sim_data(conf_idx).EXPD = EXPD_global;
        sim_data(conf_idx).N_2D = N_2D;
    end
    mech_apertures = max(global_footprint, 1e-3); 
    
    % =========================================================================
    % [Phase 2: Rendering Output]
    % =========================================================================
    for conf_idx = 1:length(configs)
        cfg = configs(conf_idx); data = sim_data(conf_idx); N_flds = length(cfg.fieldAnglesDeg);
        figure('Name', ['Optical System - ', cfg.name], 'Color', 'w', 'Position', [50, 50, 1600, max(500, N_flds*260)]); 
        
        idx_3d = []; for r = 1:N_flds, idx_3d = [idx_3d, 4*r-3, 4*r-2]; end
        subplot(N_flds, 4, idx_3d); hold on; grid on; 
        
        % 仅仅设置基础标题 (不包含体积和EXPD)
        title(sprintf('%s\n3D Layout', cfg.name), 'Interpreter', 'none', 'FontSize', 12);
        xlabel('Optical Z (mm)'); ylabel('Optical X (Depth)'); zlabel('Optical Y (mm)');
        
        all_sys_pts = []; 
        
        % 1. 绘制光阑 (Stop) 并并入包络
        theta_s = linspace(0, 2*pi, 40)';
        x_stop = (cfg.epd/2) * cos(theta_s); y_stop = (cfg.epd/2) * sin(theta_s);
        pts_stop = [x_stop, y_stop, zeros(length(theta_s), 1)]; 
        plot3(pts_stop(:,3), pts_stop(:,1), pts_stop(:,2), 'c-', 'LineWidth', 2); 
        all_sys_pts = [all_sys_pts; pts_stop]; 

        % 2. 画光线
        for fld_idx = 1:N_flds
            fld_mask = data.valid_mask & (data.Field_ID == fld_idx);
            valid_idx = find(fld_mask); if isempty(valid_idx), continue; end
            plot_idx = valid_idx(1:ceil(length(valid_idx)/80):end); 
            X_lines = squeeze(data.Traj(plot_idx, 1, :))'; Y_lines = squeeze(data.Traj(plot_idx, 2, :))'; Z_lines = squeeze(data.Traj(plot_idx, 3, :))'; 
            X_lines(end+1, :) = NaN; Y_lines(end+1, :) = NaN; Z_lines(end+1, :) = NaN;
            plot3(Z_lines(:), X_lines(:), Y_lines(:), '-', 'Color', [field_colors(fld_idx,:), 0.3]);
        end
        
        % 3. 画 3D 实体镜片 (彻底修复侧边镂空)
        for k = 1:4
            c = 1 / (cfg.r(k) * (1 - 2*(k==2 || k==4))); K = cfg.K_conic(k); 
            Nz = data.N_2D(k, 2); Ny = data.N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz];
            [RHO, THETA] = meshgrid(linspace(0, mech_apertures(k), 20), linspace(0, 2*pi, 40)); 
            Xl = RHO .* cos(THETA); Yl = RHO .* sin(THETA);
            v_s = 1 - (1+K)*c^2*(Xl.^2 + Yl.^2) >= 0; Zl_f = NaN(size(Xl));
            Zl_f(v_s) = (c * (Xl(v_s).^2 + Yl(v_s).^2)) ./ (1 + sqrt(1 - (1+K)*c^2.*(Xl(v_s).^2 + Yl(v_s).^2)));
            Zl_b = Zl_f + mirror_thickness;
            
            % 前表面
            p_f = [Xl(:), Yl(:), Zl_f(:)] * M_g2l + data.O_3D(k, :);
            surf(reshape(p_f(:,3), size(Zl_f)), reshape(p_f(:,1), size(Xl)), reshape(p_f(:,2), size(Yl)), ...
                 'FaceColor', [0.95 0.95 0.95], 'EdgeColor', 'none', 'FaceAlpha', mirror_alpha);
            % 后表面
            p_b = [Xl(:), Yl(:), Zl_b(:)] * M_g2l + data.O_3D(k, :);
            surf(reshape(p_b(:,3), size(Zl_b)), reshape(p_b(:,1), size(Xl)), reshape(p_b(:,2), size(Yl)), ...
                 'FaceColor', [0.8 0.8 0.8], 'EdgeColor', 'none', 'FaceAlpha', mirror_alpha);
            
            % ★ 强制封闭的侧边圆柱 (无 NaN 镂空) ★
            theta_edge = linspace(0, 2*pi, 60)';
            r_edge = mech_apertures(k);
            X_edge_c = r_edge * cos(theta_edge);
            Y_edge_c = r_edge * sin(theta_edge);
            Z_edge_c_f = (c * r_edge^2) ./ (1 + sqrt(1 - (1+K)*c^2*r_edge^2));
            if ~isreal(Z_edge_c_f) || isnan(Z_edge_c_f), Z_edge_c_f = 0; end % 防崩回退
            Z_edge_c_b = Z_edge_c_f + mirror_thickness;
            
            pts_edge_f = [X_edge_c, Y_edge_c, repmat(Z_edge_c_f, length(theta_edge), 1)] * M_g2l + data.O_3D(k, :);
            pts_edge_b = [X_edge_c, Y_edge_c, repmat(Z_edge_c_b, length(theta_edge), 1)] * M_g2l + data.O_3D(k, :);
            
            Z_cyl = [pts_edge_f(:,3), pts_edge_b(:,3)];
            X_cyl = [pts_edge_f(:,1), pts_edge_b(:,1)];
            Y_cyl = [pts_edge_f(:,2), pts_edge_b(:,2)];
            surf(Z_cyl, X_cyl, Y_cyl, 'FaceColor', [0.85 0.85 0.85], 'EdgeColor', 'none', 'FaceAlpha', mirror_alpha);
            
            % 收集镜面系统边界点
            all_sys_pts = [all_sys_pts; p_f(~isnan(p_f(:,3)),:); p_b(~isnan(p_b(:,3)),:)];
        end
        
        % ★ 收集像面 (全局光束真实落点边界) ★
        % 此前仅采集中心原点，现在采集在像面实际落下的全量光线坐标点
        if any(data.valid_mask)
            all_sys_pts = [all_sys_pts; data.P_im(data.valid_mask, :)];
        end
        
        % ★★★ 核心渲染：绘制全包裹 Convex Hull 并输出文本框 ★★★
        if size(all_sys_pts, 1) > 4
            [K_hull, hull_vol] = convhull(all_sys_pts);
            trisurf(K_hull, all_sys_pts(:, 3), all_sys_pts(:, 1), all_sys_pts(:, 2), ...
                    'FaceColor', [0.6 0.9 1.0], 'EdgeColor', [0.1 0.1 0.1], ...
                    'FaceAlpha', box_face_alpha, 'EdgeAlpha', box_edge_alpha, 'LineWidth', 1.0);
            
            % ★ 图表内文字浮窗 (带 LaTeX 上标解析) ★
            txt_str = sprintf('EXPD: %.2f mm\nEnv Vol: %.1f mm^{3}', data.EXPD, hull_vol);
            text(0.02, 0.98, txt_str, 'Units', 'normalized', 'Interpreter', 'tex', ...
                 'FontSize', 11, 'FontWeight', 'bold', 'VerticalAlignment', 'top', ...
                 'BackgroundColor', [1 1 1 0.85], 'EdgeColor', 'k', 'Margin', 5);
        end
        
        scatter3(data.O_3D(:,3), data.O_3D(:,1), data.O_3D(:,2), 30, 'k', 'filled');
        axis equal tight; view(0, 0); camlight; lighting gouraud; 

        % --- 右侧数据图 ---
        for fld_idx = 1:N_flds
            fld_mask = data.valid_mask & (data.Field_ID == fld_idx);
            if ~any(fld_mask), continue; end
            
            % 1. Spot Diagram
            subplot(N_flds, 4, 4*fld_idx - 1); hold on; grid on;
            Pf = data.P_im(fld_mask, :); theta_out = 2 * sum(cfg.alpha); 
            Sx = Pf(:, 1); Sy = (Pf(:, 2) - data.Oim_3D(2)) * cosd(theta_out) - (Pf(:, 3) - data.Oim_3D(3)) * sind(theta_out);
            Sx = Sx * 1000; Sy = Sy * 1000; cx = mean(Sx); cy = mean(Sy); dx = Sx - cx; dy = Sy - cy;
            rms_dia = sqrt(mean(dx.^2 + dy.^2)) * 2;
            try K_s = convhull(Sx, Sy); hX = Sx(K_s); hY = Sy(K_s); max_d = 0;
                for hi = 1:length(hX), max_d = max(max_d, max(sqrt((hX-hX(hi)).^2 + (hY-hY(hi)).^2))); end
                geo_100 = max_d;
            catch, geo_100 = max(sqrt(dx.^2 + dy.^2)) * 2; end
            scatter(Sx, Sy, 8, field_colors(fld_idx,:), 'filled', 'MarkerFaceAlpha', 0.6);
            plot(cx, cy, 'k+', 'MarkerSize', 10, 'LineWidth', 1.5); 
            title(sprintf('Spot | RMS Dia: %.2f \\mu m | 100%% Size: %.2f \\mu m', rms_dia, geo_100)); 
            xlabel('Image X (\mum)'); ylabel('Image Y (\mum)'); axis equal;
            
            % 2. Wavefront Map
            subplot(N_flds, 4, 4*fld_idx); hold on; grid on;
            UV = data.Pupil_UV(fld_mask, :); C3D = mean(Pf, 1); R_ref = norm(data.P_XP_global - C3D);
            Dlt = Pf - repmat(C3D, size(Pf,1), 1); VdD = sum(data.V_im(fld_mask,:) .* Dlt, 2);
            tr = -VdD - sqrt(max(VdD.^2 - (sum(Dlt.^2, 2) - R_ref^2), 0));
            OPL_r = data.OPL(fld_mask) + tr; [~, c_i] = min(sum(UV.^2, 2));
            OPD = (OPL_r(c_i) - OPL_r) / lambda;
            A_f = [ones(size(UV,1), 1), UV(:,1), UV(:,2)]; cf = A_f \ OPD; 
            OPD_c = OPD - (cf(2)*UV(:,1) + cf(3)*UV(:,2));
            [Uq, Vq] = meshgrid(linspace(-1, 1, 64), linspace(-1, 1, 64));
            W_g = griddata(UV(:,1), UV(:,2), OPD_c, Uq, Vq, 'cubic');
            surf(Uq, Vq, W_g, 'EdgeColor', 'none'); colormap(gca, jet); colorbar;
            title(sprintf('OPD | PV: %.3f \\lambda | RMS: %.3f \\lambda', max(OPD_c)-min(OPD_c), std(OPD_c,1)));
            xlabel('Px'); ylabel('Py'); axis square; view(2);
        end
    end
end

function [R_ref, EXPD, z_EP_from_M4] = get_zemax_paraxial_data(r, d, epd)
    n = [1, -1, 1, -1, 1];
    y_m = epd / 2; u_m = 0; y_m = y_m + d(1) * u_m; 
    y_c = 0; u_c = 0.01; y_c = y_c + d(1) * u_c; 
    for i = 1:4
        phi = (n(i+1) - n(i)) / r(i);
        u_m = (n(i)*u_m - y_m*phi) / n(i+1);
        u_c = (n(i)*u_c - y_c*phi) / n(i+1);
        if i < 4, y_m = y_m + d(i+1) * u_m; y_c = y_c + d(i+1) * u_c; end
    end
    if abs(u_c) < 1e-12, z_EP_from_M4 = 1e9; EXPD = epd;
    else, z_EP_from_M4 = -y_c / u_c; y_ep = y_m + z_EP_from_M4 * u_m; EXPD = 2 * abs(y_ep); end
    R_ref = abs(d(5) - z_EP_from_M4);
end

function y_chief = find_chief_ray(zStart, v_in, R, K_conic, O, N_2D, stopPos, O_stop, NY_stop, target_y)
    y_test = linspace(-200, 200, 41); errs = ones(size(y_test)) * 1e6;
    for ti = 1:length(y_test), errs(ti) = trace_2D_error(y_test(ti), zStart, v_in, R, K_conic, O, N_2D, stopPos, O_stop, NY_stop, target_y); end
    [~, min_i] = min(abs(errs)); y1 = y_test(min_i); err1 = errs(min_i);
    y2 = y1 + 2.0; err2 = trace_2D_error(y2, zStart, v_in, R, K_conic, O, N_2D, stopPos, O_stop, NY_stop, target_y);
    y_chief = y1;
    if abs(err1) > 1e-4
        for iter = 1:20
            if abs(err2) < 1e-4, y_chief = y2; break; end
            slope = (err2 - err1) / (y2 - y1); if abs(slope) < 1e-12, y_chief = y2; break; end
            y_next = y2 - err2 / slope; y1 = y2; err1 = err2; y2 = y_next;
            err2 = trace_2D_error(y2, zStart, v_in, R, K_conic, O, N_2D, stopPos, O_stop, NY_stop, target_y); y_chief = y2;
        end
    end
end

function err = trace_2D_error(y_start, zStart, v, R, K, O, N_2D, stopPos, O_stop, NY_stop, target_y)
    p = [y_start, zStart]; target_k = 4;
    for k = 1:target_k
        R_eff = R(k); if k == 2 || k == 4, R_eff = -R(k); end
        nx = [N_2D(k, 1), N_2D(k, 2)]; ny = [-nx(2), nx(1)]; c = 1 / R_eff;
        dp = p - O(k, :); x0 = dot(dp, nx); y0 = dot(dp, ny); vx = dot(v, nx); vy = dot(v, ny);
        if abs(c) < 1e-12, t = -x0 / vx; x_hit = 0; y_hit = y0 + t * vy;
        else
            m = vy / vx; n_val = y0 - m * x0; A = c * (1 + K(k) + m^2); B_half = c * m * n_val - 1; C = c * n_val^2; 
            delta = B_half^2 - A * C; if delta < 0, err = 1e6; return; end
            if B_half > 0, x_hit = C / (-B_half - sqrt(delta)); else, x_hit = C / (-B_half + sqrt(delta)); end
            y_hit = m * x_hit + n_val;
        end
        dx_dy = (c * y_hit) / (1 - c * (1 + K(k)) * x_hit); N_loc = [1, -dx_dy]; N_loc = N_loc / norm(N_loc);
        v_loc = [vx, vy]; if dot(v_loc, N_loc) > 0, N_loc = -N_loc; end
        v_out_loc = v_loc - 2 * dot(v_loc, N_loc) * N_loc; p = O(k, :) + x_hit * nx + y_hit * ny; v = v_out_loc(1) * nx + v_out_loc(2) * ny;
    end
    err = y_start - target_y;
end