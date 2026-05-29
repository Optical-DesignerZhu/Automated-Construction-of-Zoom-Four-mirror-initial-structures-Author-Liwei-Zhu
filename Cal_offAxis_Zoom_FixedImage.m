function data_zoom_all = Cal_offAxis_Zoom_FixedImage(sysParam, R1_fixed, d_pos1, alpha_pos1, O1_pos1_z, K_pos1)
%% 离轴四反连续变焦系统核心物理黑盒 (统一版：光阑各位置 + 像面绝对固定 + 三镜固定)
    
    if nargin < 5 || isempty(O1_pos1_z), O1_pos1_z = 400; end
    if nargin < 6 || isempty(K_pos1), K_pos1 = []; end
    
    data_zoom_all = [];
    if isfield(sysParam, 'N_pos')
        N_pos = sysParam.N_pos; f_pos1 = sysParam.pos(1).f;
    else
        N_pos = 2; f_pos1 = sysParam.pos1.f;
    end
    
    n = [1, -1, 1, -1, 1]; h1_val = 1.0;
    
    if isfield(sysParam, 'stopPosition') && sysParam.stopPosition == 5
        if isfield(sysParam, 'stopToImage'), r5_val = sysParam.stopToImage; else, r5_val = 30; end
    else
        r5_val = O1_pos1_z; 
    end
    
    %% --- 阶段 1：求解变焦位置 1 (fmincon 保持不变) ---
    C1_fixed = 1 / R1_fixed;
    x0_pos1 =  [1/600.29, 1/500, 1/206.805, 0.1, -0.4, -1.5];
    lb1 = [-5, -5, -5, -5, -5, -5]; ub1 = [5,  5,  5,  5,  5.0,  5.0];
    
    persistent opt_cached;
    if isempty(opt_cached)
        opt_cached = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'off', ...
            'MaxFunctionEvaluations', 5000, 'MaxIterations', 2000, 'ConstraintTolerance', 1e-8, 'StepTolerance', 1e-10);
    end
    options = opt_cached;
    
    nonlcon1 = @(x) deal([], my_eqs_pos1_C(x, f_pos1, d_pos1, C1_fixed, h1_val, n));
    [sol1, ~, exitflag1] = fmincon(@(x)0, x0_pos1, [], [], [], [], lb1, ub1, nonlcon1, options);
    if exitflag1 <= 0, return; end 
    
    C_sol = [C1_fixed, sol1(1:3)]; R_all = 1 ./ C_sol; h_pos1 = [h1_val, sol1(4:6)];
    
    %% --- 阶段 2：计算基准坐标 ---
    O1_pos1 = [0, O1_pos1_z];
    O2_pos1 = O1_pos1 + d_pos1(1) * [sind(2*alpha_pos1(1)), cosd(2*alpha_pos1(1))];
    O3_pos1 = O2_pos1 + d_pos1(2) * [sind(2*(sum(alpha_pos1(1:2)))), cosd(2*(sum(alpha_pos1(1:2))))];
    O4_pos1 = O3_pos1 + d_pos1(3) * [sind(2*(sum(alpha_pos1(1:3)))), cosd(2*(sum(alpha_pos1(1:3))))];
    Oim_pos1 = O4_pos1 + d_pos1(4) * [sind(2*(sum(alpha_pos1(1:4)))), cosd(2*(sum(alpha_pos1(1:4))))];
    
    cfg1_array = [R_all, r5_val, d_pos1, alpha_pos1, K_pos1];
    temp_data_zoom = zeros(N_pos, length(cfg1_array)); temp_data_zoom(1, :) = cfg1_array;
    
    sum_a1_ref = 2 * alpha_pos1(1); sum_a2_ref = 2 * sum(alpha_pos1(1:2));
    sum_a3_ref = 2 * sum(alpha_pos1(1:3)); sum_a4_ref = 2 * sum(alpha_pos1(1:4));
    unwrap_angle = @(calc_ang, ref_ang) ref_ang + mod(calc_ang - ref_ang + 180, 360) - 180;
    
    prev_O2 = O2_pos1; prev_O4 = O4_pos1; prev_d  = d_pos1; prev_h  = h_pos1;
    
    %% --- 阶段 3：循环推导后续连续变焦位置 (🌟 启用 fsolve 降维打击) ---
    persistent opt_fsolve_cached;
    if isempty(opt_fsolve_cached)
        opt_fsolve_cached = optimoptions('fsolve', 'Algorithm', 'trust-region-dogleg', ...
            'Display', 'off', 'FunctionTolerance', 1e-8, 'StepTolerance', 1e-10);
    end
    
    for i = 2:N_pos
        if isfield(sysParam, 'pos'), f_target = sysParam.pos(i).f; else, f_target = sysParam.pos2.f; end
        
        y0_pos_i = [prev_O2, prev_O4, prev_d, prev_h];
        % 直接把 12维残差函数喂给 fsolve，砍掉所有 fmincon 开销
        eq_func_i = @(y) my_eqs_pos2_PerfectFixedImage(y, n, R_all, O1_pos1, O2_pos1, O3_pos1, O4_pos1, Oim_pos1, f_target);
        [sol_i, ~, exitflag_i] = fsolve(eq_func_i, y0_pos_i, opt_fsolve_cached);
        
        if exitflag_i <= 0, data_zoom_all = []; return; end
        
        O2_pos_i = sol_i(1:2); O4_pos_i = sol_i(3:4); d_pos_i  = sol_i(5:8); h_pos_i  = sol_i(9:12);
        
        theta1 = atan2d((O2_pos_i(1) - O1_pos1(1)) / d_pos_i(1), (O2_pos_i(2) - O1_pos1(2)) / d_pos_i(1));
        theta2 = atan2d((O3_pos1(1) - O2_pos_i(1)) / d_pos_i(2), (O3_pos1(2) - O2_pos_i(2)) / d_pos_i(2));
        theta3 = atan2d((O4_pos_i(1) - O3_pos1(1)) / d_pos_i(3), (O4_pos_i(2) - O3_pos1(2)) / d_pos_i(3));
        theta4 = atan2d((Oim_pos1(1) - O4_pos_i(1)) / d_pos_i(4), (Oim_pos1(2) - O4_pos_i(2)) / d_pos_i(4));
        
        alpha_pos_i = zeros(1,4);
        alpha_pos_i(1) = unwrap_angle(theta1, sum_a1_ref) / 2;
        alpha_pos_i(2) = unwrap_angle(theta2, sum_a2_ref) / 2 - alpha_pos_i(1);
        alpha_pos_i(3) = unwrap_angle(theta3, sum_a3_ref) / 2 - sum(alpha_pos_i(1:2));
        alpha_pos_i(4) = unwrap_angle(theta4, sum_a4_ref) / 2 - sum(alpha_pos_i(1:3));
        
        temp_data_zoom(i, :) = [R_all, r5_val, d_pos_i, alpha_pos_i, K_pos1];
        prev_O2 = O2_pos_i; prev_O4 = O4_pos_i; prev_d  = d_pos_i; prev_h  = h_pos_i;
    end
    data_zoom_all = temp_data_zoom;
end

function F1 = my_eqs_pos1_C(x, f_pos1, d_pos1, C1_val, h1_val, n)
    C = [C1_val, x(1:3)]; h = [h1_val, x(4:6)]; phi = (n(2:5) - n(1:4)) .* C;
    F1 = zeros(6,1);
    F1(1) = h(2) - (h(1) + d_pos1(1)*(h(1)*phi(1)));
    F1(2) = h(3) - (h(2) - d_pos1(2)*(h(1)*phi(1) + h(2)*phi(2)));
    F1(3) = h(4) - (h(3) + d_pos1(3)*(h(1)*phi(1) + h(2)*phi(2) + h(3)*phi(3)));
    F1(4) = sum(h .* phi) - h(1)/f_pos1;
    F1(5) = d_pos1(4)/h(4) - f_pos1/h(1);
    F1(6) = sum(phi); 
end

function F2 = my_eqs_pos2_PerfectFixedImage(y, n, R, O1_pos1, O2_pos1, O3_pos1, O4_pos1, Oim_pos1, f_target)
    O2_pos2 = y(1:2); O4_pos2 = y(3:4); d_pos2 = y(5:8); h_pos2 = y(9:12);
    phi = (n(2:5) - n(1:4)) ./ R; F2 = zeros(12,1);
    F2(1) = (O2_pos1(1)-O1_pos1(1))*(O2_pos2(2)-O1_pos1(2)) - (O2_pos2(1)-O1_pos1(1))*(O2_pos1(2)-O1_pos1(2));
    F2(2) = (Oim_pos1(1)-O4_pos1(1))*(O4_pos2(2)-Oim_pos1(2)) - (O4_pos2(1)-Oim_pos1(1))*(Oim_pos1(2)-O4_pos1(2));
    F2(3) = sum((O2_pos2 - O1_pos1).^2) - d_pos2(1)^2;
    F2(4) = sum((O3_pos1 - O2_pos2).^2) - d_pos2(2)^2;
    F2(5) = sum((O4_pos2 - O3_pos1).^2) - d_pos2(3)^2;
    F2(6) = sum((Oim_pos1 - O4_pos2).^2) - d_pos2(4)^2;
    F2(7) = h_pos2(2) - (h_pos2(1) + d_pos2(1)*h_pos2(1)*phi(1));
    F2(8) = h_pos2(3) - (h_pos2(2) - d_pos2(2)*(h_pos2(1)*phi(1)+h_pos2(2)*phi(2)));
    F2(9) = h_pos2(4) - (h_pos2(3) + d_pos2(3)*(h_pos2(1)*phi(1)+h_pos2(2)*phi(2)+h_pos2(3)*phi(3)));
    F2(10) = sum(h_pos2 .* phi) - h_pos2(1)/f_target;
    F2(11) = d_pos2(4)/h_pos2(4) - f_target/h_pos2(1);
    F2(12) = h_pos2(1) - 1.0;
end