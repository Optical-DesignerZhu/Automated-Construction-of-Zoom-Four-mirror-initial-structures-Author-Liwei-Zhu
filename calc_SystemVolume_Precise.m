function [vol, all_pts_3d] = calc_SystemVolume_Precise(traces, D_max, sysParam)
% calc_SystemVolume_Precise - 计算包含全光路(反射镜+光阑+像面)的精确扫掠体积 (极速向量化版)
    if isfield(sysParam, 'stopPosition'), stopPos = sysParam.stopPosition; else, stopPos = 0; end
    numConfigs = length(traces);
    
    num_rim_pts = 40; 
    theta = linspace(0, 2*pi, num_rim_pts)';
    m_thick = 3; 
    
    % [优化 1] 预计算三角函数
    cos_theta = cos(theta);
    sin_theta = sin(theta);
    
    % [优化 2] 预分配内存池，彻底消灭动态扩容
    % 每个组态最多: M1~M4 (4*2*40=320) + 像面(40) + 光阑(40) = 400 个点
    max_pts = numConfigs * 400;
    pts_buffer = zeros(max_pts, 3);
    pt_idx = 1; % 缓冲区写入指针
    
    for c = 1:numConfigs
        tr = traces{c};
        if ~isfield(tr, 'valid') || ~tr.valid, continue; end
        
        % =========================================================
        % A. 实体镜面点云 (M1-M4)
        % =========================================================
        for k = 1:4
            r_edge = D_max(k);
            xl = r_edge * cos_theta; 
            yl = r_edge * sin_theta;
            
            Nz_norm = tr.NX(k, 2); 
            Ny_norm = tr.NX(k, 1); 
            M_g2l = [1, 0, 0; 0, Nz_norm, -Ny_norm; 0, Ny_norm, Nz_norm];
            
            c_val = 1 / tr.R(k); K_val = tr.K_conic(k);
            radicand = 1 - (1+K_val)*c_val^2.*(xl.^2 + yl.^2);
            
            % 提取有效索引，规避 NaN
            v_s = radicand >= 0;
            zl_f = NaN(num_rim_pts, 1);
            zl_f(v_s) = (c_val * (xl(v_s).^2 + yl(v_s).^2)) ./ (1 + sqrt(radicand(v_s)));
            zl_b = zl_f + m_thick;
            
            valid_mask = ~isnan(zl_f);
            num_valid = sum(valid_mask);
            
            if num_valid > 0
                O_k = [0, tr.O(k, 1), tr.O(k, 2)];
                
                % 利用隐式扩展快速变换坐标
                p_f = [xl(valid_mask), yl(valid_mask), zl_f(valid_mask)] * M_g2l + O_k;
                p_b = [xl(valid_mask), yl(valid_mask), zl_b(valid_mask)] * M_g2l + O_k;
                
                % 批量写入缓冲区
                write_len = num_valid * 2;
                pts_buffer(pt_idx : pt_idx + write_len - 1, :) = [p_f; p_b];
                pt_idx = pt_idx + write_len;
            end
        end
        
        % =========================================================
        % B. 像面点云 (提取射线最远点作为真实半径)
        % =========================================================
        if isfield(tr, 'imagePlaneRef')
            all_img_pts = reshape([tr.rays.imagePoint], 2, [])';
            valid_img_pts = all_img_pts(isfinite(all_img_pts(:,1)), :);
            
            if ~isempty(valid_img_pts)
                diffs = valid_img_pts - tr.imagePlaneRef(1,:);
                r_im = sqrt(max(sum(diffs.^2, 2))); 
            else
                r_im = 0;
            end
            if r_im < 1e-3, r_im = 1; end
            
            O_im = [0, tr.imagePlaneRef(1, 1), tr.imagePlaneRef(1, 2)];
            if stopPos == 5
                dir_out = tr.imagePlaneRef(1,:) - tr.stopPlaneRef(1,:);
            else
                dir_out = tr.imagePlaneRef(1,:) - tr.O(4,:);
            end
            dir_out = dir_out / norm(dir_out);
            v_y = dir_out(1); v_z = dir_out(2);
            M_im = [1, 0, 0; 0, v_z, -v_y; 0, v_y, v_z];
            
            xl_im = r_im * cos_theta; yl_im = r_im * sin_theta;
            p_im = [xl_im, yl_im, zeros(num_rim_pts, 1)] * M_im + O_im;
            
            pts_buffer(pt_idx : pt_idx + num_rim_pts - 1, :) = p_im;
            pt_idx = pt_idx + num_rim_pts;
        end
        
        % =========================================================
        % C. 光阑点云
        % =========================================================
        if stopPos == 0
            r_s = sysParam.pos(c).epd / 2;
            p_s = [r_s * cos_theta, r_s * sin_theta, zeros(num_rim_pts, 1)];
            
            pts_buffer(pt_idx : pt_idx + num_rim_pts - 1, :) = p_s;
            pt_idx = pt_idx + num_rim_pts;
            
        elseif stopPos == 5
            F_num_ideal = abs(sysParam.pos(c).f) / sysParam.pos(c).epd;
            r_s = sysParam.stopToImage / (2 * F_num_ideal); 
            
            Oy = tr.stopPlaneRef(1, 1); Oz = tr.stopPlaneRef(1, 2);
            dir_out = tr.imagePlaneRef(1,:) - tr.stopPlaneRef(1,:);
            dir_out = dir_out / norm(dir_out);
            v_y = dir_out(1); v_z = dir_out(2);
            M_s = [1, 0, 0; 0, v_z, -v_y; 0, v_y, v_z];
            
            xl_s = r_s * cos_theta; yl_s = r_s * sin_theta;
            p_s = [xl_s, yl_s, zeros(num_rim_pts, 1)] * M_s + [0, Oy, Oz];
            
            pts_buffer(pt_idx : pt_idx + num_rim_pts - 1, :) = p_s;
            pt_idx = pt_idx + num_rim_pts;
            
        elseif stopPos >= 1 && stopPos <= 4
            r_s = D_max(stopPos) * 0.95;
            Oy = tr.O(stopPos, 1); Oz = tr.O(stopPos, 2);
            Ny_s = tr.NX(stopPos, 1); Nz_s = tr.NX(stopPos, 2);
            M_s = [1, 0, 0; 0, Nz_s, -Ny_s; 0, Ny_s, Nz_s];
            
            xl_s = r_s * cos_theta; yl_s = r_s * sin_theta;
            p_s = [xl_s, yl_s, zeros(num_rim_pts, 1)] * M_s + [0, Oy, Oz];
            
            pts_buffer(pt_idx : pt_idx + num_rim_pts - 1, :) = p_s;
            pt_idx = pt_idx + num_rim_pts;
        end
    end
    
    % 截断有效数据
    all_pts_3d = pts_buffer(1 : pt_idx - 1, :);
    
    if size(all_pts_3d, 1) > 4
        try
            % =================================================================
            % 🌟 终极黑科技 1：注入确定性的“纳米级微扰”
            % 打破圆形点云的完美共面退化态，规避 Qhull 的最差时间复杂度
            % =================================================================
            N_pts = size(all_pts_3d, 1);
            perturb = (1:N_pts)' * 1e-8; 
            all_pts_3d(:,1) = all_pts_3d(:,1) + perturb;
            all_pts_3d(:,2) = all_pts_3d(:,2) - perturb;
            all_pts_3d(:,3) = all_pts_3d(:,3) + perturb;
            
            % =================================================================
            % 🌟 终极黑科技 2：关闭 Simplify 参数
            % =================================================================
            [~, vol] = convhull(all_pts_3d(:,3), all_pts_3d(:,1), all_pts_3d(:,2), 'Simplify', false);
        catch
            vol = 1e8;
        end
    else
        vol = 1e8;
    end
end