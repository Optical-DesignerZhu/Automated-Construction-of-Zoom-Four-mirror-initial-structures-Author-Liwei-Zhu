
load("D:\OneDrive\PhD\Other\UndergraduateThesis_LinJvnPeng\Code\version11\AZFM_Optimization_Data.mat");

for i = 1:15
    g_opt_all(1,:) = solutionData(i,1:17);
    g_opt_all(2,:) = solutionData(i,1+17:17+17);
    % g_opt_all(3,:) = solutionData(i,1+17+17:17+17+17);
    % g_opt_all(4,:) = solutionData(i,1+17+17+17:17+17+17+17);

    fprintf('\n=== 正在生成 MATLAB 原生底层光路剖析图 ===\n');
    fig_merged = figure('Name', sprintf('MATLAB Trace Overlay - Iter: %d', i), ...
                        'Color', 'w', 'Position', [100, 100, 1200, 600]);
    ax = axes('Parent', fig_merged);
    hold(ax, 'on'); axis(ax, 'equal'); grid(ax, 'on');
    xlabel(ax, 'Z (mm)', 'FontSize', 12, 'FontWeight', 'bold'); 
    ylabel(ax, 'Y (mm)', 'FontSize', 12, 'FontWeight', 'bold');
    title(ax, sprintf('Zoom System Global Overlay - Iter: %d', i), 'FontSize', 14, 'FontWeight', 'bold');
    
    color_map = {'r', 'b', 'm', 'g', 'c', 'y'};
    
    % 1. 先进行一次全局预追迹，提取 M1~M4 贯穿所有组态的最大物理半宽 D_max
    D_max_global = zeros(1, 4);
    traces_all = cell(1, sysParam.N_pos);
    
    for c = 1:sysParam.N_pos
        r_new = g_opt_all(c, :);  % 完美适配你的 g_opt_all 矩阵！
        
        % ============= 🌟 核心修复 2：拼接时补上圆锥系数 K =============
        if sysParam.stopPosition == 5
            d_stop_img = sysParam.stopToImage;   % 光阑到像面距离永远固定
            dex = r_new(9) - d_stop_img;         % 动态计算 M4 到光阑的距离
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
    
    % 2. 传入真实的机械尺寸，执行高保真渲染
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
    drawnow;
    
    % =================================================================
    % 🌟 自动保存和自动关闭窗口逻辑
    % =================================================================
    % 保存合并后的高分辨率 PNG 图片
    img_name = sprintf('Matlab_Trace_Iter%02d_Overlay.png', i);
    print(fig_merged, img_name, '-dpng', '-r600');
    
    % 关闭图像释放内存
    % close(fig_merged);
end



    