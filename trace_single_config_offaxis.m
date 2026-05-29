function result = trace_single_config_offaxis(r, epd, fieldAnglesDeg, stopPos)
    %#codegen
    R = r(1:4); d = r(5:9); alpha = r(10:13);
    if numel(r) >= 17, K_conic = r(14:17); else, K_conic = [0, 0, 0, 0]; end
    R = R(:).'; alpha = alpha(:).'; d = d(:).'; fieldAnglesDeg = fieldAnglesDeg(:).';
    absR = abs(R);
    
    % 初始化基础字段
    result = struct(); 
    result.valid = false; 
    result.errorId = ''; 
    result.errorMsg = '';
    result.stopPos = stopPos;
    
    if stopPos == 0, O1_z = d(1); else, O1_z = 400; end
    O1 = [0, O1_z]; 
    
    if stopPos == 5, t_gaps = [d(1), d(2), d(3), d(4)+d(5)];
    else, t_gaps = [d(2), d(3), d(4), d(5)]; end
    
    a12 = alpha(1) + alpha(2); a123 = a12 + alpha(3);
    O2 = O1 + t_gaps(1) * [sind(2 * alpha(1)), cosd(2 * alpha(1))];
    O3 = O2 + t_gaps(2) * [sind(2 * a12), cosd(2 * a12)];
    O4 = O3 + t_gaps(3) * [sind(2 * a123), cosd(2 * a123)];
    
    dImage = t_gaps(4); alphaSum = sum(alpha);
    dir_out_global = [sind(2 * alphaSum), cosd(2 * alphaSum)];
    Oim = O4 + dImage * dir_out_global;
    O = [O1; O2; O3; O4];
    
    if stopPos == 0
        min_z = min([O1(2), O2(2), O3(2), O4(2), 0]); 
    else
        min_z = min([O1(2), O2(2), O3(2), O4(2)]);
    end
    Oref = [0, min_z - 50]; 
    zStart = min_z - 60;    
    
    if stopPos == 5
        O_stop = O4 + d(4) * dir_out_global; 
        NY_stop = [-dir_out_global(2), dir_out_global(1)];
    else
        O_stop = [0, 0]; NY_stop = [1, 0]; 
    end
    
    NX = zeros(4, 2); NY = zeros(4, 2);
    for k = 1:4
        if k == 1
            dv = O(1,:) - Oref; 
            n_dv = sqrt(dv(1)^2 + dv(2)^2);
            u_in = dv / n_dv;
        else
            dv = O(k,:) - O(k-1,:); 
            n_dv = sqrt(dv(1)^2 + dv(2)^2);
            u_in = dv / n_dv; 
        end
        if k == 4
            dv = Oim - O(4,:); 
            n_dv = sqrt(dv(1)^2 + dv(2)^2);
            u_out = dv / n_dv;
        else
            dv = O(k+1,:) - O(k,:); 
            n_dv = sqrt(dv(1)^2 + dv(2)^2);
            u_out = dv / n_dv; 
        end
        N_bisect = u_in - u_out; 
        nx = N_bisect / sqrt(N_bisect(1)^2 + N_bisect(2)^2); 
        ny = [-nx(2), nx(1)];           
        NX(k, :) = nx; NY(k, :) = ny;
    end
    
    if stopPos >= 1 && stopPos <= 4
        O_stop = O(stopPos, :);
        NY_stop = NY(stopPos, :);
    end
    
    stop_target_y_shared = 0;
    if stopPos >= 1 && stopPos <= 5
        d0_ref = normalize_vec([0, 1]);
        y_ref_local = trace_to_stop_error(0, zStart, d0_ref, R, K_conic, O, NX, NY, stopPos, O_stop, NY_stop, 0);
        if isfinite(y_ref_local) && abs(y_ref_local) < 1e5
            stop_target_y_shared = y_ref_local;
        end
    end
    
    if stopPos == 5
        EFL_val = get_EFL(R, d);
        F_num = abs(EFL_val) / epd;
        R_stop_target = d(5) / (2 * F_num); 
    elseif stopPos >= 1 && stopPos <= 4
        err_axial = trace_to_stop_error(epd/2, zStart, [0,1], R, K_conic, O, NX, NY, stopPos, O_stop, NY_stop, stop_target_y_shared);
        R_stop_target = abs(err_axial);
        if R_stop_target > 1e5 || R_stop_target < 1e-3, R_stop_target = epd / 2; end
    else
        R_stop_target = epd / 2; 
    end
    
    pupilY = [-epd / 2, 0, epd / 2];
    rayIdx = 0; totalRays = numel(fieldAnglesDeg) * numel(pupilY);
    base_ray = struct('fieldDeg', 0, 'pupilY', 0, 'points', NaN(6, 2), 'dirs', NaN(4, 2), 'imagePoint', [NaN, NaN], 'refPoint', [NaN, NaN], 'surfacePoints', NaN(7, 2));
    rays = repmat(base_ray, 1, totalRays);
    any_failed = false;
    
    for fi = 1:numel(fieldAnglesDeg)
        fld = fieldAnglesDeg(fi);
        d0 = normalize_vec([sind(fld), cosd(fld)]);
        y_chief = 0; 
        
        if stopPos >= 1 && stopPos <= 5
            y_test = linspace(-200, 200, 41); errs = ones(size(y_test)) * 1e6;
            for ti = 1:length(y_test), errs(ti) = trace_to_stop_error(y_test(ti), zStart, d0, R, K_conic, O, NX, NY, stopPos, O_stop, NY_stop, stop_target_y_shared); end
            valid_idx = find(abs(errs) < 1e5);
            if isempty(valid_idx), any_failed = true; break; end
            
            [~, min_i] = min(abs(errs(valid_idx)));
            y_in1 = y_test(valid_idx(min_i)); err1 = errs(valid_idx(min_i));
            y_in2 = y_in1 + 2.0; err2 = trace_to_stop_error(y_in2, zStart, d0, R, K_conic, O, NX, NY, stopPos, O_stop, NY_stop, stop_target_y_shared);
            
            y_chief = y_in1;
            if abs(err1) > 1e-4
                for iter = 1:20
                    if abs(err2) < 1e-4, y_chief = y_in2; break; end
                    slope = (err2 - err1) / (y_in2 - y_in1);
                    if abs(slope) < 1e-12, y_chief = y_in2; break; end
                    y_in_next = y_in2 - err2 / slope; y_in1 = y_in2; err1 = err2; y_in2 = y_in_next;
                    err2 = trace_to_stop_error(y_in2, zStart, d0, R, K_conic, O, NX, NY, stopPos, O_stop, NY_stop, stop_target_y_shared);
                    y_chief = y_in2;
                end
            end
        end
        
        for pi = 1:numel(pupilY)
            rayIdx = rayIdx + 1;
            
            if stopPos == 0
                y_start_final = pupilY(pi) + zStart * tand(fld); 
            else
                target_y = stop_target_y_shared + (pupilY(pi) / (epd / 2)) * R_stop_target;
                y_guess1 = y_chief + pupilY(pi) / cosd(fld);
                err1 = trace_to_stop_error(y_guess1, zStart, d0, R, K_conic, O, NX, NY, stopPos, O_stop, NY_stop, target_y);
                
                y_guess2 = y_guess1 + 1.0; 
                err2 = trace_to_stop_error(y_guess2, zStart, d0, R, K_conic, O, NX, NY, stopPos, O_stop, NY_stop, target_y);
                
                y_start_final = y_guess1;
                if abs(err1) > 1e-4
                    for iter = 1:30
                        if abs(err2) < 1e-4, y_start_final = y_guess2; break; end
                        slope = (err2 - err1) / (y_guess2 - y_guess1);
                        if abs(slope) < 1e-12, y_start_final = y_guess2; break; end
                        y_next = y_guess2 - err2 / slope;
                        y_guess1 = y_guess2; err1 = err2; y_guess2 = y_next;
                        err2 = trace_to_stop_error(y_guess2, zStart, d0, R, K_conic, O, NX, NY, stopPos, O_stop, NY_stop, target_y);
                        y_start_final = y_guess2;
                    end
                end
            end
            
            p = [y_start_final, zStart]; v = d0;
            
            % 初始化兜底
            stopHit = [NaN, NaN];
            
            refHit = intersect_plane(p, v, Oref, [0, 1]); 
            if stopPos == 0, stopHit = intersect_plane(p, v, [0, 0], [0, 1]); end
            
            pts = NaN(6, 2); dirs = NaN(4, 2); pts(1, :) = p;
            ray_failed = false;
            
            for k = 1:4
                R_eff = R(k); if k == 2 || k == 4, R_eff = -R(k); end
                [hit, v_out, ok] = ray_conic_hit_and_reflect(p, v, O(k, :), R_eff, K_conic(k), NX(k,:), NY(k,:));
                if ~ok
                    pts(k + 1, :) = [NaN, NaN]; dirs(k, :) = [NaN, NaN];
                    ray_failed = true; any_failed = true; break;
                end
                v = v_out; pts(k + 1, :) = hit; dirs(k, :) = v; p = hit;
            end
            
            if ~ray_failed
                imageHit = intersect_plane(p, v, Oim, dir_out_global); 
                pts(6, :) = imageHit;
                if stopPos == 5, stopHit = intersect_plane(p, v, O_stop, dir_out_global); end
            else
                imageHit = [NaN, NaN]; 
            end
            
            if stopPos == 5
                surfacePts = [refHit; pts(2:5, :); stopHit; imageHit];
            elseif stopPos == 0
                surfacePts = [refHit; stopHit; pts(2:6, :)];
            else
                surfacePts = [refHit; pts(2:6, :); NaN, NaN];
            end
            
            rays(rayIdx).fieldDeg = fld; rays(rayIdx).pupilY = pupilY(pi);
            rays(rayIdx).points = pts; rays(rayIdx).dirs = dirs;
            rays(rayIdx).imagePoint = imageHit; rays(rayIdx).refPoint = refHit;
            rays(rayIdx).surfacePoints = surfacePts;
        end
    end
    
    if ~any_failed, result.valid = true; end
    
    % =========================================================================
    % 🌟 终极防线：无论任何情况，严格按照固定的顺序填充所有字段！
    % =========================================================================
    result.O = O; 
    result.R = R; 
    result.K_conic = K_conic; 
    result.NX = NX; 
    result.NY = NY; 
    result.radii = absR;
    result.referencePlaneRef = [Oref; Oref + [1, 0]]; 
    result.imagePlaneRef = [Oim; Oim + [-dir_out_global(2), dir_out_global(1)]]; 
    
    if stopPos >= 1 && stopPos <= 5
        result.stopPlaneRef = [O_stop; O_stop + NY_stop]; 
        result.R_stop = R_stop_target;
    else
        % 🚨 如果进不来 if，强制用 NaN 占位填满，绝不允许字段失踪或乱序！
        result.stopPlaneRef = [NaN, NaN; NaN, NaN]; 
        result.R_stop = NaN;
    end
    
    result.rays = rays;
    result.P_S = build_point_data(rays, fieldAnglesDeg, epd);
end

% =========================================================================
% 🚨 底层辅助函数 (全线标量展开，彻底规避泛型库调度耗时)
% =========================================================================
function hit_plane = intersect_plane(ray_origin, ray_dir, plane_pt, plane_normal)
    den = ray_dir(1)*plane_normal(1) + ray_dir(2)*plane_normal(2);
    if abs(den) < 1e-12, hit_plane = [NaN, NaN]; return; end
    t = ((plane_pt(1) - ray_origin(1))*plane_normal(1) + (plane_pt(2) - ray_origin(2))*plane_normal(2)) / den;
    hit_plane = [ray_origin(1) + t * ray_dir(1), ray_origin(2) + t * ray_dir(2)];
end

function EFL = get_EFL(R, d)
    R1=R(1); R2=R(2); R3=R(3); R4=R(4); d1=d(1); d2=d(2); d3=d(3);
    num = R1*R2*R3*R4;
    den = 4*R2*(d1-d2)*(R4+2*d3) - 2*R2*R3*(R4+2*(d1-d2+d3)) - 4*d1*(2*d2*(R4+2*d3) + R3*(R4-2*d2+2*d3)) + 2*R1*(R2*(R3-R4-2*d3) + 2*d2*(R4+2*d3) + R3*(R4-2*d2+2*d3));
    EFL = num / den;
end

function err = trace_to_stop_error(y_start, zStart, v_in, R, K_conic, O, NX, NY, stopPos, O_stop, NY_stop, target_y)
    err = 1e6; 
    p = [y_start, zStart]; v = v_in; ok_all = true;
    
    if stopPos >= 1 && stopPos <= 4
        for k = 1:stopPos
            R_eff = R(k); if k == 2 || k == 4, R_eff = -R(k); end
            [hit, v_out, ok] = ray_conic_hit_and_reflect(p, v, O(k, :), R_eff, K_conic(k), NX(k,:), NY(k,:));
            if ~ok, ok_all = false; break; end
            if k == stopPos
                err = (hit(1) - O(k, 1))*NY(k, 1) + (hit(2) - O(k, 2))*NY(k, 2) - target_y; return;
            end
            p = hit; v = v_out;
        end
        if ~ok_all, err = 1e6; return; end
    elseif stopPos == 5
        for k = 1:4
            R_eff = R(k); if k == 2 || k == 4, R_eff = -R(k); end
            [hit, v_out, ok] = ray_conic_hit_and_reflect(p, v, O(k, :), R_eff, K_conic(k), NX(k,:), NY(k,:));
            if ~ok, ok_all = false; break; end
            p = hit; v = v_out;
        end
        if ~ok_all, err = 1e6; return; end
        
        dir_out1 = NY_stop(2); dir_out2 = -NY_stop(1);
        den = v(1)*dir_out1 + v(2)*dir_out2;
        if abs(den) < 1e-12, err = 1e6; return; end
        
        t = ((O_stop(1) - p(1))*dir_out1 + (O_stop(2) - p(2))*dir_out2) / den;
        hit_stop1 = p(1) + t * v(1);
        hit_stop2 = p(2) + t * v(2);
        err = (hit_stop1 - O_stop(1))*NY_stop(1) + (hit_stop2 - O_stop(2))*NY_stop(2) - target_y;
    end
end

function [hit_glob, v_out_glob, ok] = ray_conic_hit_and_reflect(p0_glob, v_in_glob, O_k, R_k, K_k, nx, ny)
    dp1 = p0_glob(1) - O_k(1); dp2 = p0_glob(2) - O_k(2);
    x0 = dp1 * nx(1) + dp2 * nx(2);
    y0 = dp1 * ny(1) + dp2 * ny(2);
    vx = v_in_glob(1) * nx(1) + v_in_glob(2) * nx(2);
    vy = v_in_glob(1) * ny(1) + v_in_glob(2) * ny(2);
    
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
            A = c * (1 + K_k + m^2); B_half = c * m * n_val - 1; C = c * n_val^2; delta = B_half^2 - A * C;
            if delta < 0, ok = false; hit_glob = [NaN, NaN]; v_out_glob = [NaN, NaN]; return; end
            if B_half > 0, x_hit = C / (-B_half - sqrt(delta)); else, x_hit = C / (-B_half + sqrt(delta)); end
            y_hit = m * x_hit + n_val;
        end
    end
    if ~isfinite(x_hit) || ~isfinite(y_hit), ok = false; hit_glob = [NaN, NaN]; v_out_glob = [NaN, NaN]; return; end
    
    dx_dy = (c * y_hit) / (1 - c * (1 + K_k) * x_hit); 
    n_norm_sq = 1 + dx_dy^2; 
    if n_norm_sq < 1e-24, ok = false; hit_glob = [NaN, NaN]; v_out_glob = [NaN, NaN]; return; end
    n_norm = sqrt(n_norm_sq);
    
    N_loc1 = 1 / n_norm; N_loc2 = -dx_dy / n_norm;
    dot_val = vx * N_loc1 + vy * N_loc2;
    if dot_val > 0, N_loc1 = -N_loc1; N_loc2 = -N_loc2; dot_val = -dot_val; end
    
    v_out_loc1 = vx - 2 * dot_val * N_loc1;
    v_out_loc2 = vy - 2 * dot_val * N_loc2;
    
    hit_glob = [O_k(1) + x_hit * nx(1) + y_hit * ny(1), O_k(2) + x_hit * nx(2) + y_hit * ny(2)];
    
    v_out_glob1 = v_out_loc1 * nx(1) + v_out_loc2 * ny(1);
    v_out_glob2 = v_out_loc1 * nx(2) + v_out_loc2 * ny(2);
    
    n_out = sqrt(v_out_glob1^2 + v_out_glob2^2);
    if n_out < 1e-12, ok = false; v_out_glob = [NaN, NaN]; return; end
    v_out_glob = [v_out_glob1 / n_out, v_out_glob2 / n_out];
end

function P_S = build_point_data(rays, fieldAnglesDeg, epd)
    if numel(fieldAnglesDeg) < 3, P_S = NaN(0,1); return; end
    f1 = fieldAnglesDeg(1); f3 = fieldAnglesDeg(3); r2 = epd / 2; r3 = -epd / 2; 
    tol = max(1e-9, abs(epd) * 1e-12);
    
    flds = [rays.fieldDeg]; pups = [rays.pupilY];
    
    idx1 = find(abs(flds - f1) <= tol & abs(pups - r2) <= tol, 1);
    idx2 = find(abs(flds - f3) <= tol & abs(pups - r2) <= tol, 1);
    idx3 = find(abs(flds - f1) <= tol & abs(pups - r3) <= tol, 1);
    idx4 = find(abs(flds - f3) <= tol & abs(pups - r3) <= tol, 1);
    
    if isempty(idx1) || isempty(idx2) || isempty(idx3) || isempty(idx4), P_S = NaN(0,1); return; end
    
    sp1 = rays(idx1).surfacePoints; sp2 = rays(idx2).surfacePoints;
    sp3 = rays(idx3).surfacePoints; sp4 = rays(idx4).surfacePoints;
    
    N_planes = size(sp1, 1);
    if N_planes == 0, P_S = NaN(0,1); return; end
    
    P_S = NaN(N_planes * 8, 1);
    Y_mat = [sp1(:,1), sp2(:,1), sp3(:,1), sp4(:,1)];
    Z_mat = [sp1(:,2), sp2(:,2), sp3(:,2), sp4(:,2)];
    
    for s = 1:N_planes
        offset = (s-1)*8;
        P_S(offset+1 : offset+4) = Y_mat(s, :);
        P_S(offset+5 : offset+8) = Z_mat(s, :);
    end
end

function u = normalize_vec(v)
    n = sqrt(v(1)^2 + v(2)^2); 
    if ~isfinite(n) || n < 1e-15, u = [NaN, NaN]; else, u = v / n; end
    if(u(2)<0), u=-u; end
end