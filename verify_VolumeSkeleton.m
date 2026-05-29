function vol = verify_VolumeSkeleton(data_zoom_all, sysParam)
% verify_VolumeSkeleton - 验证 3D 评价包络
    if isfield(sysParam, 'stopPosition'), stopPos = sysParam.stopPosition; else, stopPos = 0; end
    N_pos = size(data_zoom_all, 1);
    
    r_configs_cell = cell(1, N_pos); epd_array = zeros(1, N_pos); fa_cell = cell(1, N_pos);
    for i = 1:N_pos
        r_new = data_zoom_all(i, :);
        if stopPos == 5
            d_stop_img = sysParam.stopToImage; dex = r_new(9) - d_stop_img;
            if length(r_new) >= 17, K_pos = r_new(14:17); else, K_pos = []; end
            r_configs_cell{i} = [r_new(1:4), r_new(6:8), dex, d_stop_img, r_new(10:13), K_pos];
        else
            r_configs_cell{i} = r_new;
        end
        epd_array(i) = sysParam.pos(i).epd;
        fa_cell{i} = [-sysParam.pos(i).hfov, 0, sysParam.pos(i).hfov];
    end

    [~, ~, ~, ~, traces, D_max] = funObscurationZoom(r_configs_cell, epd_array, fa_cell, stopPos);
    [vol, all_pts_3d] = calc_SystemVolume_Precise(traces, D_max, sysParam);

    figure('Color','w'); ax = axes; hold on; axis equal; grid on; view(0,0);
    
    plot3(all_pts_3d(:,3), all_pts_3d(:,1), all_pts_3d(:,2), 'r.', 'MarkerSize', 6);
    
    if size(all_pts_3d, 1) > 4
        [K, ~] = convhull(all_pts_3d(:,3), all_pts_3d(:,1), all_pts_3d(:,2));
        trisurf(K, all_pts_3d(:,3), all_pts_3d(:,1), all_pts_3d(:,2), 'FaceColor', [0.6 0.9 1], 'FaceAlpha', 0.15, 'EdgeColor', 'k', 'EdgeAlpha', 0.1);
    end
    
    xlabel('Optical Z (mm)'); ylabel('Optical X (Depth)'); zlabel('Optical Y (mm)');
    title(sprintf('Verified Sweep Volume: %.2f mm^3', vol));
    fprintf('>> [验证] 评价函数视角下的 Sweep Volume: %.2f mm^3\n', vol);
end