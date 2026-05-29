function [fig, ax, g_opt_all, sysParam] = Plot_Selected_Solution_3D(solution_idx)
% Plot_Selected_Solution_3D
% 在函数内部指定 .mat 文件路径，读取指定序号的 3D 光学系统解并绘图。
%
% 用法示例:
%   Plot_Selected_Solution_3D(1);
%
% 输入:
%   solution_idx  - 指定绘制第几个解（solutionData 的第几行）
%
% 输出:
%   fig           - 图窗句柄
%   ax            - 坐标轴句柄
%   g_opt_all     - 还原后的多组态解矩阵
%   sysParam      - 数据中的系统参数结构体

    if nargin < 1 || isempty(solution_idx)
        solution_idx = 1;
    end

    % 在这里直接指定要读取的 .mat 文件
    mat_file = "D:\OneDrive\PhD\Other\UndergraduateThesis_LinJvnPeng\DataResult\Batch_AZFM_Results_withvolWeight\stop_back\stopDistance40\StopRear_F3_HFOV1_Wvol0.04\Full_Data.mat";
    current_dir = fileparts(mfilename('fullpath'));
    mat_path = i_resolve_mat_path(mat_file, current_dir);

    if ~exist(mat_path, 'file')
        error('未找到指定的 .mat 文件：\n%s', mat_path);
    end

    fprintf('>> 正在加载数据: %s\n', mat_path);
    data_in = load(mat_path);
    var_names = fieldnames(data_in);

    if ~(ismember('sysParam', var_names) && ismember('solutionData', var_names))
        error('文件中缺少 sysParam 或 solutionData，无法绘制 3D 图。');
    end

    sysParam = data_in.sysParam;
    solutionData = data_in.solutionData;

    if ~isfield(sysParam, 'N_pos') || isempty(sysParam.N_pos)
        error('sysParam.N_pos 不存在，无法还原多组态解矩阵。');
    end

    num_solutions = size(solutionData, 1);
    if solution_idx < 1 || solution_idx > num_solutions || solution_idx ~= floor(solution_idx)
        error('solution_idx 超出范围。当前共有 %d 个解，要求的序号为 %d。', num_solutions, solution_idx);
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

    fprintf('>> 数据加载完成，共检测到 %d 个解；当前绘制第 %d 个解。\n', num_solutions, solution_idx);
    [fig, ax] = plot_3D_zoom_overlay(g_opt_all, sysParam, 'on');
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
