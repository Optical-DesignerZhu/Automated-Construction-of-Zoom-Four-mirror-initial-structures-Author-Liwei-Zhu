function printZoomSystemParameters(g_opt_all, fitness, sysParam)
% printZoomSystemParameters - 打印离轴四反系统最终优化参数 (N组态动态扩展对齐版)
% 
% 输入参数：
%   g_opt_all - N x 13 或 N x 17 的连续变焦最终优化结果矩阵
%   fitness   - 最终适应度值 (Merit Function)
%   sysParam  - 系统结构体参数

    %% 1. 提取基础信息
    N_pos = size(g_opt_all, 1);
    num_dims = size(g_opt_all, 2); % 获取当前矩阵维度
    
    R_pos1 = g_opt_all(1, 1:4); % 表面曲率在变焦中保持不变
    
    % 如果是 17 维，提取圆锥系数 (同样保持不变)
    if num_dims >= 17
        K_pos1 = g_opt_all(1, 14:17);
    else
        K_pos1 = [];
    end
    
    %% 2. 判定系统架构模式
    if isfield(sysParam, 'stopPosition')
        stopPos = sysParam.stopPosition;
    else
        stopPos = 0;
    end
    
    % 手动计算显示宽度，确保所有的前缀恰好占据 17 个英文字符的空间
    if stopPos == 5
        stopStr = '冷阑后置 (实出瞳)';
        var5_name = ' d5 (Stop->Img)  '; % 🌟 修复：改为明确的 d5 (Stop->Img)
    elseif stopPos >= 1 && stopPos <= 4
        stopStr = sprintf('光阑放置于反射镜 M%d 上', stopPos);
        var5_name = ' d0 (虚拟->M1)   '; 
    else
        stopStr = '光阑前置 (独立虚拟面)';
        var5_name = ' d0 (光阑->M1)   '; 
    end
    
    if isfield(sysParam, 'move') && sysParam.move == 1
        moveStr = '动像模式 (M4固定，像面移动)';
    else
        moveStr = '稳像模式 (像面绝对固定)';
    end
    
    %% 3. 动态构建对齐边界与动态表头
    % 每多一个组态，表格就向右延伸 17 个字符宽度
    base_width = 18; 
    col_width = 17;
    total_width = base_width + N_pos * col_width;
    
    eqStr      = repmat('=', 1, total_width);
    dividerStr = repmat('-', 1, total_width);
    
    % 动态计算标题居中所需的空格数 (标题占 36 个字符宽)
    titleSpaces = repmat(' ', 1, max(0, floor((total_width - 36) / 2)));
    
    % 动态拼接表头 (区分短焦、中焦、长焦)
    headerStr = '                 |';
    for i = 1:N_pos
        % 1. 动态生成后缀标签 (保证视觉宽度绝对等于 7)
        if i == 1
            tag = '(短焦) '; 
        elseif i == N_pos
            tag = '(长焦) ';
        else
            if N_pos > 3
                tag = sprintf('(中焦%d)', i - 1); % 例如: (中焦1), (中焦2)
            else
                tag = '(中焦) ';
            end
        end
        
        % 2. 拼接时保证严格的 17 字符宽度对齐 (兼容 10 个以上的组态)
        if i < 10
            headerStr = [headerStr, sprintf(' 组态 %d %s |', i, tag)]; % 单位数，前面留空格
        else
            headerStr = [headerStr, sprintf(' 组态%d %s |', i, tag)];  % 双位数，挤占掉一个空格
        end
    end
    
    %% 4. 控制台精美对齐打印
    fprintf('\n%s\n', eqStr);
    fprintf('%s【离轴四反变焦系统最终优化结果报告】\n', titleSpaces);
    fprintf('%s\n', eqStr);
    
    fprintf('[ 系统架构配置 ]\n');
    fprintf(' - 变焦模式: %s\n', moveStr);
    fprintf(' - 光阑位置: %s\n', stopStr);
    fprintf(' - 采样组态: %d 个点连续变焦\n', N_pos);
    fprintf(' - 最终适应度 (Merit Function): %.6f\n\n', fitness);
    
    % ----------------- 打印光学指标 -----------------
    fprintf('[ 理想光学指标 ]\n');
    fprintf('%s\n', headerStr);
    fprintf('%s\n', dividerStr);
    
    fprintf(' 焦距 (EFL)      |');
    for i=1:N_pos, fprintf(' %-14.2f |', sysParam.pos(i).f); end
    fprintf('\n F / #           |');
    for i=1:N_pos, fprintf(' %-14.2f |', sysParam.pos(i).F_number); end
    fprintf('\n 半视场 (HFOV)   |');
    for i=1:N_pos, fprintf(' %-14.3f |', sysParam.pos(i).hfov); end
    fprintf('\n 入瞳直径 (EPD)  |');
    for i=1:N_pos, fprintf(' %-14.2f |', sysParam.pos(i).epd); end
    fprintf('\n\n');
    
    % ----------------- 打印曲率半径 -----------------
    fprintf('[ 表面曲率半径 (R) ] (变焦过程保持不变)\n');
    fprintf('%s\n', dividerStr);
    fprintf(' M1 (主镜)       | %-14.4f\n', R_pos1(1));
    fprintf(' M2 (次镜)       | %-14.4f\n', R_pos1(2));
    fprintf(' M3 (三镜)       | %-14.4f\n', R_pos1(3));
    fprintf(' M4 (四镜)       | %-14.4f\n\n', R_pos1(4));
    
    % ----------------- 打印圆锥系数 -----------------
    if ~isempty(K_pos1)
        fprintf('[ 表面圆锥系数 (K) ] (变焦过程保持不变)\n');
        fprintf('%s\n', dividerStr);
        fprintf(' K1 (主镜)       | %-14.6f\n', K_pos1(1));
        fprintf(' K2 (次镜)       | %-14.6f\n', K_pos1(2));
        fprintf(' K3 (三镜)       | %-14.6f\n', K_pos1(3));
        fprintf(' K4 (四镜)       | %-14.6f\n\n', K_pos1(4));
    end
    
    % ----------------- 打印厚度间隔 -----------------
    fprintf('[ 镜面中心间隔 (Thickness / d) ]\n');
    fprintf('%s\n', headerStr);
    fprintf('%s\n', dividerStr);
    
    fprintf('%s|', var5_name);
    for i=1:N_pos, fprintf(' %-14.4f |', g_opt_all(i, 5)); end
    fprintf('\n');
    
    d_labels = {' d1 (M1->M2)     ', ' d2 (M2->M3)     ', ' d3 (M3->M4)     ', ' d4 (M4->Image)  '};
    for k = 1:4
        fprintf('%s|', d_labels{k});
        for i=1:N_pos, fprintf(' %-14.4f |', g_opt_all(i, 5+k)); end
        fprintf('\n');
    end
    fprintf('\n');
    
    % ----------------- 打印偏转倾角 -----------------
    fprintf('[ 表面偏转倾角 (Alpha) ]\n');
    fprintf('%s\n', headerStr);
    fprintf('%s\n', dividerStr);
    
    a_labels = {' Alpha 1 (M1)    ', ' Alpha 2 (M2)    ', ' Alpha 3 (M3)    ', ' Alpha 4 (M4)    '};
    for k = 1:4
        fprintf('%s|', a_labels{k});
        for i=1:N_pos, fprintf(' %-14.4f |', g_opt_all(i, 9+k)); end
        fprintf('\n');
    end
    fprintf('%s\n\n', eqStr);
end