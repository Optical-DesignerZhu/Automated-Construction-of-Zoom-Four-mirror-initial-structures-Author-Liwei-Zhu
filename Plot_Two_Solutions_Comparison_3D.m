function [fig, ax1, ax2] = Plot_Two_Solutions_Comparison_3D(idx1, idx2)
% Plot_Two_Solutions_Comparison_3D
% 指定两个不同目录下的 .mat 文件及其对应的解序号，并将它们放在同一个图窗中对比显示。
% 采用"坐标轴转移"机制，完美兼容自带 figure 创建的底层绘图函数。

    % ==========================================================
    % [调试接口] 3D 视角控制
    % ==========================================================
    % 请在此处修改方位角 (az) 和仰角 (el) 以调整两张图的 3D 旋转视角
    view_az = -15;  % 默认方位角 (例如: 正视可以设为 0)
    view_el = 30;     % 默认仰角 (例如: 俯视可以设为 90)
    % ==========================================================

    if nargin < 2
        idx2 = 1;
    end
    if nargin < 1 || isempty(idx1)
        idx1 = 1;
    end

    % ==========================================================
    % 1. 在这里分别指定两个目录下你要对比的 .mat 文件路径
    % ==========================================================
    mat_file1 = "D:\OneDrive\PhD\Other\UndergraduateThesis_LinJvnPeng\DataResult\Batch_AZFM_Results_withvolWeight\stop_back\stopDistance40\StopRear_F3_HFOV1_Wvol0.04\Full_Data.mat";  
    mat_file2 = "D:\OneDrive\PhD\Other\UndergraduateThesis_LinJvnPeng\DataResult\Batch_AZFM_Results_withvolWeight\stop_front\StopFront_F3_HFOV1_Wvol0.02\Full_Data.mat";  
    
    current_dir = fileparts(mfilename('fullpath'));
    
    % ==========================================================
    % 2. 提取并解析两个系统的数据
    % ==========================================================
    fprintf('=== 正在加载并处理 第一个 系统 ===\n');
    [g_opt_all1, sysParam1] = load_and_parse_data(mat_file1, current_dir, idx1);
    
    fprintf('\n=== 正在加载并处理 第二个 系统 ===\n');
    [g_opt_all2, sysParam2] = load_and_parse_data(mat_file2, current_dir, idx2);

    % ==========================================================
    % 3. 创建主合并图窗并计算排版位置
    % ==========================================================
    % 创建一个宽屏的主图窗
    fig = figure('Name', '3D Solutions Comparison', 'Color', 'w', 'Position', [100, 100, 1400, 600]);

    % 使用 subplot 仅为了获取标准排版的坐标轴位置信息 (Position)
    ax_dummy1 = subplot(1, 2, 1);
    pos1 = get(ax_dummy1, 'Position');
    delete(ax_dummy1); % 拿到位置后删除占位符
    
    ax_dummy2 = subplot(1, 2, 2);
    pos2 = get(ax_dummy2, 'Position');
    delete(ax_dummy2); % 拿到位置后删除占位符

    % ==========================================================
    % 4. 绘制图表并执行"坐标轴转移"
    % ==========================================================
    fprintf('\n>> 正在生成 3D 图像并合并...\n');
    
    % --- 绘制左侧：系统 1 ---
    [temp_fig1, ax1] = plot_3D_zoom_overlay(g_opt_all1, sysParam1, 'on');
    set(ax1, 'Parent', fig, 'Position', pos1);
    
    % 视角设置
    view(ax1, view_az, view_el);
    
    % 强制清除子图可能存在的任何标题
    title(ax1, ''); 
    
    % 仅修改 Label 的文本内容，绝对保留底层函数设置好的字体、字号和粗细
    ax1.XLabel.String = 'X(mm)';
    ax1.YLabel.String = 'Y(mm)';
    ax1.ZLabel.String = 'Z(mm)';
    
    % 恢复显示坐标轴刻度数据（移除了隐藏 Ticks 的代码）
    
    if ishandle(temp_fig1) && temp_fig1 ~= fig
        close(temp_fig1); 
    end

    % --- 绘制右侧：系统 2 ---
    [temp_fig2, ax2] = plot_3D_zoom_overlay(g_opt_all2, sysParam2, 'on');
    set(ax2, 'Parent', fig, 'Position', pos2);
    
    % 视角设置
    view(ax2, view_az, view_el);
    
    % 强制清除子图可能存在的任何标题
    title(ax2, ''); 
    
    % 仅修改 Label 的文本内容，绝对保留底层函数设置好的字体、字号和粗细
    ax2.XLabel.String = 'X(mm)';
    ax2.YLabel.String = 'Y(mm)';
    ax2.ZLabel.String = 'Z(mm)';
    
    % 恢复显示坐标轴刻度数据（移除了隐藏 Ticks 的代码）
    
    if ishandle(temp_fig2) && temp_fig2 ~= fig
        close(temp_fig2); 
    end
    
    % 开启主图窗的 3D 交互旋转 (运行后你依然可以用鼠标直接拖拽查看)
    rotate3d(fig, 'on');
    
    fprintf('>> 绘图合并完成！\n');
end

% =========================================================================
% 内部子函数：加载和解析单个系统的逻辑
% =========================================================================
function [g_opt_all, sysParam] = load_and_parse_data(mat_file, current_dir, solution_idx)
    mat_path = i_resolve_mat_path(mat_file, current_dir);
    if ~exist(mat_path, 'file')
        error('未找到指定的 .mat 文件：\n%s', mat_path);
    end
    fprintf('>> 加载数据: %s\n', mat_path);
    data_in = load(mat_path);
    
    var_names = fieldnames(data_in);
    if ~(ismember('sysParam', var_names) && ismember('solutionData', var_names))
        error('文件中缺少 sysParam 或 solutionData，无法提取数据。');
    end
    sysParam = data_in.sysParam;
    solutionData = data_in.solutionData;
    
    if ~isfield(sysParam, 'N_pos') || isempty(sysParam.N_pos)
        error('sysParam.N_pos 不存在，无法还原多组态解矩阵。');
    end
    
    num_solutions = size(solutionData, 1);
    if solution_idx < 1 || solution_idx > num_solutions || solution_idx ~= floor(solution_idx)
        error('solution_idx 超出范围。该文件共有 %d 个解，要求的序号为 %d。', num_solutions, solution_idx);
    end
    
    [numParams, has_merit_col] = i_get_num_params(solutionData, sysParam.N_pos);
    row_data = solutionData(solution_idx, :);
    if has_merit_col
        row_data = row_data(1:end-1);
    end
    
    g_opt_all = zeros(sysParam.N_pos, numParams);
    for pos_idx = 1:sysParam.N_pos
        start_col = (pos_idx - 1) * numParams + 1;
        end_col = pos_idx * numParams;
        g_opt_all(pos_idx, :) = row_data(start_col:end_col);
    end
end

function mat_path = i_resolve_mat_path(mat_file, current_dir)
    if isstring(mat_file)
        mat_file = char(mat_file);
    end
    if ~ischar(mat_file)
        error('mat_file 必须是字符向量或字符串。');
    end
    if i_is_absolute_path(mat_file)
        mat_path = mat_file;
    else
        mat_path = fullfile(current_dir, mat_file);
    end
end

function tf = i_is_absolute_path(path_str)
    tf = false;
    if isempty(path_str)
        return;
    end
    if numel(path_str) >= 3 && path_str(2) == ':' && (path_str(3) == '\' || path_str(3) == '/')
        tf = true;
        return;
    end
    if strncmp(path_str, '\\', 2) || strncmp(path_str, '//', 2)
        tf = true;
    end
end

function [numParams, has_merit_col] = i_get_num_params(solutionData, N_pos)
    total_cols = size(solutionData, 2);
    if mod(total_cols - 1, N_pos) == 0
        numParams = (total_cols - 1) / N_pos;
        has_merit_col = true;
        return;
    end
    if mod(total_cols, N_pos) == 0
        numParams = total_cols / N_pos;
        has_merit_col = false;
        return;
    end
    error('solutionData 列数与 sysParam.N_pos 不匹配，无法解析每个组态的参数数目。');
end