function Fiber_PAS_Sim_Precomputed_Fast()
    % 六马达光纤熔接机 CMOS 成像效果 (终极性能版)
    % 核心架构：启动时预渲染全空间 3D 数据立方体，UI交互零延迟刷新
    clc; clear; close all;
    
    %% 1. 宽谱光源与空间基础参数
    lambda_center = 0.650; FWHM = 0.030; sigma_lambda = FWHM / 2.355; 
    % 使用 5 个波长点保证宽谱平滑度与预计算速度的平衡
    lambdas = linspace(lambda_center - 1.5*sigma_lambda, lambda_center + 1.5*sigma_lambda, 5);
    weights = exp(-0.5 * ((lambdas - lambda_center) / sigma_lambda).^2);
    weights = weights / sum(weights); 
    
    R_clad = 62.5; n_air = 1.0; NA = 0.35;
    
    L_y = 300; N_y = 4096; % 使用 4096 保证分辨率
    y = linspace(-L_y/2, L_y/2, N_y);
    fy = fftshift((-N_y/2 : N_y/2-1) * (1/L_y));
    
    display_range = [-80, 80];
    idx_crop = (y >= display_range(1)) & (y <= display_range(2));
    y_crop = y(idx_crop);
    
    %% 2. 光纤模型库
    fibers = struct(...
        'Name', {'G.651 (多模渐变)', 'G.652 (标准单模)', 'G.654 (大硅芯)', 'G.654.E (大有效面积)', 'G.655 (细芯)', 'G.657 (沟槽抗弯)'}, ...
        'R_core', {25.0, 4.5, 5.5, 6.25, 3.0, 4.3}, ...
        'n_core_max', {1.465, 1.449, 1.444, 1.444, 1.450, 1.449}, ...
        'n_clad', {1.450, 1.444, 1.439, 1.439, 1.444, 1.444}, ...
        'Profile', {'Graded', 'Step', 'Step', 'Step', 'Step', 'Trench'} ... 
    );
    num_fibers = length(fibers);
    
    %% 3. 【核心】空间缓存预计算 (Pre-computation)
    Z_array = -50 : 0.5 : 200; % Z轴切片集合，步长 0.5um
    num_z = length(Z_array);
    
    % 分配 3D 矩阵内存: [光纤类型, Z轴索引, 空间像素]
    Precomputed_I = zeros(num_fibers, num_z, length(y_crop));
    
    h_wait = waitbar(0, '正在初始化光学引擎并预渲染全空间焦平面，请稍候...');
    for f = 1:num_fibers
        waitbar((f-1)/num_fibers, h_wait, sprintf('正在渲染光纤光学模型 %d / %d ...', f, num_fibers));
        
        % 1. 计算几何黑边与物理光程差
        [OPD, amplitude] = calc_base_features(fibers(f), y, R_clad, n_air, NA);
        
        % 2. 遍历所有 Z 轴切片进行 FFT 传播
        for zi = 1:num_z
            I_1D_crop = propagate_ffts(OPD, amplitude, fibers(f).R_core, Z_array(zi), y, fy, lambdas, weights, NA, idx_crop);
            Precomputed_I(f, zi, :) = I_1D_crop;
        end
    end
    close(h_wait);
    
    %% 4. 构建零延迟 GUI
    gui_fig = figure('Name', '光纤 PAS 成像仿真 (极速缓存版)', 'Position', [50, 50, 1500, 850], 'Color', '#1E1E1E');
    set(gui_fig, 'WindowScrollWheelFcn', @mouse_wheel_callback);
    
    % UI 控件
    uicontrol('Style', 'text', 'Position', [500, 810, 120, 20], 'String', '散焦平面 Z (μm):', 'BackgroundColor', '#1E1E1E', 'ForegroundColor', 'w', 'FontSize', 10, 'FontWeight', 'bold');
    z_slider = uicontrol('Style', 'slider', 'Position', [630, 810, 300, 20], 'Min', 1, 'Max', num_z, 'Value', 101, 'SliderStep', [1/(num_z-1), 10/(num_z-1)], 'Callback', @update_ui);
    z_label = uicontrol('Style', 'text', 'Position', [940, 810, 80, 20], 'String', sprintf('%.1f', Z_array(101)), 'BackgroundColor', '#1E1E1E', 'ForegroundColor', '#00FF00', 'FontSize', 10, 'FontWeight', 'bold');
    uicontrol('Style', 'text', 'Position', [630, 790, 300, 15], 'String', '(在窗口内滚动鼠标滚轮快速穿透焦平面)', 'BackgroundColor', '#1E1E1E', 'ForegroundColor', '#888888', 'FontSize', 8);

    % 坐标轴设置
    ax_1d = axes('Parent', gui_fig, 'Position', [0.05, 0.45, 0.82, 0.32], 'Color', 'k', 'XColor', 'w', 'YColor', 'w');
    title(ax_1d, '1D 剖面信号全局对比', 'Color', 'w', 'FontSize', 12);
    xlim(ax_1d, [-80, 80]); ylim(ax_1d, [-0.05, 1.05]); grid(ax_1d, 'on'); set(ax_1d, 'GridColor', '#333333');
    hold(ax_1d, 'on');
    
    x_positions = [0.05, 0.38, 0.71]; y_positions = [0.23, 0.02];
    ax_2d = cell(1, num_fibers);
    h_lines = zeros(1, num_fibers); % 保存 1D 曲线句柄
    h_imgs = zeros(1, num_fibers);  % 保存 2D 图像句柄
    colors = {'#E6194B', '#3CB44B', '#0082C8', '#F58231', '#911EB4', '#FFFFFF'};
    
    Image_height_pix = 200;
    x_axis = linspace(0, 100, Image_height_pix);
    
    % 初始化空图像，获取句柄
    for f = 1:num_fibers
        % 初始化 1D 曲线
        h_lines(f) = plot(ax_1d, y_crop, squeeze(Precomputed_I(f, 101, :)), 'Color', colors{f}, 'LineWidth', 1.5, 'DisplayName', fibers(f).Name);
        
        % 初始化 2D 屏幕
        row = floor((f-1)/3) + 1; col = mod(f-1, 3) + 1;
        ax_2d{f} = axes('Parent', gui_fig, 'Position', [x_positions(col), y_positions(row), 0.25, 0.16]);
        h_imgs(f) = imagesc(ax_2d{f}, y_crop, x_axis, zeros(Image_height_pix, length(y_crop), 'uint8'));
        colormap(ax_2d{f}, gray(256)); axis(ax_2d{f}, 'image');
        title(ax_2d{f}, fibers(f).Name, 'Color', colors{f}, 'FontSize', 10);
        set(ax_2d{f}, 'YTick', [], 'XColor', '#555', 'YColor', '#555');
    end
    legend(ax_1d, 'show', 'Location', 'northeastoutside', 'FontSize', 10, 'TextColor', 'w');
    
    update_ui(0, 0); % 首次推图
    
    %% GUI 回调：滚轮控制索引
    function mouse_wheel_callback(~, event)
        new_idx = round(z_slider.Value - event.VerticalScrollCount * 2); % 滚一格走2个step (1um)
        new_idx = max(z_slider.Min, min(z_slider.Max, new_idx));
        z_slider.Value = new_idx;
        update_ui(0, 0);
    end

    %% GUI 回调：零延迟显存数据推送
    function update_ui(~, ~)
        zi = round(z_slider.Value);
        z_label.String = sprintf('%.1f', Z_array(zi));
        
        % 预生成动态 CMOS 底噪
        noise_base = 5 * randn(Image_height_pix, length(y_crop));
        
        for f = 1:num_fibers
            % 1. 极速提取缓存
            I_1D = squeeze(Precomputed_I(f, zi, :));
            
            % 2. 极速刷新 1D 曲线 (直接替换内存指针)
            set(h_lines(f), 'YData', I_1D);
            
            % 3. 极速合成 2D 图像并刷新 CData
            I_enhanced = I_1D .^ 1.8; 
            I_8bit = 255 * repmat(I_enhanced(:)', Image_height_pix, 1);
            
            % 加入噪点并截断
            noisy_img = I_8bit + noise_base + 6 * sqrt(abs(I_8bit)/255) .* randn(size(noise_base));
            noisy_img(noisy_img < 0) = 0; noisy_img(noisy_img > 255) = 255;
            
            set(h_imgs(f), 'CData', uint8(noisy_img));
        end
    end

    %% 【算法】几何特征计算
    function [OPD, amplitude] = calc_base_features(fib, y, R_clad, n_air, NA)
        r_dist = abs(y);
        amplitude = zeros(size(y));
        valid_y = r_dist < (R_clad * 0.999); 
        
        theta_i = asin(y(valid_y) / R_clad);
        theta_r = asin(y(valid_y) / (fib.n_clad * R_clad));
        angle_out = zeros(size(y));
        angle_out(valid_y) = 2 * (theta_i - theta_r);
        
        mask_NA = abs(angle_out) <= asin(NA);
        amplitude(valid_y) = (1.0 + 0.3 * (r_dist(valid_y) / R_clad).^2) .* mask_NA(valid_y);
        
        OPD = zeros(size(y));
        for i = 1:length(y)
            if r_dist(i) <= R_clad
                x_max = sqrt(R_clad^2 - y(i)^2);
                x_sample = linspace(-x_max, x_max, 200);
                r_sample = sqrt(y(i)^2 + x_sample.^2); 
                
                n_sample = ones(size(x_sample)) * fib.n_clad;
                if strcmp(fib.Profile, 'Graded')
                    c_mask = r_sample <= fib.R_core;
                    delta = (fib.n_core_max^2 - fib.n_clad^2) / (2 * fib.n_core_max^2);
                    n_sample(c_mask) = fib.n_core_max * sqrt(1 - 2 * delta * (r_sample(c_mask) / fib.R_core).^2);
                elseif strcmp(fib.Profile, 'Trench')
                    c_mask = r_sample <= fib.R_core;
                    n_sample(c_mask) = fib.n_core_max;
                    t_mask = r_sample > 10 & r_sample <= 14;
                    n_sample(t_mask) = fib.n_clad - 0.004;
                else
                    c_mask = r_sample <= fib.R_core;
                    n_sample(c_mask) = fib.n_core_max;
                end
                OPD(i) = trapz(x_sample, n_sample - n_air);
            end
        end
    end

    %% 【算法】FFT 传播
    function I_1D_crop = propagate_ffts(OPD, amplitude, R_core, z_def, y, fy, lambdas, weights, NA, idx_crop)
        z_actual = z_def + R_core;
        Intensity_1D = zeros(size(y));
        
        for w = 1:length(lambdas)
            lam = lambdas(w);
            k_w = 2 * pi / lam;
            
            U_in = amplitude .* exp(1i * k_w * OPD);
            H_fresnel = exp(1i * k_w * z_actual) * exp(-1i * pi * lam * z_actual * fy.^2);
            H_lens = abs(fy) <= (NA / lam); 
            
            U_defocus = ifft(fft(U_in) .* H_fresnel);
            U_image = ifft(fft(U_defocus) .* H_lens);
            
            Intensity_1D = Intensity_1D + weights(w) * (abs(U_image).^2);
        end
        
        I_1D_crop = Intensity_1D(idx_crop);
        I_min = min(I_1D_crop); I_max = max(I_1D_crop);
        if I_max > I_min; I_1D_crop = (I_1D_crop - I_min) / (I_max - I_min); end
    end
end