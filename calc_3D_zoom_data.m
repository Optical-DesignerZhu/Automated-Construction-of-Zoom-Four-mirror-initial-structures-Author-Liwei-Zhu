function [sim_data, mech_apertures, configs, meridional_apertures, hull_vol] = calc_3D_zoom_data(g_opt_all, sysParam)
% 静默版纯计算模块，无 fprintf 输出，避免刷屏
    if isfield(sysParam, 'stopPosition'), stopPos = sysParam.stopPosition; else, stopPos = 0; end
    N_pos = size(g_opt_all, 1);
    grid_size = 5; 
    mirror_thickness = 3;
    
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
    meridional_footprint = zeros(1, 4); 
    sim_data = struct();            
    
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
        if stopPos == 5
            O_stop_2D = O4 + d(4) * dir_out_global;
            NY_stop = [-dir_out_global(2), dir_out_global(1)];
            O_stop_3D = [0, O_stop_2D];
            if isfield(sysParam, 'stopToImage'), d_stop_img = sysParam.stopToImage; else, d_stop_img = d(5); end
            if isfield(sysParam, 'pos') && numel(sysParam.pos) >= conf_idx && isfield(sysParam.pos(conf_idx), 'f')
                f_curr = abs(sysParam.pos(conf_idx).f);
            else
                f_curr = abs(d_stop_img);
            end
            F_num_ideal = f_curr / max(epd, 1e-9);
            r_stop_design = d_stop_img / (2 * max(F_num_ideal, 1e-9));
        else
            O_stop_2D = [NaN, NaN]; NY_stop = [NaN, NaN]; O_stop_3D = [NaN, NaN, NaN]; r_stop_design = NaN;
        end
        
        N_2D = zeros(4, 2);
        for k = 1:4
            if k == 1, u_in = [0, 1]; else, u_in = (O_2D(k,:) - O_2D(k-1,:)) / norm(O_2D(k,:) - O_2D(k-1,:)); end
            if k == 4, u_out = (Oim - O_2D(4,:)) / norm(Oim - O_2D(4,:)); else, u_out = (O_2D(k+1,:) - O_2D(k,:)) / norm(O_2D(k+1,:) - O_2D(k,:)); end
            N_bisect = u_in - u_out; N_2D(k, :) = N_bisect / norm(N_bisect);
        end
        
        if stopPos == 0
            min_z = min([O_2D(:,2); 0]);
        else
            min_z = min(O_2D(:,2));
        end
        zStart = min_z - 60;
        
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
        P_all = []; V_all = []; Field_ID = []; Pupil_UV = [];
        
        is_merid_global = logical([]);
        
        for fld_idx = 1:N_flds
            fld = fieldAnglesDeg(fld_idx);
            v_chief_2D = [sind(fld), cosd(fld)];
            
            is_merid_fld = abs(X_pupil) < 1e-9;
            is_merid_global = [is_merid_global; is_merid_fld]; 
            
            if stopPos == 0
                y_start = Y_pupil + zStart * tand(fld);
            elseif stopPos >= 1 && stopPos <= 4
                y_chief = solve_to_surface_target_2d(fld, zStart, r, K_conic, O_2D, N_2D, stopPos, 0, zStart * tand(fld));
                cos_fld = cosd(fld);
                if abs(cos_fld) < 1e-9, cos_fld = sign(cos_fld + (cos_fld == 0)) * 1e-9; end
                y_start = y_chief + Y_pupil / cos_fld;
            elseif stopPos == 5
                y_chief = solve_to_stop_target_2d(fld, zStart, r, K_conic, O_2D, N_2D, O_stop_2D, NY_stop, 0, zStart * tand(fld));
                target_stop_y = (Y_pupil / max(epd / 2, 1e-9)) * r_stop_design;
                y_start = NaN(size(Y_pupil));
                cos_fld = cosd(fld);
                if abs(cos_fld) < 1e-9, cos_fld = sign(cos_fld + (cos_fld == 0)) * 1e-9; end
                for rp = 1:N_rays_per_field
                    if abs(target_stop_y(rp)) < 1e-12
                        y_start(rp) = y_chief;
                    else
                        y_seed = y_chief + target_stop_y(rp) / cos_fld;
                        y_start(rp) = solve_to_stop_target_2d(fld, zStart, r, K_conic, O_2D, N_2D, O_stop_2D, NY_stop, target_stop_y(rp), y_seed);
                    end
                end
            else
                y_chief = zStart * tand(fld);
                y_start = y_chief + Y_pupil;
            end
            P_all = [P_all; [X_pupil, y_start, repmat(zStart, N_rays_per_field, 1)]];
            V_all = [V_all; repmat([0, v_chief_2D], N_rays_per_field, 1)];
            Field_ID = [Field_ID; repmat(fld_idx, N_rays_per_field, 1)];
            Pupil_UV = [Pupil_UV; UV];
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
            merid_mask_valid = logical(is_merid_global(valid_mask)); 
            
            if ~isempty(hits_loc_valid)
                global_footprint(k) = max(global_footprint(k), max(sqrt(hits_loc_valid(:,1).^2 + hits_loc_valid(:,2).^2)));
                merid_hits = hits_loc_valid(merid_mask_valid, :);
                if ~isempty(merid_hits)
                    meridional_footprint(k) = max(meridional_footprint(k), max(abs(merid_hits(:,2))));
                end
            end
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
        sim_data(conf_idx).r_stop = r_stop_design; sim_data(conf_idx).O_stop_3D = O_stop_3D;
    end
    mech_apertures = max(global_footprint, 1e-3); 
    meridional_apertures = max(meridional_footprint, 1e-3);
    
    % 提取点云并计算 3D Sweep Volume
    all_global_pts = [];
    
    for conf_idx = 1:N_pos
        cfg = configs(conf_idx); data = sim_data(conf_idx);
        theta_s = linspace(0, 2*pi, 40)'; 
        
        if stopPos == 5
            r_stop = data.r_stop;
            v_y = data.dir_out_global(1); v_z = data.dir_out_global(2);
            M_rot_stop = [1, 0, 0; 0, v_z, -v_y; 0, v_y, v_z];
            pts_stop = [r_stop*cos(theta_s), r_stop*sin(theta_s), zeros(40,1)] * M_rot_stop + repmat(data.O_stop_3D, 40, 1);
        elseif stopPos >= 1 && stopPos <= 4
            r_stop = mech_apertures(stopPos) * 0.95;
            Nz_s = data.N_2D(stopPos, 2); Ny_s = data.N_2D(stopPos, 1);
            M_rot_stop = [1, 0, 0; 0, Nz_s, -Ny_s; 0, Ny_s, Nz_s];
            pts_stop = [r_stop*cos(theta_s), r_stop*sin(theta_s), zeros(40,1)] * M_rot_stop + repmat(data.O_3D(stopPos, :), 40, 1);
        else
            r_stop = cfg.epd / 2;
            pts_stop = [r_stop*cos(theta_s), r_stop*sin(theta_s), zeros(40,1)];
        end
        all_global_pts = [all_global_pts; pts_stop]; 
        
        r_im = data.r_im;
        v_y = data.dir_out_global(1); v_z = data.dir_out_global(2);
        M_rot_im = [1, 0, 0; 0, v_z, -v_y; 0, v_y, v_z];
        pts_im = [r_im*cos(theta_s), r_im*sin(theta_s), zeros(40,1)] * M_rot_im + repmat(data.Oim_3D, 40, 1);
        all_global_pts = [all_global_pts; pts_im];
        
        for k = 1:4
            c = 1 / (cfg.r(k) * (1 - 2*(k==2 || k==4))); K = cfg.K_conic(k); 
            Nz = data.N_2D(k, 2); Ny = data.N_2D(k, 1); M_g2l = [1, 0, 0; 0, Nz, -Ny; 0, Ny, Nz];
            [RHO, THETA] = meshgrid(linspace(0, mech_apertures(k), 20), linspace(0, 2*pi, 40)); 
            Xl = RHO .* cos(THETA); Yl = RHO .* sin(THETA);
            v_s = 1 - (1+K)*c^2*(Xl.^2 + Yl.^2) >= 0; Zl_f = NaN(size(Xl));
            Zl_f(v_s) = (c * (Xl(v_s).^2 + Yl(v_s).^2)) ./ (1 + sqrt(1 - (1+K)*c^2.*(Xl(v_s).^2 + Yl(v_s).^2)));
            Zl_b = Zl_f + mirror_thickness;
            p_f = [Xl(:), Yl(:), Zl_f(:)] * M_g2l + data.O_3D(k, :);
            p_b = [Xl(:), Yl(:), Zl_b(:)] * M_g2l + data.O_3D(k, :);
            all_global_pts = [all_global_pts; p_f(~isnan(p_f(:,3)),:); p_b(~isnan(p_b(:,3)),:)];
        end
        
        if any(data.valid_mask), all_global_pts = [all_global_pts; data.P_im(data.valid_mask, :)]; end
    end
    
    if size(all_global_pts, 1) > 4
        [~, hull_vol] = convhull(all_global_pts(:,3), all_global_pts(:,1), all_global_pts(:,2));
    else
        hull_vol = 1e8;
    end
end

% ---------------------- 支撑函数保留 ----------------------
function [R_ref, EXPD, z_EP_from_M4] = get_zemax_paraxial_data(r, d, epd)
    n = [1, -1, 1, -1, 1]; y_m = epd / 2; u_m = 0; y_m = y_m + d(1) * u_m; y_c = 0; u_c = 0.01; y_c = y_c + d(1) * u_c; 
    for i = 1:4
        phi = (n(i+1) - n(i)) / r(i); u_m = (n(i)*u_m - y_m*phi) / n(i+1); u_c = (n(i)*u_c - y_c*phi) / n(i+1);
        if i < 4, y_m = y_m + d(i+1) * u_m; y_c = y_c + d(i+1) * u_c; end
    end
    if abs(u_c) < 1e-12, z_EP_from_M4 = 1e9; EXPD = epd;
    else, z_EP_from_M4 = -y_c / u_c; y_ep = y_m + z_EP_from_M4 * u_m; EXPD = 2 * abs(y_ep); end
    R_ref = abs(d(5) - z_EP_from_M4);
end
function y_sol = solve_to_surface_target_2d(fld, zStart, r, K_conic, O_2D, N_2D, target_k, target_y, y_init)
    v_in = [sind(fld), cosd(fld)]; v_in = v_in / norm(v_in);
    y_test = linspace(-200, 200, 41); errs = ones(size(y_test)) * 1e6;
    if nargin < 9, y_init = zStart * tand(fld); end
    for ti = 1:numel(y_test)
        errs(ti) = trace_to_surface_error_2d(y_test(ti), zStart, v_in, r, K_conic, O_2D, N_2D, target_k, target_y);
    end
    valid_idx = find(abs(errs) < 1e5);
    if isempty(valid_idx), y_sol = y_init; return; end
    [~, min_i] = min(abs(errs(valid_idx)));
    y1 = y_test(valid_idx(min_i)); e1 = errs(valid_idx(min_i));
    y2 = y1 + 2.0;
    e2 = trace_to_surface_error_2d(y2, zStart, v_in, r, K_conic, O_2D, N_2D, target_k, target_y);
    y_sol = y1;
    if abs(e1) <= 1e-4, return; end
    for iter = 1:20
        if abs(e2) < 1e-4, y_sol = y2; return; end
        slope = (e2 - e1) / (y2 - y1);
        if abs(slope) < 1e-12, y_sol = y2; return; end
        y_next = y2 - e2 / slope; y1 = y2; e1 = e2; y2 = y_next;
        e2 = trace_to_surface_error_2d(y2, zStart, v_in, r, K_conic, O_2D, N_2D, target_k, target_y);
        y_sol = y2;
    end
end
function err = trace_to_surface_error_2d(y_start, zStart, v_in, r, K_conic, O_2D, N_2D, target_k, target_y)
    p = [y_start, zStart]; v = v_in;
    for k = 1:target_k
        R_eff = r(k); if k == 2 || k == 4, R_eff = -r(k); end
        [hit, v_out, ok] = ray_conic_hit_and_reflect_2d(p, v, O_2D(k, :), R_eff, K_conic(k), N_2D(k, :));
        if ~ok, err = 1e6; return; end
        if k == target_k
            ny_k = [-N_2D(k, 2), N_2D(k, 1)]; err = dot(hit - O_2D(k, :), ny_k) - target_y; return;
        end
        p = hit; v = v_out;
    end
    err = 1e6;
end
function y_sol = solve_to_stop_target_2d(fld, zStart, r, K_conic, O_2D, N_2D, O_stop, NY_stop, target_y, y_init)
    v_in = [sind(fld), cosd(fld)]; v_in = v_in / norm(v_in);
    y_test = linspace(-200, 200, 41); errs = ones(size(y_test)) * 1e6;
    if nargin < 10, y_init = zStart * tand(fld); end
    for ti = 1:numel(y_test)
        errs(ti) = trace_to_stop_error_2d(y_test(ti), zStart, v_in, r, K_conic, O_2D, N_2D, O_stop, NY_stop, target_y);
    end
    valid_idx = find(abs(errs) < 1e5);
    if isempty(valid_idx), y_sol = y_init; return; end
    [~, min_i] = min(abs(errs(valid_idx)));
    y1 = y_test(valid_idx(min_i)); e1 = errs(valid_idx(min_i));
    y2 = y1 + 2.0;
    e2 = trace_to_stop_error_2d(y2, zStart, v_in, r, K_conic, O_2D, N_2D, O_stop, NY_stop, target_y);
    y_sol = y1;
    if abs(e1) <= 1e-4, return; end
    for iter = 1:20
        if abs(e2) < 1e-4, y_sol = y2; return; end
        slope = (e2 - e1) / (y2 - y1);
        if abs(slope) < 1e-12, y_sol = y2; return; end
        y_next = y2 - e2 / slope; y1 = y2; e1 = e2; y2 = y_next;
        e2 = trace_to_stop_error_2d(y2, zStart, v_in, r, K_conic, O_2D, N_2D, O_stop, NY_stop, target_y);
        y_sol = y2;
    end
end
function err = trace_to_stop_error_2d(y_start, zStart, v_in, r, K_conic, O_2D, N_2D, O_stop, NY_stop, target_y)
    p = [y_start, zStart]; v = v_in; ok_all = true;
    for k = 1:4
        R_eff = r(k); if k == 2 || k == 4, R_eff = -r(k); end
        [hit, v_out, ok] = ray_conic_hit_and_reflect_2d(p, v, O_2D(k, :), R_eff, K_conic(k), N_2D(k, :));
        if ~ok, ok_all = false; break; end
        p = hit; v = v_out;
    end
    if ~ok_all, err = 1e6; return; end
    dir_stop = [NY_stop(2), -NY_stop(1)];
    den = dot(v, dir_stop);
    if abs(den) < 1e-12, err = 1e6; return; end
    t = dot(O_stop - p, dir_stop) / den;
    hit_stop = p + t * v;
    err = dot(hit_stop - O_stop, NY_stop) - target_y;
end
function [hit_glob, v_out_glob, ok] = ray_conic_hit_and_reflect_2d(p0_glob, v_in_glob, O_k, R_k, K_k, nx)
    ny = [-nx(2), nx(1)]; dp = p0_glob - O_k;
    x0 = dp * nx'; y0 = dp * ny'; vx = v_in_glob * nx'; vy = v_in_glob * ny';
    c = 1 / R_k; ok = true;
    if abs(c) < 1e-12
        if abs(vx) < 1e-12, ok = false; hit_glob = [NaN, NaN]; v_out_glob = [NaN, NaN]; return; end
        t = -x0 / vx; x_hit = 0; y_hit = y0 + t * vy;
    else
        if abs(vx) < 1e-12
            x_hit = x0; y2 = (2*x_hit - c*(1+K_k)*x_hit^2) / c;
            if y2 < 0, ok = false; hit_glob = [NaN, NaN]; v_out_glob = [NaN, NaN]; return; end
            y_hit1 = sqrt(y2); y_hit2 = -sqrt(y2);
            if abs(y_hit1 - y0) < abs(y_hit2 - y0), y_hit = y_hit1; else, y_hit = y_hit2; end
        else
            m = vy / vx; n_val = y0 - m * x0;
            A = c * (1 + K_k + m^2); B_half = c * m * n_val - 1; C = c * n_val^2;
            delta = B_half^2 - A * C;
            if delta < 0, ok = false; hit_glob = [NaN, NaN]; v_out_glob = [NaN, NaN]; return; end
            if B_half > 0, x_hit = C / (-B_half - sqrt(delta)); else, x_hit = C / (-B_half + sqrt(delta)); end
            y_hit = m * x_hit + n_val;
        end
    end
    if ~isfinite(x_hit) || ~isfinite(y_hit), ok = false; hit_glob = [NaN, NaN]; v_out_glob = [NaN, NaN]; return; end
    den_grad = 1 - c * (1 + K_k) * x_hit;
    if abs(den_grad) < 1e-12, ok = false; hit_glob = [NaN, NaN]; v_out_glob = [NaN, NaN]; return; end
    dx_dy = (c * y_hit) / den_grad; N_loc = [1, -dx_dy]; n_norm = norm(N_loc);
    if n_norm < 1e-12, ok = false; hit_glob = [NaN, NaN]; v_out_glob = [NaN, NaN]; return; end
    N_loc = N_loc / n_norm; v_loc = [vx, vy];
    if dot(v_loc, N_loc) > 0, N_loc = -N_loc; end
    v_out_loc = v_loc - 2 * dot(v_loc, N_loc) * N_loc;
    hit_glob = O_k + x_hit * nx + y_hit * ny; v_out_glob = v_out_loc(1) * nx + v_out_loc(2) * ny;
    if norm(v_out_glob) < 1e-12, ok = false; return; end
    v_out_glob = v_out_glob / norm(v_out_glob);
end