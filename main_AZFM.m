%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%*****Description : Automated Construction of Zoom Four-mirror initial structures
%*****Author : Liwei Zhu
%*****Date : Mar. 10, 2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear;
%% 定义系统参数结构体
sysParam = struct();
% 变焦形式选择 (1: 动像, 2: 稳像)
sysParam.move = 2;

% =========================================================================
% 【核心提效】：使用变量与数组自动生成连续变焦的所有组态参数
% =========================================================================
% 1. 定义光学系统基准参数 (以短焦位作为基准)
base_f        = -100;   % 起始焦距 (短焦)
base_F_number = 4;      % 整个系统保持恒定的 F数
base_hfov     = 2;      % 短焦对应的半视场角

% 2. 设定连续变焦的采样点
target_max_f  = -200;   % 目标最长焦距
sysParam.N_pos = 2;     % 设定我们要采样几个组态 (例如: 3 表示短、中、长 3个点)

% 自动生成等间距的焦距数组 (例如 [-100, -150, -200])，也可自己指定
f_list = linspace(base_f, target_max_f, sysParam.N_pos);

% 3. 循环自动构建所有组态的理想光学参数
for i = 1:sysParam.N_pos
    sysParam.pos(i).F_number = base_F_number;
    sysParam.pos(i).f        = f_list(i);
    % 视场角与焦距成反比 (拉赫不变量)
    sysParam.pos(i).hfov     = base_hfov * (base_f / f_list(i)); 
    % 入瞳直径 = 焦距 / F数
    sysParam.pos(i).epd      = abs(f_list(i) / base_F_number);
end

% =========================================================================
% 定义光阑的位置，以及选择的求解的面型
sysParam.stopPosition = 0;     % 0:前置, 1~4:在M1~M4上, 5:后置(实出瞳)
sysParam.stopToImage = 25;     % 若 stopPosition=5 需要指定的距离
sysParam.surfaceType = 'CON'; 
sysParam.field_grid_size = 5;  % （代表采样密度）

% 搜索空间范围限制 (13维边界)
sysParam.bounds.xmin = [-8000; -8000; -8000; -8000;  50; -400; 100; -400;  100;   6; -30; -30; -30; -20; -20; -20; -20];
sysParam.bounds.xmax = [ 8000;  8000;  8000;  8000; 500; -100; 400; -100; 400;  30;  30;  30;  30;  20;  20;  20;  20];

% ================= 算法超参数设置与几何约束设置 =================
sysParam.algo.aco.N_pop     = 200;   
sysParam.algo.aco.T_aco_min = 20;    
sysParam.algo.aco.T_aco_max = 22;    
sysParam.algo.aco.m         = 50;    
sysParam.algo.aco.q         = 0.02;  
sysParam.algo.aco.xi        = 0.85;  
sysParam.algo.nm.T_nm_max   = 150;   
sysParam.algo.nm.tol_nm     = 1e-7;  

% ================= 评价函数灵活控制与权重设置 =================
% 【控制模式选择】 (1: 线性直接作为权重加入, 2: 阈值硬约束平方惩罚)
sysParam.mode.vol      = 2;  % 体积控制模式 (默认1: 线性压缩)
sysParam.mode.aperture = 2;  % 口径控制模式 (默认2: 硬边界限制)
sysParam.mode.stroke   = 2;  % 行程控制模式 (默认2: 硬边界限制)

% -------------------------------------------------------------
% [模式 1 专用参数] 线性直接权重系数 (引导该指标越小越好)
sysParam.weight.vol             = 0.01;  % 继承您的设定：体积的线性权重
sysParam.weight.aperture_linear = 0.05;  % 口径的线性权重
sysParam.weight.stroke_linear   = 0.05;  % 行程的线性权重

% -------------------------------------------------------------
% [模式 2 专用参数] 阈值上限与平方惩罚权重
sysParam.bounds.max_vol_limit      = 2;   % 体积阈值上限 (L)
sysParam.bounds.max_aperture_limit = 70;   % 继承您的设定：全口径阈值上限 (mm)
sysParam.bounds.max_stroke_M2 = 50;   % 继承您的设定：次镜行程上限 (mm)
sysParam.bounds.max_stroke_M4= 20;    % 继承您的设定：四镜行程上限 (mm)

% 越界后的平方惩罚系数
sysParam.weight.penalty_vol      = 1.0; 
sysParam.weight.penalty_aperture = 1.0;    % 继承您的设定：口径惩罚权重
sysParam.weight.penalty_stroke   = 1.0; 

% -------------------------------------------------------------
% 基础光学指标权重 (波像差与遮拦保持线性模式)
sysParam.weight.line = 0.1;    % 相当于原来的 (f_line_total / 10)
sysParam.weight.wave = 1.0;    % 波前像差的权重

%% =========================================================================
% 🌟 初始化数据矩阵与全局调度参数
% =========================================================================
sysParam.iteration = 1;      % 保留原有的100次外部大循环
N_runs = 10;                 % 每次大循环内，进行10次独立的ACO+NM并发优选

% 动态判定每个组态的参数维度 (球面=13, 圆锥面=17)
if strcmpi(sysParam.surfaceType, 'CON')
    numParams = 17;
else
    numParams = 13;
end

% 为本次运行创建专属的独立保存文件夹
time_str = datestr(now, 'yyyymmdd_HHMMSS');
save_dir = sprintf('AZFM_Results_%s', time_str);
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end
fprintf('\n>> 📂 已创建专属结果文件夹: %s\n', save_dir);

% 🌟 核心修改：动态分配存储空间，现在需要保存 iteration * N_runs 行全量数据
solutionData = zeros(sysParam.iteration * N_runs, sysParam.N_pos * numParams + 1);

for it = 1:sysParam.iteration
    fprintf('\n======================================================\n');
    fprintf('=== 第 %d 轮次开始 (本轮将执行 %d 次独立并发优选) ===\n', it, N_runs);
    fprintf('======================================================\n');
    
    aco_bests = zeros(N_runs, 1);
    aco_all_list = cell(N_runs, 1);
    aco_pos1_list = cell(N_runs, 1);
    
    %% 1. 运行 10 次独立的 ACO 全局探索 (串行调度，内部占满CPU)
    t_aco_start = tic;
    for r = 1:N_runs
        fprintf('\n>>> [第 %d 轮次] 正在执行内部第 %d/%d 次独立 ACO 搜索...\n', it, r, N_runs);
        [g_aco_all, gbest_aco, ~] = run_ACO(sysParam);
        
        aco_bests(r) = gbest_aco;
        aco_all_list{r} = g_aco_all;
        aco_pos1_list{r} = g_aco_all(1, :);
    end
    fprintf('\n>> [第 %d 轮次] %d 次 ACO 搜索完成，耗时 %.2f 秒。\n', it, N_runs, toc(t_aco_start));
    
    %% 2. 运行 10 路 NM 局部优化并发 (并行调度，外部占满CPU)
    fprintf('>> [第 %d 轮次] 正在启动 %d 路并发 NM 局部精确寻优...\n', it, N_runs);
    
    nm_bests = zeros(N_runs, 1);
    nm_opt_all_list = cell(N_runs, 1);
    
    t_nm_start = tic;
    parfor r = 1:N_runs
        if aco_bests(r) > 8 
            % ACO 结果较差，直接跳过 NM
            nm_opt_all_list{r} = aco_all_list{r};
            nm_bests(r) = aco_bests(r);
        else
            % 正常进行 NM 寻优
            [g_opt_all_nm, gbest_nm, ~] = run_NM(aco_pos1_list{r}, sysParam);
            
            if gbest_nm < aco_bests(r)
                nm_opt_all_list{r} = g_opt_all_nm;
                nm_bests(r) = gbest_nm;
            else
                nm_opt_all_list{r} = aco_all_list{r};
                nm_bests(r) = aco_bests(r);
            end
        end
    end
    fprintf('>> [第 %d 轮次] %d 路并发 NM 完成，耗时 %.2f 秒。\n', it, N_runs, toc(t_nm_start));
    
    %% 3. 🌟 全量输出：依次打印、绘图并保存本轮的 10 个独立结果
    fprintf('\n========== 正在输出并保存本轮全量图纸与数据 ==========\n');
    for r = 1:N_runs
        g_opt_all = nm_opt_all_list{r};
        gbest_opt = nm_bests(r);
        
        fprintf('\n=== 第 %d 轮次 - 独立分支 %d 结果 ===\n', it, r);
        fprintf('ACO 阶段: 该分支最优适应度值 = %.6f\n', aco_bests(r)); 
        fprintf('全局最终: 该分支最优适应度值 = %.6f\n', gbest_opt);
        
        % 调用打印函数
        printZoomSystemParameters(g_opt_all, gbest_opt, sysParam);     
        
        % 提取核心物理指标与系统最大口径（注意用 ~ 占位 timings）
        [~, final_line_avg, final_wave_avg, final_vol_unit, ~, final_max_D,stroke_M2, stroke_M4] = calc_MeritFunction(g_opt_all, sysParam);
        
        % 打印输出（体积 final_vol_unit 本身已经是 L，直接输出即可）
        fprintf('物理指标: 波前 = %.4f | 遮拦 = %.4f | 扫掠体积 = %.2f L | 最大口径 = %.1f mm\n', ...
                final_wave_avg, final_line_avg, final_vol_unit, final_max_D);
        % 🌟 新增：打印当前分支结果的变焦行程，方便与硬约束进行对比监控
        fprintf('行程监控: 次镜(M2)行程 = %.2f mm | 四镜(M4)行程 = %.2f mm\n', ...
                stroke_M2, stroke_M4);
        
        % 多组态绘图
        [fig_3d, ax_3d] = plot_2D_zoom_overlay(g_opt_all, sysParam, 'off');
        drawnow; 
        
        % 定义带有 Run 编号的高清图片名称
        img_3d_name = sprintf('Matlab_3D_Iter%02d_Run%02d_Overlay_HD.png', it, r);
        img_3d_path = fullfile(save_dir, img_3d_name);
        fprintf('>> 导出图片: %s ...\n', img_3d_name);
        exportgraphics(fig_3d, img_3d_path, 'Resolution', 300, 'BackgroundColor', 'w');
        close(fig_3d);         
        
        % 存入外层 solutionData (按绝对行号索引)
        row_idx = (it - 1) * N_runs + r;
        for pos_idx = 1:sysParam.N_pos
            start_col = (pos_idx - 1) * numParams + 1;
            end_col   = pos_idx * numParams;
            solutionData(row_idx, start_col:end_col) = g_opt_all(pos_idx, :);
        end
        solutionData(row_idx, end) = gbest_opt;
    end
    fprintf('======================================================\n');
end

%% 数据保存
% 将 .mat 文件保存在专属文件夹内
mat_filename = 'AZFM_Optimization_Data.mat';
mat_filepath = fullfile(save_dir, mat_filename);

% 将系统配置 (sysParam) 及全量历代记录 (solutionData) 存入本地
save(mat_filepath, 'sysParam', 'solutionData');

fprintf('\n✅ 全部 %d 轮运行结束！\n', sysParam.iteration);
fprintf('👉 所有的 %d 张图纸及数据记录已打包至文件夹: [%s]\n', sysParam.iteration * N_runs, save_dir);