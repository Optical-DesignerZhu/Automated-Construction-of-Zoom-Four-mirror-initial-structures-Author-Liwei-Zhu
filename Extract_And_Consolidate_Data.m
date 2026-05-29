%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%*****Description : Data Extraction, Analytics and Consolidation
%*****Author : Lei Yang & Assistant
%*****Date : May. 1, 2026
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear; clc;

%% 1. 用户配置区
% =========================================================================
% 请将此处修改为你实际跑出来的【大文件夹】的名称或绝对路径
master_dir ="D:\OneDrive\PhD\Other\UndergraduateThesis_LinJvnPeng\Code\testdata\Batch_AZFM_Results_20260503_115240"; 
% =========================================================================

% 定义提取后统一存放的文件夹名称
target_dir = fullfile(master_dir, 'Consolidated_Data');
if ~exist(target_dir, 'dir')
    mkdir(target_dir);
end

fprintf('\n>>> 🗂️ 开始数据提取、智能解析与聚合任务...\n');
fprintf('>>> 正在扫描大目录: %s\n', master_dir);

%% 2. 递归获取所有 .mat 文件
all_mat_files = dir(fullfile(master_dir, '**', '*.mat'));

if isempty(all_mat_files)
    error('未在指定目录下找到任何 .mat 文件，请检查路径！');
end

MasterData = struct();
valid_count = 0;

%% 3. 遍历提取与校验
for i = 1:length(all_mat_files)
    
    current_folder = all_mat_files(i).folder;
    current_name   = all_mat_files(i).name;
    full_path      = fullfile(current_folder, current_name);
    
    % 跳过汇总表文件和已经被存入目标文件夹的文件
    if contains(current_folder, 'Consolidated_Data') || contains(current_name, 'Summary')
        continue;
    end
    
    % 加载数据
    data_in = load(full_path);
    var_names = fieldnames(data_in);
    
    %% 4. 数据严格校验
    if ~(ismember('sysParam', var_names) && ismember('solutionData', var_names))
        warning('【文件不合规】跳过 "%s"：缺失 sysParam 或 solutionData。', current_name);
        continue;
    end
    
    sysParam = data_in.sysParam;
    solutionData = data_in.solutionData;
    
    %% 5. 提取物理参数与变倍比
    try
        % 提取光阑位置
        str_stop = 'StopFront';
        if sysParam.stopPosition == 5, str_stop = 'StopRear'; end
        
        % 提取 F数 和 视场角
        F_num = sysParam.pos(1).F_number;
        hfov  = sysParam.pos(1).hfov;
        
        % 计算变倍比 Zoom Ratio (长焦 / 短焦)
        f_array = [sysParam.pos.f];
        zoom_ratio = max(abs(f_array)) / min(abs(f_array));
        
    catch ME
        warning('【参数解析失败】跳过 "%s"：sysParam 内部结构不完整。', current_name);
        continue;
    end
    
    %% 6. 数据深度处理：评估评价函数与体积
    % 提取所有 Run 的最终评价函数值 (最后一列)
    fitness_all = solutionData(:, end);
    avg_fitness = mean(fitness_all);
    [best_fitness, best_idx] = min(fitness_all);
    
    % 还原每一行的结构并计算体积
    numParams = (size(solutionData, 2) - 1) / sysParam.N_pos;
    num_rows = size(solutionData, 1);
    vol_all = zeros(num_rows, 1);
    
    try
        for r = 1:num_rows
            row_data = solutionData(r, 1:end-1);
            g_opt_all = zeros(sysParam.N_pos, numParams);
            % 重新将一维数组折叠回多组态矩阵
            for pos_idx = 1:sysParam.N_pos
                start_col = (pos_idx - 1) * numParams + 1;
                end_col   = pos_idx * numParams;
                g_opt_all(pos_idx, :) = row_data(start_col:end_col);
            end
            
            % 调用评价函数计算物理指标 (需要 calc_MeritFunction 在工作目录中)
            [~, ~, ~, vol_unit] = calc_MeritFunction(g_opt_all, sysParam);
            vol_all(r) = vol_unit * 1e6; % 转换为 mm^3
        end
        avg_vol = mean(vol_all);
        best_vol = vol_all(best_idx); % 适应度最好的一组对应的体积
    catch ME
        warning('【体积计算失败】在处理 %s 时出错，请确保 calc_MeritFunction.m 存在。', current_name);
        avg_vol = NaN;
        best_vol = NaN;
    end
    
    %% 7. 动态命名与防覆盖
    % 命名格式加入变倍比 (例如: OptRes_StopRear_F5_HFOV3_Z3.5X)
    base_new_name = sprintf('OptRes_%s_F%g_HFOV%g_Z%.1fX', str_stop, F_num, hfov, zoom_ratio);
    
    new_name = base_new_name;
    suffix_idx = 1;
    while exist(fullfile(target_dir, [new_name, '.mat']), 'file')
        new_name = sprintf('%s_V%d', base_new_name, suffix_idx);
        suffix_idx = suffix_idx + 1;
    end
    
    %% 8. 保存与记录
    % 拷贝一份标准重命名文件过去
    target_path = fullfile(target_dir, [new_name, '.mat']);
    save(target_path, 'sysParam', 'solutionData');
    
    % 录入 MasterData 数据湖
    valid_count = valid_count + 1;
    MasterData(valid_count).OriginalFile = current_name;
    MasterData(valid_count).NewName      = new_name;
    MasterData(valid_count).StopPos      = sysParam.stopPosition;
    MasterData(valid_count).F_number     = F_num;
    MasterData(valid_count).HFOV         = hfov;
    MasterData(valid_count).ZoomRatio    = zoom_ratio;
    MasterData(valid_count).Avg_Fitness  = avg_fitness;
    MasterData(valid_count).Best_Fitness = best_fitness;
    MasterData(valid_count).Avg_Volume   = avg_vol;
    MasterData(valid_count).Best_Volume  = best_vol;
    MasterData(valid_count).sysParam     = sysParam;
    MasterData(valid_count).solutionData = solutionData;
    
    fprintf('✅ 成功提取: %s\n   -> 平均误差: %.2f | 平均体积: %.1f mm³\n', [new_name, '.mat'], avg_fitness, avg_vol);
end

%% 9. 导出终极数据包与 Excel 汇总分析表
if valid_count > 0
    master_file_path = fullfile(target_dir, '00_Master_Dataset.mat');
    save(master_file_path, 'MasterData');
    
    % 将最核心的评估数据导出为 Excel，方便直接写论文作图
    SummaryTable = table({MasterData.NewName}', [MasterData.ZoomRatio]', [MasterData.Avg_Fitness]', [MasterData.Best_Fitness]', [MasterData.Avg_Volume]', [MasterData.Best_Volume]', ...
        'VariableNames', {'FileName', 'ZoomRatio', 'Avg_Fitness', 'Best_Fitness', 'Avg_Volume_mm3', 'Best_Volume_mm3'});
    writetable(SummaryTable, fullfile(target_dir, '00_Consolidated_Summary.xlsx'));
    
    fprintf('\n🎉 数据聚合完成！共成功处理 %d 个有效文件。\n', valid_count);
    fprintf('👉 独立文件存放至: %s\n', target_dir);
    fprintf('👉 终极聚合包: 00_Master_Dataset.mat (包含所有系统配置与光路解)\n');
    fprintf('👉 Excel 统计表: 00_Consolidated_Summary.xlsx (包含各项平均评估指标)\n');
else
    fprintf('\n⚠️ 未提取到任何有效数据，请检查输入的大文件夹路径是否正确。\n');
end