function [g_opt_all, gbest_opt, nm_history] = run_NM(g_aco_pos1,sysParam)
%% Nelder-Mead (NM) 单纯形局部优化算法 - 支持多组态连续变焦版
% 输入参数:
%   g_aco_pos1 - 只需要传入基准组态1的参数(1x13或1x17向量)作为起点即可
%   sysParam   - 系统参数结构体
    disp('========== 启动 Nelder-Mead 局部精确优化 ==========');
    
    % ================= 0. 判断架构与变焦模式 =================
    isStopAfter = false;
    isStopOnMirror = false;
    isConic = isfield(sysParam, 'surfaceType') && strcmpi(sysParam.surfaceType, 'CON');
    
    if isfield(sysParam, 'stopPosition')
        if sysParam.stopPosition == 5
            isStopAfter = true;  
            if isConic, disp('>> [NM] 检测到 光阑后置(实出瞳) + 圆锥面，启动 13 维局部寻优...');
            else, disp('>> [NM] 检测到 光阑后置(实出瞳)，启动 9 维局部寻优...'); end
        elseif sysParam.stopPosition >= 1 && sysParam.stopPosition <= 4
            isStopOnMirror = true;
            if isConic, disp(['>> [NM] 检测到 光阑设于镜面 M', num2str(sysParam.stopPosition), ' 上 + 圆锥面，启动 13 维局部寻优...']);
            else, disp(['>> [NM] 检测到 光阑设于镜面 M', num2str(sysParam.stopPosition), ' 上，启动 9 维局部寻优...']); end
        else
            if isConic, disp('>> [NM] 检测到 光阑前置(常规独立面) + 圆锥面，启动 14 维局部寻优...');
            else, disp('>> [NM] 检测到 光阑前置(常规独立面)，启动 10 维局部寻优...'); end
        end
    else
        if isConic, disp('>> [NM] 默认 光阑前置(常规独立面) + 圆锥面，启动 14 维局部寻优...');
        else, disp('>> [NM] 默认 光阑前置(常规独立面)，启动 10 维局部寻优...'); end
    end
    
    if isfield(sysParam, 'move') && sysParam.move == 1
        isMovingImage = true;
    else
        isMovingImage = false;
    end
    
    % ================= 1. 参数设置 =================
    T_nm_max = sysParam.algo.nm.T_nm_max;
    tol_nm   = sysParam.algo.nm.tol_nm;
    
    % ================= 2. 提取自适应探索空间及边界 =================
    Xmin = sysParam.bounds.xmin(:)';     
    Xmax = sysParam.bounds.xmax(:)';
    
    if isStopAfter || isStopOnMirror
        if isConic
            idx_active = [1, 6:13, 14:17]; % 包含圆锥系数
        else
            idx_active = [1, 6:13]; % 剔除第5维
        end
    else
        if isConic
            idx_active = [1, 5:13, 14:17]; % 包含第5维(d0)和圆锥系数
        else
            idx_active = [1, 5:13]; % 包含第5维(d0)
        end
    end
    
    lb = Xmin(idx_active); 
    ub = Xmax(idx_active); 
    
    % ================= 3. 提取 NM 的初始基点 =================
    % 虽然是N个组态，但寻优空间只基于组态1降维
    x0_nm = g_aco_pos1(idx_active)'; 
    
    % ================= 4. 定义 NM 包装器 =================
    objective = @(x) objective_func_wrapper(x, sysParam, isStopAfter, isStopOnMirror, isMovingImage, isConic);
    
    % ================= 5. 运行 NM =================
    disp('>> [NM] 开始快速本地数学计算迭代...');
    tic;
    [xopt_nm, gbest_opt, nm_history] = nelder_mead_bounded(objective, x0_nm, T_nm_max, tol_nm, lb, ub);
    nm_time = toc;
    
    % ================= 6. 反算并输出完整连续变焦组态结果 =================
    [~, g_opt_all] = objective_func_wrapper(xopt_nm, sysParam, isStopAfter, isStopOnMirror, isMovingImage, isConic);
    
    fprintf('========== Nelder-Mead 阶段完成 (耗时: %.2f 秒) ==========\n', nm_time);
end

% ================= 辅助函数 1：NM 目标函数包装器 =================
function [f, data_zoom_all] = objective_func_wrapper(x_col, sysParam, isStopAfter, isStopOnMirror, isMovingImage, isConic)
    ant_red = x_col'; 
    
    if isStopAfter || isStopOnMirror
        R1_fixed   = ant_red(1);
        d_pos1     = ant_red(2:5);   
        alpha_pos1 = ant_red(6:9);   
        O1_pos1_z  = 400; 
        if isConic, K_pos1 = ant_red(10:13); else, K_pos1 = []; end
    else
        R1_fixed   = ant_red(1);
        O1_pos1_z  = ant_red(2); 
        d_pos1     = ant_red(3:6);   
        alpha_pos1 = ant_red(7:10);   
        if isConic, K_pos1 = ant_red(11:14); else, K_pos1 = []; end
    end
    
    if isMovingImage
        data_zoom_all = Cal_offAxis_Zoom_MovingImage(sysParam, R1_fixed, d_pos1, alpha_pos1, O1_pos1_z, K_pos1);
    else
        data_zoom_all = Cal_offAxis_Zoom_FixedImage(sysParam, R1_fixed, d_pos1, alpha_pos1, O1_pos1_z, K_pos1);
    end
    
    if ~isempty(data_zoom_all)
        % 此处 cv 仅作为占位符向下传递，实际 calc_MeritFunction 已不调用
        f = calc_MeritFunction(data_zoom_all,  sysParam);
    else
        f = 1e6; 
        % 若物理求解失败，返回 0 矩阵以保持格式兼容 (动态识别13维/17维)
        D_full = 13;
        if isConic, D_full = 17; end
        
        if isfield(sysParam, 'N_pos')
            data_zoom_all = zeros(sysParam.N_pos, D_full);
        else
            data_zoom_all = zeros(2, D_full);
        end
    end
end
% ================= 辅助函数 2：NM单纯形法引擎 (带精准监控面板版) =================
function [xopt, fopt, history] = nelder_mead_bounded(obj_fun, x0, max_iter, tol, lb, ub)
    n = length(x0);
    alpha = 1; gamma = 2; rho = 0.5; sigma = 0.5; 
    
    simplex = zeros(n+1, n);
    simplex(1, :) = min(max(x0', lb), ub);  
    delta = 0.05;  
    for i = 1:n
        simplex(i+1, :) = simplex(1, :);
        simplex(i+1, i) = simplex(i+1, i) + delta * abs(simplex(1, i)) + 1e-6; 
        simplex(i+1, :) = min(max(simplex(i+1, :), lb), ub); 
    end
    
    fvals = zeros(n+1, 1);
    
    fprintf('  ├─ [NM] 正在初始化单纯形顶点并启动 Parfor 评估...\n');
    t_init = tic;
    % 🌟 优化点 1：并行化初始单纯形的 n+1 次评估
    parfor i = 1:n+1
        fvals(i) = obj_fun(simplex(i, :)');  
    end
    fprintf('  ├─ [NM] 初始单纯形评估完成, 耗时: %.2f 秒 | 起点 Merit: %.6f\n', toc(t_init), min(fvals));
    
    history = zeros(max_iter, 1);
    iter = 0;
    
    fprintf('  ├─ [NM] 进入局部精确迭代循环...\n');
    t_loop = tic;
    
    while iter < max_iter
        iter = iter + 1;
        [fvals, idx] = sort(fvals);
        simplex = simplex(idx, :);
        
        if max(fvals) - min(fvals) < tol
            fprintf('  ├─ [NM 触发收敛] 顶点差异小于容差 (%.1e)，提前在 Iter %d 结束！\n', tol, iter);
            break;
        end
        
        centroid = mean(simplex(1:end-1, :), 1);
        xr = min(max(centroid + alpha * (centroid - simplex(end, :)), lb), ub);  
        fr = obj_fun(xr');
        
        if fr < fvals(1)  
            xe = min(max(centroid + gamma * (xr - centroid), lb), ub);  
            fe = obj_fun(xe');
            if fe < fr
                simplex(end, :) = xe; fvals(end) = fe;
            else
                simplex(end, :) = xr; fvals(end) = fr;
            end
        elseif fr < fvals(end-1)  
            simplex(end, :) = xr; fvals(end) = fr;
        else  
            if fr < fvals(end)  
                xc = min(max(centroid + rho * (xr - centroid), lb), ub); 
            else  
                xc = min(max(centroid + rho * (simplex(end, :) - centroid), lb), ub); 
            end
            fc = obj_fun(xc');
            if fc < fvals(end)
                simplex(end, :) = xc; fvals(end) = fc;
            else  
                % 🌟 优化点 2：并行化极其耗时的 Shrink (收缩) 操作
                fprintf('  │   ├─ [NM 性能警告] Iter %d 触发全局 Shrink (启动 Parfor 重估 %d 个点)...\n', iter, n);
                best_point = simplex(1, :);
                temp_simplex = zeros(n, n);
                temp_fvals = zeros(n, 1);
                
                % 提取需要缩放的原始点，避开 parfor 广播变量警告
                orig_points = simplex(2:end, :);
                
                parfor j = 1:n
                    % 向最优点收缩并施加边界约束
                    new_p = min(max(best_point + sigma * (orig_points(j, :) - best_point), lb), ub);
                    temp_simplex(j, :) = new_p;
                    temp_fvals(j) = obj_fun(new_p');
                end
                
                % 将并行计算的结果写回原矩阵
                simplex(2:end, :) = temp_simplex;
                fvals(2:end) = temp_fvals;
            end
        end
        history(iter) = min(fvals);
        
        % 🌟 频率控制输出：每 20 代播报一次进度，避免刷屏
        if mod(iter, 20) == 0
            fprintf('  │   ├─ [NM Iter %3d/%3d] 当前最优 Merit: %.6f\n', iter, max_iter, history(iter));
        end
    end
    
    fprintf('  ├─ [NM] 单纯形迭代结束, 循环耗时: %.2f 秒 | 最终 Merit: %.6f\n', toc(t_loop), min(fvals));
    xopt = simplex(1, :)'; fopt = min(fvals); history = history(1:iter);  
end