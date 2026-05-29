function [hull_vol, fig] = render_3D_zoom_system(configs, sim_data, mech_apertures, sysParam)
% render_3D_zoom_system - 纯渲染模块：接收轨迹数据，生成高保真 3D 包络图
% 返回：
% hull_vol: 基于 3D 渲染点云生成的空间变焦包络体积 (mm^3)
% fig: 生成的 Figure 句柄

    % ========================== ★ Global Display Settings ★ ==========================
    canvas_width_ratio  = 0.9;     
    canvas_height_ratio = 0.85;    
    mirror_alpha = 0.55;           
    mirror_thickness = 3;          
    ray_density_step = 150;        
    ray_alpha = 0.85;              
    ray_width = 0.8;               
    moving_mirror_gray_range = [0.85, 0.35]; 
    moving_mirror_tint       = 0.8;          
    fixed_mirror_color       = [0.9 0.9 0.9];
    env_face_color = [0.6 0.9 1.0]; 
    env_face_alpha = 0.15;          
    env_edge_color = 'none';        
    env_edge_alpha = 0.1;           
    env_edge_width = 0.5;           
    env_mesh_density = 0.5;         
    view_angle = [0, 0];         
    zoom_factor = 0.9;              
    % =================================================================================
    
    if isfield(sysParam, 'stopPosition'), stopPos = sysParam.stopPosition; else, stopPos = 0; end
    N_pos = length(configs);
    config_colors = jet(N_pos); 
    
    scrn = get(0, 'ScreenSize'); screen_W = scrn(3); screen_H = scrn(4);
    fig_W = screen_W * canvas_width_ratio; fig_H = screen_H * canvas_height_ratio;    
    pos_X = (screen_W - fig_W) / 2; pos_Y = (screen_H - fig_H) / 2;
    
    fprintf('\n=== 正在生成 3D 渲染图与包络网格 ===\n');
    fig = figure('Name', 'Zoom System - All Configurations Overlay', 'Color', 'w', 'Position', [pos_X, pos_Y, fig_W, fig_H]); 
    ax = axes('Parent', fig, 'Position', [0.10, 0.10, 0.85, 0.80]); 
    hold(ax, 'on'); grid(ax, 'on'); 
    xlabel(ax, 'Optical Z (mm)', 'FontSize', 12, 'FontWeight', 'bold'); 
    ylabel(ax, 'Optical X (Depth)', 'FontSize', 12, 'FontWeight', 'bold'); 
    zlabel(ax, 'Optical Y (mm)', 'FontSize', 12, 'FontWeight', 'bold');
    
    all_global_pts = []; h_leg = zeros(1, N_pos); leg_str = cell(1, N_pos);
    
    for conf_idx = 1:N_pos
        cfg = configs(conf_idx); data = sim_data(conf_idx); N_flds = length(cfg.fieldAnglesDeg);
        conf_color = config_colors(conf_idx, :);
        
        theta_s = linspace(0, 2*pi, 40)'; 
        
        if stopPos == 5
            r_stop = data.r_stop;
            O_stop_3D = data.O_stop_3D;
            v_y = data.dir_out_global(1); v_z = data.dir_out_global(2);
            M_rot_stop = [1, 0, 0; 0, v_z, -v_y; 0, v_y, v_z];
        elseif stopPos >= 1 && stopPos <= 4
            r_stop = mech_apertures(stopPos) * 0.95;
            O_stop_3D = data.O_3D(stopPos, :);
            Nz_s = data.N_2D(stopPos, 2); Ny_s = data.N_2D(stopPos, 1);
            M_rot_stop = [1, 0, 0; 0, Nz_s, -Ny_s; 0, Ny_s, Nz_s];
        else
            r_stop = cfg.epd / 2;
            O_stop_3D = [0, 0, 0]; M_rot_stop = eye(3);
        end
        pts_stop = [r_stop*cos(theta_s), r_stop*sin(theta_s), zeros(40,1)] * M_rot_stop + repmat(O_stop_3D, 40, 1);
        plot3(ax, pts_stop(:,3), pts_stop(:,1), pts_stop(:,2), '-', 'Color', conf_color, 'LineWidth', 0.6); 
        all_global_pts = [all_global_pts; pts_stop]; 
        
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
        hull_vol = 1e8;
        title(ax, sprintf('Continuous Zoom %d-Configurations Overlay 3D Layout', N_pos), 'FontSize', 16, 'FontWeight', 'bold');
    end
    
    axis(ax, 'equal'); axis(ax, 'tight'); 
    view(ax, view_angle(1), view_angle(2)); camzoom(ax, zoom_factor); 
    camlight(ax); lighting(ax, 'gouraud'); legend(ax, h_leg, leg_str, 'Location', 'best', 'FontSize', 12, 'Box', 'on');
    fprintf('>> [绘图完成] 3D 包络渲染结束。\n');
end