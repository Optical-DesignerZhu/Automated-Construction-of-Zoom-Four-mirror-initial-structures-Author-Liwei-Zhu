function f = funLine(tr, epd, stopPos, D_mech) 
    % 直接使用已经追迹好的 tr.P_S，不需要重新追迹
    P_S = tr.P_S(:);
    
    N_planes = numel(P_S) / 8;
    N_beams = N_planes - 1;
    
    BeamTop = zeros(N_planes, 2); BeamBot = zeros(N_planes, 2);
    ObsTop  = NaN(N_planes, 2);   ObsBot  = NaN(N_planes, 2); 
    
    for s = 1:N_planes
        base = (s - 1) * 8;
        pts_now = [P_S(base + (1:4)), P_S(base + (5:8))];
        [TestA_s, TestB_s] = farthest_pair_four_points(pts_now);
        
        BeamTop(s, :) = TestA_s; BeamBot(s, :) = TestB_s;
        
        % 动态匹配光阑产生的偏移，寻找正确的物理镜面索引 k
        is_mirror = false; k = 0;
        if stopPos == 0 && (s >= 3 && s <= 6)
            is_mirror = true; k = s - 2;
        elseif stopPos == 5 && (s >= 2 && s <= 5)
            is_mirror = true; k = s - 1;
        elseif stopPos >= 1 && stopPos <= 4 && (s >= 2 && s <= 5)
            is_mirror = true; k = s - 1;
        end
        
        if is_mirror && ~isempty(D_mech)
            y_edge = D_mech(k) + 2.0; % 附加2mm安全边界
            R_eff = tr.R(k); if k == 2 || k == 4, R_eff = -R_eff; end
            c = 1 / R_eff; K = tr.K_conic(k);
            if abs(c) < 1e-12, x_edge = 0;
            else
                radicand = 1 - (1+K)*(c*y_edge)^2;
                if radicand < 0, radicand = 0; end
                x_edge = (c * y_edge^2) / (1 + sqrt(radicand));
            end
            ObsTop(s, :) = tr.O(k, :) + x_edge * tr.NX(k, :) + y_edge * tr.NY(k, :);
            ObsBot(s, :) = tr.O(k, :) + x_edge * tr.NX(k, :) - y_edge * tr.NY(k, :);
            
        elseif s == N_planes && isfield(tr, 'imagePlaneRef') && ~isempty(tr.imagePlaneRef)
            O_im = tr.imagePlaneRef(1, :);
            NY_im_vec = tr.imagePlaneRef(2, :) - O_im;
            NY_im = NY_im_vec / norm(NY_im_vec);
            det_half = max(15.0, norm(TestA_s - TestB_s) / 2 + 5.0);
            ObsTop(s, :) = O_im + det_half * NY_im;
            ObsBot(s, :) = O_im - det_half * NY_im;
        end
    end
    
    has_standalone_stop = false;
    if stopPos == 0
        O_stop = [0, 0]; NY_stop = [1, 0]; 
        R_stop_up = epd / 2; R_stop_dn = epd / 2;
        has_standalone_stop = true;
    elseif stopPos == 5
        if isfield(tr, 'stopPlaneRef') && isfield(tr, 'R_stop')
            O_stop = tr.stopPlaneRef(1, :);
            NY_stop_vec = tr.stopPlaneRef(2, :) - O_stop;
            NY_stop = NY_stop_vec / norm(NY_stop_vec);
            R_stop_up = tr.R_stop; R_stop_dn = tr.R_stop;
            has_standalone_stop = true;
        end
    end
    
    if has_standalone_stop
        margin = 0.05; L_ext = 150;   
        StopTop_P1 = O_stop + (R_stop_up + margin) * NY_stop;
        StopTop_P2 = O_stop + (R_stop_up + L_ext) * NY_stop;
        StopBot_P1 = O_stop - (R_stop_dn + margin) * NY_stop;
        StopBot_P2 = O_stop - (R_stop_dn + L_ext) * NY_stop;
        STP1_zy = [StopTop_P1(2), StopTop_P1(1)]; STP2_zy = [StopTop_P2(2), StopTop_P2(1)];
        SBP1_zy = [StopBot_P1(2), StopBot_P1(1)]; SBP2_zy = [StopBot_P2(2), StopBot_P2(1)];
    end

    D1_penalty = 0; Erf2 = 0;
    
    for i = 1:N_beams
        Z_quad = [BeamTop(i,2), BeamBot(i,2), BeamTop(i+1,2), BeamBot(i+1,2)];
        Y_quad = [BeamTop(i,1), BeamBot(i,1), BeamTop(i+1,1), BeamBot(i+1,1)];
        [SortZ, SortY] = SortAndExpandVertices(Z_quad, Y_quad, 40); 
        quad = [SortZ', SortY'];
        
        ray_i_top_start = [BeamTop(i,2), BeamTop(i,1)]; ray_i_top_end = [BeamTop(i+1,2), BeamTop(i+1,1)];
        ray_i_bot_start = [BeamBot(i,2), BeamBot(i,1)]; ray_i_bot_end = [BeamBot(i+1,2), BeamBot(i+1,1)];
        
        for k = 1:N_planes
            if k == i || k == i + 1, continue; end
            if isnan(ObsTop(k, 1)), continue; end 
            
            mirror_P1 = [ObsTop(k, 2), ObsTop(k, 1)];
            mirror_P2 = [ObsBot(k, 2), ObsBot(k, 1)];
            
            if check_segment_intersect(mirror_P1, mirror_P2, ray_i_top_start, ray_i_top_end) || ...
               check_segment_intersect(mirror_P1, mirror_P2, ray_i_bot_start, ray_i_bot_end)
                D1_penalty = D1_penalty + 5000;
            end
            
            if pointInConvexQuadrilateral(ObsTop(k,2), ObsTop(k,1), quad)
                depth = pointToConvexQuadrilateral(ObsTop(k,2), ObsTop(k,1), quad);
                D1_penalty = D1_penalty + depth^2 + 2000;
            end
            if pointInConvexQuadrilateral(ObsBot(k,2), ObsBot(k,1), quad)
                depth = pointToConvexQuadrilateral(ObsBot(k,2), ObsBot(k,1), quad);
                D1_penalty = D1_penalty + depth^2 + 2000;
            end
        end
        
        for j = i+2 : N_beams 
            ray_j_top_start = [BeamTop(j,2), BeamTop(j,1)]; ray_j_top_end = [BeamTop(j+1,2), BeamTop(j+1,1)];
            ray_j_bot_start = [BeamBot(j,2), BeamBot(j,1)]; ray_j_bot_end = [BeamBot(j+1,2), BeamBot(j+1,1)];
            
            Erf2 = Erf2 + segment_cross_penalty(ray_i_top_start, ray_i_top_end, ray_j_top_start, ray_j_top_end);
            Erf2 = Erf2 + segment_cross_penalty(ray_i_top_start, ray_i_top_end, ray_j_bot_start, ray_j_bot_end);
            Erf2 = Erf2 + segment_cross_penalty(ray_i_bot_start, ray_i_bot_end, ray_j_top_start, ray_j_top_end);
            Erf2 = Erf2 + segment_cross_penalty(ray_i_bot_start, ray_i_bot_end, ray_j_bot_start, ray_j_bot_end);
        end
        
        if has_standalone_stop
            is_stop_beam = false;
            if stopPos == 0 && i == 1, is_stop_beam = true;
            elseif stopPos == 5 && (i == 5 || i == 6), is_stop_beam = true; end
            
            if ~is_stop_beam
                if check_segment_intersect(STP1_zy, STP2_zy, ray_i_top_start, ray_i_top_end) || ...
                   check_segment_intersect(STP1_zy, STP2_zy, ray_i_bot_start, ray_i_bot_end) || ...
                   check_segment_intersect(SBP1_zy, SBP2_zy, ray_i_top_start, ray_i_top_end) || ...
                   check_segment_intersect(SBP1_zy, SBP2_zy, ray_i_bot_start, ray_i_bot_end)
                    D1_penalty = D1_penalty + 5000;
                end
            end
        end
    end
    
    f = D1_penalty + Erf2;
end

function tf = check_segment_intersect(p1, p2, p3, p4)
    ccw = @(A, B, C) (C(2)-A(2))*(B(1)-A(1)) - (C(1)-A(1))*(B(2)-A(2));
    tf = (ccw(p1, p3, p4) * ccw(p2, p3, p4) < 0) && ...
         (ccw(p3, p1, p2) * ccw(p4, p1, p2) < 0);
end

function [pointA, pointB] = farthest_pair_four_points(points)
    pairs = [1 2; 1 3; 1 4; 2 3; 2 4; 3 4];
    diffs = points(pairs(:,1), :) - points(pairs(:,2), :);
    dist2 = sum(diffs.^2, 2);
    [~, idx] = max(dist2);
    pointA = points(pairs(idx, 1), :); pointB = points(pairs(idx, 2), :);
end

function penalty = segment_cross_penalty(hardP1, hardP2, softP1, softP2)
    penalty = 0;
    if ~bbox_overlap(hardP1, hardP2, softP1, softP2), return; end
    [xCross, yCross] = polyxpoly([hardP1(1), hardP2(1)], [hardP1(2), hardP2(2)], [softP1(1), softP2(1)], [softP1(2), softP2(2)]);
    if ~isempty(xCross)
        penalty = (shortestdistance(hardP1, hardP2, [xCross, yCross]))^2 + 10; 
    end
end

function tf = bbox_overlap(a1, a2, b1, b2)
    axmin = min(a1(1), a2(1)); axmax = max(a1(1), a2(1));
    aymin = min(a1(2), a2(2)); aymax = max(a1(2), a2(2));
    bxmin = min(b1(1), b2(1)); bxmax = max(b1(1), b2(1));
    bymin = min(b1(2), b2(2)); bymax = max(b1(2), b2(2));
    tf = (axmax >= bxmin) && (bxmax >= axmin) && (aymax >= bymin) && (bymax >= aymin);
end