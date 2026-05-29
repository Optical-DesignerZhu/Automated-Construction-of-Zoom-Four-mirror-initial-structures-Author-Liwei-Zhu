function plot_trace_result(result, ax, cfg_color, cfg_idx, D_mech)
% 独立的 MATLAB 离轴光路绘制函数 (支持全局坐标系叠加与单色渲染，智能裁切100mm外包络)
% 新增参数 D_mech: 1x4 数组，代表 M1~M4 的真实机械半宽 (可选)

    % 防错处理
    if nargin < 2 || isempty(ax)
        fig = figure('Name', 'Single Config Off-Axis Trace', 'Color', 'w');
        ax = axes('Parent', fig); 
        hold(ax, 'on'); axis(ax, 'equal'); grid(ax, 'on');
        xlabel(ax, 'Z (mm)'); ylabel(ax, 'Y (mm)');
    end
    if nargin < 3 || isempty(cfg_color), cfg_color = 'b'; end
    if nargin < 4 || isempty(cfg_idx), cfg_label = ''; else, cfg_label = sprintf('(C%d)', cfg_idx); end
    if nargin < 5, D_mech = []; end % 默认未提供物理尺寸
    
    O = result.O; R_signed = result.R; K_conic = result.K_conic; NX = result.NX; NY = result.NY;
    
    % 准备收集物理坐标以计算真实外包络
    all_Z = []; all_Y = [];
    
    % =========================================================
    % 绘制 4 个反射镜面 (核心修改区：按真实物理尺寸 D_mech 绘图)
    % =========================================================
    % 依然计算当前组态的光斑足迹，作为兜底方案
    hits_Y_local = cell(4, 1); for k = 1:4, hits_Y_local{k} = []; end
    for i = 1:numel(result.rays)
        ptsAll = result.rays(i).points;
        for k = 1:4
            hit_pt = ptsAll(k+1, :);
            if all(isfinite(hit_pt)), dp = hit_pt - O(k, :); hits_Y_local{k}(end+1) = dp * NY(k, :)'; end
        end
    end
    
    for k = 1:4
        % 🌟 判断是否传入了真实的物理金属尺寸
        if ~isempty(D_mech) && length(D_mech) >= k && D_mech(k) > 0
            % 如果有全局机械尺寸，直接使用
            D = D_mech(k);
        else
            % 如果没传，退化为当前组态的光斑动态尺寸
            if isempty(hits_Y_local{k})
                D = 10;
            else
                D = max(abs(hits_Y_local{k})); 
                if D < 1e-4, D = 5; end
            end
        end
        
        y_vec = linspace(-D, D, 300);
        R_eff = R_signed(k); if k == 2 || k == 4, R_eff = -R_signed(k); end
        c = 1 / R_eff;
        if abs(c) < 1e-12, x_vec = zeros(size(y_vec));
        else
            radicand = 1 - (1 + K_conic(k)) * (c * y_vec).^2;
            valid = radicand >= 0; y_vec = y_vec(valid); radicand = radicand(valid);
            x_vec = (c * y_vec.^2) ./ (1 + sqrt(radicand));
        end
        Y_curve = O(k, 1) + x_vec * NX(k, 1) + y_vec * NY(k, 1);
        Z_curve = O(k, 2) + x_vec * NX(k, 2) + y_vec * NY(k, 2);
        
        % 收集面型坐标用于包络计算
        all_Z = [all_Z, Z_curve]; all_Y = [all_Y, Y_curve];
        
        % 绘制反射面
        plot(ax, Z_curve, Y_curve, '-', 'Color', cfg_color, 'LineWidth', 0.1);
        
        % 绘制法线轴标识
        len_axis = D * 0.4; 
        ax_Z = [O(k,2) - len_axis*NX(k,2), O(k,2) + len_axis*NX(k,2)]; 
        ax_Y = [O(k,1) - len_axis*NX(k,1), O(k,1) + len_axis*NX(k,1)];
        plot(ax, ax_Z, ax_Y, '-.', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.1);
        
        % 绘制顶点
        plot(ax, O(k, 2), O(k, 1), 'ko', 'MarkerFaceColor', cfg_color, 'MarkerSize', 4);
        text(O(k, 2), O(k, 1), sprintf(' M%d%s', k, cfg_label), 'FontSize', 9, 'Color', cfg_color, 'Parent', ax);
    end
    
    % =========================================================
    % 绘制光线
    % =========================================================
    for i = 1:numel(result.rays)
        ptsAll = result.rays(i).points; refPt = result.rays(i).refPoint; pFirst = ptsAll(1, :);
        if all(isfinite(refPt)) && all(isfinite(pFirst))
            dir_in = pFirst - refPt; dir_in = dir_in / norm(dir_in);
            pt_start = pFirst - 50 * dir_in;
            plot(ax, [pt_start(2), pFirst(2)], [pt_start(1), pFirst(1)], '--', 'Color', cfg_color, 'LineWidth', 0.1);
            
            all_Z = [all_Z, pt_start(2)]; all_Y = [all_Y, pt_start(1)];
        end
        for s = 1:size(ptsAll, 1) - 1
            pA = ptsAll(s, :); pB = ptsAll(s + 1, :);
            if all(isfinite(pA)) && all(isfinite(pB))
                all_Z = [all_Z, pA(2), pB(2)]; all_Y = [all_Y, pA(1), pB(1)];
                if s < 5 && ~all(isfinite(ptsAll(s+2, :)))
                    plot(ax, [pA(2), pB(2)], [pA(1), pB(1)], '-.', 'Color', cfg_color, 'LineWidth', 0.1);
                    plot(ax, pB(2), pB(1), 'rh', 'MarkerSize', 8, 'MarkerFaceColor', 'r'); 
                else
                    plot(ax, [pA(2), pB(2)], [pA(1), pB(1)], '-', 'Color', cfg_color, 'LineWidth', 0.1); 
                end
            end
        end
    end
    
    % =========================================================
    % 绘制像面 (Image)
    % =========================================================
    if isfield(result, 'imagePlaneRef') && ~isempty(result.imagePlaneRef)
        O_im = result.imagePlaneRef(1, :); NY_im = result.imagePlaneRef(2, :) - O_im;
        pt1 = O_im + 15 * NY_im; pt2 = O_im - 15 * NY_im;
        plot(ax, [pt1(2), pt2(2)], [pt1(1), pt2(1)], '-', 'Color', cfg_color, 'LineWidth', 0.1);
        text(O_im(2), O_im(1) + 8, sprintf(' IMG%s', cfg_label), 'FontSize', 9, 'FontWeight', 'bold', 'Color', cfg_color, 'Parent', ax);
        
        all_Z = [all_Z, pt1(2), pt2(2)]; all_Y = [all_Y, pt1(1), pt2(1)];
    end
    
    % =========================================================
    % 绘制冷阑 (Stop)
    % =========================================================
    draw_stop = isfield(result, 'stopPlaneRef') && ~isempty(result.stopPlaneRef);
    if draw_stop && isfield(result, 'stopPos')
        draw_stop = ~(result.stopPos >= 1 && result.stopPos <= 4);
    end

    if draw_stop
        O_stop = result.stopPlaneRef(1, :); NY_stop = result.stopPlaneRef(2, :) - O_stop;
        if isfield(result, 'R_stop') && ~isnan(result.R_stop), aper_h = result.R_stop; else, aper_h = 0.5; end
        
        ptTop1 = O_stop + aper_h * NY_stop; ptTop2 = O_stop + (aper_h + 4) * NY_stop;
        plot(ax, [ptTop1(2), ptTop2(2)], [ptTop1(1), ptTop2(1)], '-', 'Color', cfg_color, 'LineWidth', 1);
        ptBot1 = O_stop - aper_h * NY_stop; ptBot2 = O_stop - (aper_h + 4) * NY_stop;
        plot(ax, [ptBot1(2), ptBot2(2)], [ptBot1(1), ptBot2(1)], '-', 'Color', cfg_color, 'LineWidth', 1);
        
        % plot(ax, O_stop(2), O_stop(1), 'x', 'Color', cfg_color, 'MarkerSize', 6, 'LineWidth', 0.5);
        text(O_stop(2), O_stop(1) + aper_h + 5, sprintf(' STOP%s', cfg_label), 'FontSize', 9, 'Color', cfg_color, 'FontWeight', 'bold', 'Parent', ax);
        
        all_Z = [all_Z, ptTop2(2), ptBot2(2)]; all_Y = [all_Y, ptTop2(1), ptBot2(1)];
    end
    
    % =========================================================
    % 🌟 动态计算 100mm 物理极限外包络并锁定视图
    % =========================================================
    if ~isempty(all_Z) && ~isempty(all_Y)
        curr_Zmin = min(all_Z); curr_Zmax = max(all_Z);
        curr_Ymin = min(all_Y); curr_Ymax = max(all_Y);
        
        % 读取之前存储的全局外包络 (用于多组态叠加)
        global_box = get(ax, 'UserData');
        if isempty(global_box)
            global_box = [curr_Zmin, curr_Zmax, curr_Ymin, curr_Ymax];
        else
            global_box = [min(global_box(1), curr_Zmin), max(global_box(2), curr_Zmax), ...
                          min(global_box(3), curr_Ymin), max(global_box(4), curr_Ymax)];
        end
        
        % 存入最新包络
        set(ax, 'UserData', global_box);
        
        % 严格应用边界，并向外扩展 100mm
        xlim(ax, [global_box(1) - 100, global_box(2) + 100]);
        ylim(ax, [global_box(3) - 100, global_box(4) + 100]);
    end
end