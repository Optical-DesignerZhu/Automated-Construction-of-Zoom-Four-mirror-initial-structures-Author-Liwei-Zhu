function [fig, ax] = plot_2D_zoom_overlay(g_opt_all, sysParam, isVisible)
% plot_2D_zoom_overlay - 连续变焦系统 2D 剖面多组态叠加渲染器
% 基于 drawYZ.m 逻辑封装
% 输入:
%   g_opt_all : 多组态优化解矩阵
%   sysParam  : 系统参数结构体
%   isVisible : 'on' (显示窗口) 或 'off' (后台静默渲染不弹窗)

    if nargin < 3
        isVisible = 'on'; % 默认显示窗口
    end

    % 创建 Figure 并应用 isVisible 开关
    fig = figure('Name', 'Zoom System Global Overlay', ...
                 'Color', 'w', 'Position', [100, 100, 1200, 600], ...
                 'Visible', isVisible);
    ax = axes('Parent', fig);
    hold(ax, 'on'); axis(ax, 'equal'); grid(ax, 'on');
    xlabel(ax, 'Z (mm)', 'FontSize', 12, 'FontWeight', 'bold'); 
    ylabel(ax, 'Y (mm)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax, 'Zoom System Global 2D Overlay', 'FontSize', 14, 'FontWeight', 'bold');
    
    color_map = {'r', 'b', 'm', 'g', 'c', 'y'};
    
    % 1. 先进行一次全局预追迹，提取 M1~M4 贯穿所有组态的最大物理半宽 D_max
    D_max_global = zeros(1, 4);
    traces_all = cell(1, sysParam.N_pos);
    
    for c = 1:sysParam.N_pos
        r_new = g_opt_all(c, :);  
        
        % ============= 🌟 适配光阑位置和圆锥系数 K =============
        if sysParam.stopPosition == 5
            d_stop_img = sysParam.stopToImage;   
            dex = r_new(9) - d_stop_img;         
            if length(r_new) >= 17
                K_pos = r_new(14:17);
            else
                K_pos = [];
            end
            r_trace = [r_new(1:4), r_new(6:8), dex, d_stop_img, r_new(10:13), K_pos];
        else
            r_trace = r_new;
        end
        % ===============================================================
        
        epd_c = sysParam.pos(c).epd;
        fa_c = [-sysParam.pos(c).hfov, 0, sysParam.pos(c).hfov];
        
        % 缓存当前组态追迹结果
        traces_all{c} = trace_single_config_offaxis(r_trace, epd_c, fa_c, sysParam.stopPosition);
        
        % 统计光斑足迹计算 D_max
        tr_c = traces_all{c};
        for k = 1:4
            h_all = [];
            for r_idx = 1:numel(tr_c.rays)
                if size(tr_c.rays(r_idx).points, 1) >= k+1 && all(isfinite(tr_c.rays(r_idx).points(k+1,:)))
                    dp = tr_c.rays(r_idx).points(k+1,:) - tr_c.O(k,:);
                    h_all(end+1) = dp * tr_c.NY(k,:)';
                end
            end
            if ~isempty(h_all)
                D_max_global(k) = max(D_max_global(k), max(abs(h_all)));
            end
        end
    end
    
    % 附加物理装配余量
    D_max_global = D_max_global + 2.0;
    
    % 2. 传入真实的机械尺寸，执行高保真渲染 (依赖 plot_trace_result 函数)
    for c = 1:sysParam.N_pos
        cfg_color = color_map{mod(c-1, length(color_map)) + 1};
        plot_trace_result(traces_all{c}, ax, cfg_color, c, D_max_global);
    end
    
    % 生成图例
    h_leg = zeros(1, sysParam.N_pos);
    leg_str = cell(1, sysParam.N_pos);
    for c = 1:sysParam.N_pos
        cfg_color = color_map{mod(c-1, length(color_map)) + 1};
        h_leg(c) = plot(ax, NaN, NaN, '-', 'Color', cfg_color, 'LineWidth', 2); 
        leg_str{c} = sprintf('Config %d', c);
    end
    legend(ax, h_leg, leg_str, 'Location', 'best', 'FontSize', 11);
end