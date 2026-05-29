function [f_list, data_zoom_list] = analyze_zoom_focal_length(data, d1_range)
% analyze_zoom_focal_length - 分析系统整体焦距随间隔 d1 的变化规律并画图
%
% 输入:
%   data     - 系统的基础/初始结构 (1x11 向量: [R1~R4, d1~d3, alpha1~alpha4])
%   d1_range - d1 的变化范围数组 (可选，若不输入则默认在原值基础上变动 +/- 20%)
%
% 输出:
%   f_list         - 对应各个 d1 的系统焦距数组
%   data_zoom_list - 对应各个 d1 的完整系统参数矩阵 (N x 11 维)

    % ================= 1. 提取基础定焦参数 =================
    R = data(1:4);
    d_base = data(5:7);
    alpha_base = data(8:11);
    
    % 调用已有的 CalculateFir 函数获取初始状态的后截距
    [~, BFL_base] = CalculateFir(data);
    d_pos1 = [d_base, BFL_base];
    
    % ================= 2. 确定 d1 的遍历范围 =================
    if nargin < 2
        d1_base = d_base(1);
        % 默认范围：以 d1_base 为中心，波动 20% (生成 100 个点用于平滑绘图)
        d1_range = linspace(d1_base * 0.8, d1_base * 1.2, 100); 
    end
    
    % ================= 3. 计算固定镜面的绝对坐标 =================
    % 在您的四反变焦设计中，M1, M3, M4 是固定的，只有 M2 和像面移动
    O1 = [0, 400]; % M1 坐标系原点
    O2_base = O1 + d_pos1(1) * [sind(2*alpha_base(1)), cosd(2*alpha_base(1))];
    O3 = O2_base + d_pos1(2) * [sind(2*(alpha_base(1) + alpha_base(2))), cosd(2*(alpha_base(1) + alpha_base(2)))];
    O4 = O3 + d_pos1(3) * [sind(2*(alpha_base(1) + alpha_base(2) + alpha_base(3))), cosd(2*(alpha_base(1) + alpha_base(2) + alpha_base(3)))];
    
    % 预分配空间，提升计算速度
    num_points = length(d1_range);
    f_list = zeros(1, num_points);
    data_zoom_list = zeros(num_points, 11);
    
    % ================= 4. 正向解析计算全过程 =================
    for i = 1:num_points
        d1_new = d1_range(i);
        
        % --- A. 计算新的坐标与间距 ---
        alpha1_new = alpha_base(1); % M1 倾斜角固定不变
        
        % M2 沿入射光轴方向移动，计算新位置
        O2_new = O1 + d1_new * [sind(2*alpha1_new), cosd(2*alpha1_new)];
        
        % 计算新的 d2 (O3位置固定，仅受O2移动影响)
        d2_new_mag = norm(O3 - O2_new);
        d2_new = sign(d_pos1(2)) * d2_new_mag; % 保持原有的符号设定
        
        % M3 到 M4 的间距是固定的
        d3_new = d_pos1(3);
        
        % --- B. 动态修正镜面倾斜角以保证光轴对准 ---
        a_sum1 = alpha1_new;
        % 根据几何关系直接求出反射出射角的绝对角度
        a_sum2 = asind((O3(1) - O2_new(1)) / d2_new) / 2;
        a_sum3 = asind((O4(1) - O3(1)) / d3_new) / 2;
        
        alpha2_new = a_sum2 - a_sum1;
        alpha3_new = a_sum3 - a_sum2;
        alpha4_new = alpha_base(4); % M4 到像面的出射方向不变，故 alpha4 固定
        
        % --- C. 重组参数并求解焦距 ---
        % 将求得的新系统参数封装成标准 11 维格式
        r_temp = [R, d1_new, d2_new, d3_new, alpha1_new, alpha2_new, alpha3_new, alpha4_new];
        
        % 直接调用您现成的高斯理论公式函数获取对应的 EFL
        [f_new, ~] = CalculateFir(r_temp);
        
        % 保存数据
        f_list(i) = f_new;
        data_zoom_list(i, :) = r_temp;
    end
    
    % ================= 5. 绘制焦距随 d1 变化的动态曲线 =================
    figure('Name', '焦距随 d1 变化关系', 'Color', 'w');
    plot(d1_range, f_list, 'b-', 'LineWidth', 2);
    xlabel('M1 与 M2 的间距 d_1 (mm)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('系统整体焦距 f (mm)', 'FontSize', 12, 'FontWeight', 'bold');
    title('系统焦距随镜面平移量的动态变化规律', 'FontSize', 14);
    grid on;
    set(gca, 'FontSize', 11, 'GridLineStyle', '--');
    
    % 可选：在图中标出原起始点的位置
    hold on;
    [f_base, ~] = CalculateFir(data);
    plot(d_base(1), f_base, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    legend('焦距变化曲线', '当前参考点(Pos1)', 'Location', 'best');
    hold off;
end