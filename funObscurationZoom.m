function [f_total, L, W, all_valid, traces, D_max, t_trace, t_obs] = funObscurationZoom(r_configs_cell, epd_array, fa_cell, stopPos)
    numConfigs = length(r_configs_cell);
    traces = cell(1, numConfigs); 
    all_valid = true;
    
    % --- 1. 光线追迹计时 ---
    t_tr_start = tic;
    for c = 1:numConfigs
        r_c = r_configs_cell{c};
        epd_c = epd_array(c);
        fa_c = fa_cell{c};
        
        tr = trace_single_config_offaxis_mex(r_c, epd_c, fa_c, stopPos);
        traces{c} = tr; 
        
        if ~(isfield(tr, 'valid') && tr.valid)
            all_valid = false;
        end
    end
    t_trace = toc(t_tr_start);
    
    % 如果有配置失效，兜底返回
    if ~all_valid
        f_total = 1000; L = 1000; W = 1000; 
        D_max = zeros(1, 4); 
        t_obs = 0; % 兜底时间
        return;
    end
    
    % --- 2. 遮拦与干涉评估计时 ---
    t_ob_start = tic;
    D_max = zeros(1, 4); 
    for k = 1:4
        h_all = []; 
        for c = 1:numConfigs
            tr_c = traces{c};
            for i = 1:numel(tr_c.rays)
                if size(tr_c.rays(i).points, 1) >= k+1 && all(isfinite(tr_c.rays(i).points(k+1,:)))
                    dp = tr_c.rays(i).points(k+1,:) - tr_c.O(k,:); 
                    h_all(end+1) = dp * tr_c.NY(k,:)'; 
                end
            end
        end
        if ~isempty(h_all)
            D_max(k) = max(abs(h_all));
        end
    end
    
    f_total = 0;
    for c = 1:numConfigs
        tr_c = traces{c};
        % ==========================================================
        % 🌟 为 MEX 函数专门打包“纯净版”结构体，规避 C++ 字段数检查报错
        tr_mex = struct();
        tr_mex.P_S     = tr_c.P_S;
        tr_mex.R       = tr_c.R;
        tr_mex.K_conic = tr_c.K_conic;
        tr_mex.O       = tr_c.O;
        tr_mex.NX      = tr_c.NX;
        tr_mex.NY      = tr_c.NY;
        % ==========================================================

        if stopPos == 5 || stopPos == 0
            f_c = funLine6q_mex(tr_mex, D_max, stopPos);
        else
            f_c = funLine5q_mex(tr_mex, D_max, stopPos);
        end
        f_total = f_total + f_c;
    end
    
    pts = extract_system_point_cloud_local(traces, D_max);
    if isempty(pts)
        L = 1000; W = 1000;
    else
        min_ZY = min(pts, [], 1); max_ZY = max(pts, [], 1);
        L = max_ZY(1) - min_ZY(1); W = max_ZY(2) - min_ZY(2); 
    end
    t_obs = toc(t_ob_start);
end

function pts = extract_system_point_cloud_local(traces_cell, D_max)
    pts = []; numConfigs = length(traces_cell);
    for t = 1:numConfigs
        tr = traces_cell{t};
        for i = 1:numel(tr.rays)
            p = tr.rays(i).surfacePoints; 
            if size(p, 1) > 1
                valid_p = p(2:end, :); 
            else
                valid_p = p;
            end
            valid_p = valid_p(isfinite(valid_p(:,1)), :);
            pts = [pts; valid_p(:,2), valid_p(:,1)]; 
        end
        for k = 1:4
            y_edge = D_max(k); R_eff = tr.R(k);
            if k == 2 || k == 4, R_eff = -R_eff; end
            c = 1 / R_eff; K = tr.K_conic(k);
            y_vec = linspace(-y_edge, y_edge, 30); 
            if abs(c) < 1e-12, x_vec = zeros(size(y_vec));
            else
                radicand = 1 - (1+K)*(c*y_vec).^2;
                valid = radicand >= 0; y_vec = y_vec(valid);
                x_vec = (c * y_vec.^2) ./ (1 + sqrt(radicand(valid)));
            end
            for i = 1:length(y_vec)
                pt = tr.O(k,:) + x_vec(i) * tr.NX(k,:) + y_vec(i) * tr.NY(k,:);
                pts = [pts; pt(2), pt(1)];
            end
        end
    end
end