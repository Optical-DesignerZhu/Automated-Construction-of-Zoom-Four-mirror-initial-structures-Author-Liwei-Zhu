function data_zoom_all = Cal_offAxis_Zoom_MovingImage(sysParam, R1_fixed, d_pos1, alpha_pos1, O1_pos1_z, K_pos1)
% Cal_offAxis_Zoom_MovingImage - 离轴四反连续变焦核心物理黑盒 (像面移动架构)
    
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
    
    % =========================================================================
    %                           【第一阶段：求解变焦位置 1】
    % =========================================================================
    C1_fixed = 1 / R1_fixed;
    x0_pos1 = [1/600.29, 1/500, 1/206.805, 0.1, -0.4, -1.5];
    lb1 = [-5, -5, -5, -10, -10, -10]; ub1 = [ 5,  5,  5,  10,  10,  10];
    
    persistent opt_cached;
    if isempty(opt_cached)
        opt_cached = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'off', ...
            'MaxFunctionEvaluations', 5000, 'MaxIterations', 2000, 'ConstraintTolerance', 1e-8, 'StepTolerance', 1e-10);
    end
    options = opt_cached;
        
    nonlcon1 = @(x) deal([], my_eqs_pos1_C(x, f_pos1, d_pos1, C1_fixed, h1_val, n));
    [sol1, ~, exit1] = fmincon(@(x)0, x0_pos1, [], [], [], [], lb1, ub1, nonlcon1, options);
    if exit1 <= 0, return; end
    
    C_sol = sol1(1:3); R_all = [R1_fixed, 1 ./ C_sol]; h_pos1_solved = [h1_val, sol1(4:6)];
    
    % =========================================================================
    %                           【第二阶段：计算位置 1 坐标】
    % =========================================================================
    O1_pos1 = [0, O1_pos1_z];
    O2_pos1 = O1_pos1 + d_pos1(1) * [sind(2*alpha_pos1(1)) , cosd(2*alpha_pos1(1))];
    O3_pos1 = O2_pos1 + d_pos1(2) * [sind(2*(sum(alpha_pos1(1:2)))) , cosd(2*(sum(alpha_pos1(1:2))))];
    O4_pos1 = O3_pos1 + d_pos1(3) * [sind(2*(sum(alpha_pos1(1:3)))) , cosd(2*(sum(alpha_pos1(1:3))))];
    Oim_pos1 = O4_pos1 + d_pos1(4) * [sind(2*(sum(alpha_pos1(1:4)))) , cosd(2*(sum(alpha_pos1(1:4))))];
    
    cfg1_array = [R_all, r5_val, d_pos1, alpha_pos1, K_pos1];
    temp_data_zoom = zeros(N_pos, length(cfg1_array)); temp_data_zoom(1, :) = cfg1_array;
    
    sum_a1_ref = 2 * alpha_pos1(1); sum_a2_ref = 2 * sum(alpha_pos1(1:2));
    sum_a3_ref = 2 * sum(alpha_pos1(1:3)); sum_a4_ref = 2 * sum(alpha_pos1(1:4));
    unwrap_angle = @(calc_ang, ref_ang) ref_ang + mod(calc_ang - ref_ang + 180, 360) - 180;
    
    prev_O2  = O2_pos1; prev_Oim = Oim_pos1; prev_d   = d_pos1; prev_h   = h_pos1_solved;
    
    % =========================================================================
    %                           【第三阶段：循环推导后续组态 (🌟 启用 fsolve)】
    % =========================================================================
    persistent opt_fsolve_cached;
    if isempty(opt_fsolve_cached)
        opt_fsolve_cached = optimoptions('fsolve', 'Algorithm', 'trust-region-dogleg', ...
            'Display', 'off', 'FunctionTolerance', 1e-8, 'StepTolerance', 1e-10);
    end

    for i = 2:N_pos
        if isfield(sysParam, 'pos'), f_target = sysParam.pos(i).f; else, f_target = sysParam.pos2.f; end
        
        y0_pos_i = [prev_O2, prev_Oim, prev_d, prev_h];
        % 直接把 12维残差函数喂给 fsolve
        eq_func_i = @(y) my_eqs_pos2_MovingImage(y, n, R_all, O1_pos1, O2_pos1, O3_pos1, O4_pos1, Oim_pos1, d_pos1, f_target);
        [sol_i, ~, exit_i] = fsolve(eq_func_i, y0_pos_i, opt_fsolve_cached);
        
        if exit_i <= 0, data_zoom_all = []; return; end
        
        O2_pos_i = sol_i(1:2); Oim_pos_i = sol_i(3:4); d_pos_i = sol_i(5:8); h_pos_i = sol_i(9:12);
        
        theta1 = atan2d((O2_pos_i(1) - O1_pos1(1)) / d_pos_i(1), (O2_pos_i(2) - O1_pos1(2)) / d_pos_i(1));
        theta2 = atan2d((O3_pos1(1) - O2_pos_i(1)) / d_pos_i(2), (O3_pos1(2) - O2_pos_i(2)) / d_pos_i(2));
        theta3 = atan2d((O4_pos1(1) - O3_pos1(1)) / d_pos_i(3), (O4_pos1(2) - O3_pos1(2)) / d_pos_i(3));
        theta4 = atan2d((Oim_pos_i(1) - O4_pos1(1)) / d_pos_i(4), (Oim_pos_i(2) - O4_pos1(2)) / d_pos_i(4));
        
        alpha_pos_i = zeros(1,4);
        alpha_pos_i(1) = unwrap_angle(theta1, sum_a1_ref) / 2;
        alpha_pos_i(2) = unwrap_angle(theta2, sum_a2_ref) / 2 - alpha_pos_i(1);
        alpha_pos_i(3) = unwrap_angle(theta3, sum_a3_ref) / 2 - sum(alpha_pos_i(1:2));
        alpha_pos_i(4) = unwrap_angle(theta4, sum_a4_ref) / 2 - sum(alpha_pos_i(1:3));
        
        temp_data_zoom(i, :) = [R_all, r5_val, d_pos_i, alpha_pos_i, K_pos1];
        prev_O2  = O2_pos_i; prev_Oim = Oim_pos_i; prev_d   = d_pos_i; prev_h   = h_pos_i;
    end
    data_zoom_all = temp_data_zoom;
end

function F1 = my_eqs_pos1_C(x, f_pos1, d_pos1, C1_val, h1_val, n)
    C = [C1_val, x(1:3)]; h_pos1_h = [h1_val, x(4:6)]; phi = (n(2:5) - n(1:4)) .* C;
    F1 = zeros(6,1);
    F1(1) = h_pos1_h(2) - (h_pos1_h(1) + d_pos1(1) * (h_pos1_h(1)*phi(1)));
    F1(2) = h_pos1_h(3) - (h_pos1_h(2) - d_pos1(2) * (h_pos1_h(1)*phi(1) + h_pos1_h(2)*phi(2)));
    F1(3) = h_pos1_h(4) - (h_pos1_h(3) + d_pos1(3) * (h_pos1_h(1)*phi(1) + h_pos1_h(2)*phi(2) + h_pos1_h(3)*phi(3)));
    F1(4) = sum(h_pos1_h .* phi) - h_pos1_h(1)/f_pos1;
    F1(5) = d_pos1(4)/h_pos1_h(4) - f_pos1/h_pos1_h(1);
    F1(6) = sum(phi);
end

function F2 = my_eqs_pos2_MovingImage(y, n, R, O1_pos1, O2_pos1, O3_pos1, O4_pos1, Oim_pos1, d_pos1_anchor, f_target)
    F2 = zeros(12,1);
    O2_pos2 = [y(1), y(2)]; Oim_pos2 = [y(3), y(4)]; d_pos2 = y(5:8); h_pos2 = y(9:12);
    F2(1) = (O2_pos1(1) - O1_pos1(1)) * (O2_pos2(2) - O1_pos1(2)) - (O2_pos2(1) - O1_pos1(1)) * (O2_pos1(2) - O1_pos1(2));
    F2(2) = (Oim_pos1(1) - O4_pos1(1)) * (Oim_pos2(2) - O4_pos1(2)) - (Oim_pos2(1) - O4_pos1(1)) * (Oim_pos1(2) - O4_pos1(2));
    F2(3) = (O2_pos2(1) -  O1_pos1(1))^2 + (O2_pos2(2) -  O1_pos1(2))^2 - d_pos2(1)^2;
    F2(4) = (O3_pos1(1) -  O2_pos2(1))^2 + (O3_pos1(2) -  O2_pos2(2))^2 - d_pos2(2)^2;
    F2(5) = d_pos2(3) - d_pos1_anchor(3); 
    F2(6) = (Oim_pos2(1) - O4_pos1(1))^2 + (Oim_pos2(2) - O4_pos1(2))^2 - d_pos2(4)^2;
    phi = (n(2:5) - n(1:4)) ./ R;
    F2(7) = h_pos2(2) - (h_pos2(1) + d_pos2(1) * (h_pos2(1)*phi(1)));   
    F2(8) = h_pos2(3) - (h_pos2(2) - d_pos2(2) * (h_pos2(1)*phi(1) + h_pos2(2)*phi(2)));
    F2(9) = h_pos2(4) - (h_pos2(3) + d_pos2(3) * (h_pos2(1)*phi(1) + h_pos2(2)*phi(2) + h_pos2(3)*phi(3)));
    F2(10) = sum(h_pos2 .* phi) - h_pos2(1)/f_target;      
    F2(11) = d_pos2(4)/h_pos2(4) - f_target/h_pos2(1);    
    F2(12) = h_pos2(1) - 1;
end