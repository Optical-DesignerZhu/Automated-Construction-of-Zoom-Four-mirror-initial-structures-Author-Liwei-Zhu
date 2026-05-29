function [] = inputRData(cv, r, sysParam)
% inputRData - 向 CODE V 输入系统的参数 (支持任意 N 组态，支持自适应球面/圆锥面)
%
% 调用形式:
%   1. 包含系统参数: inputRData(cv, r, sysParam) -> 支持判断光阑位置
%   2. 不含系统参数: inputRData(cv, r)           -> 默认按常规架构执行
%
% 变量维度定义:
%   r 矩阵必须包含 13 或 17 维列，行数为 N (N >= 1):
%   常规球面 (13维): [R1~R4(1:4), d0(5), d1~d4(6:9), a1~a4(10:13)]
%   圆锥面   (17维): [R1~R4(1:4), d0(5), d1~d4(6:9), a1~a4(10:13), K1~K4(14:17)]
    
    % ================= 0. 判断是否为光阑后置 (stopPosition == 5) =================
    if nargin < 3 || isempty(sysParam)
        isStop5 = false;
    else
        if isfield(sysParam, 'stopPosition') && sysParam.stopPosition == 5
            isStop5 = true;
        else
            isStop5 = false;
        end
    end
    
    % ================= 1. 解析输入参数矩阵 =================
    N_pos = size(r, 1); % 动态获取需要输入多少个组态
    numCols = size(r, 2);
    
    if numCols < 13
        error('输入矩阵 r 的列数不足！必须至少包含 13 维基础变量。');
    end
    
    if N_pos < 1
        error('输入矩阵 r 不能为空！');
    end
    
    hasConic = (numCols >= 17); % 判断是否携带圆锥系数
    
    % ================= 2. 输入基础 / 变焦位置 1 参数 =================
    r1 = r(1, :);
    
    if isStop5
        % === 光阑后置架构 (S6 为实出瞳光阑) ===
        commandStr1 = sprintf(['RDY S2 %g; RDY S3 %g; RDY S4 %g; RDY S5 %g; ' ...
                               'THI S1 400; THI S2 %g; THI S3 %g; THI S4 %g; THI S5 %g; THI S6 %g; ' ...
                               'ADE S2 %g; ADE S3 %g; ADE S4 %g; ADE S5 %g;'], ...
                               r1(1), r1(2), r1(3), r1(4), ...               % 曲率半径 (R1~R4)
                               r1(6), r1(7), r1(8), r1(9) - r1(5), r1(5), ...% 厚度 (d1, d2, d3, d4-dex, dex)
                               r1(10), r1(11), r1(12), r1(13));              % 倾斜角度 (a1~a4)
    else
        % === 常规架构 (0~4 独立光阑或面上光阑) ===
        commandStr1 = sprintf(['RDY S2 %g; RDY S3 %g; RDY S4 %g; RDY S5 %g; ' ...
                               'THI S1 %g; THI S2 %g; THI S3 %g; THI S4 %g; THI S5 %g; ' ...
                               'ADE S2 %g; ADE S3 %g; ADE S4 %g; ADE S5 %g;'], ...
                               r1(1), r1(2), r1(3), r1(4), ...                 % 曲率半径 (R1~R4)
                               r1(5), r1(6), r1(7), r1(8), r1(9), ...          % 厚度参数 (r5, d1~d4)
                               r1(10), r1(11), r1(12), r1(13));                % 倾斜角度 (a1~a4)
    end
    
    % 🌟 核心修复：如果是 17 维矩阵，追加输入圆锥系数 (CODE V 指令为 K)
    if hasConic
        conicStr = sprintf(' K S2 %g; K S3 %g; K S4 %g; K S5 %g;', r1(14), r1(15), r1(16), r1(17));
        commandStr1 = [commandStr1, conicStr];
    end
                           
    % 一次性执行组态 1 (全局基准) 的命令
    cv.Command(commandStr1);
    
    % ================= 3. 循环输入变焦组态 2 ~ N 参数 =================
    if N_pos > 1
        for i = 2:N_pos
            ri = r(i, :); % 提取第 i 个组态的参数
            
            % 变焦过程中，曲率半径和圆锥系数保持不变，只需更新厚度和角度
            if isStop5
                commandStri = sprintf(['THI S2 Z%d %g; THI S3 Z%d %g; THI S4 Z%d %g; THI S5 Z%d %g;  ' ...
                                       'ADE S2 Z%d %g; ADE S3 Z%d %g; ADE S4 Z%d %g; ADE S5 Z%d %g;'], ...
                                       i, ri(6), i, ri(7), i, ri(8), i, ri(9) - ri(5), ... 
                                       i, ri(10), i, ri(11), i, ri(12), i, ri(13));        
            else
                commandStri = sprintf(['THI S1 Z%d %g; THI S2 Z%d %g; THI S3 Z%d %g; THI S4 Z%d %g; THI S5 Z%d %g; ' ...
                                       'ADE S2 Z%d %g; ADE S3 Z%d %g; ADE S4 Z%d %g; ADE S5 Z%d %g;'], ...
                                       i, ri(5), i, ri(6), i, ri(7), i, ri(8), i, ri(9), ... 
                                       i, ri(10), i, ri(11), i, ri(12), i, ri(13));          
            end
                                   
            cv.Command(commandStri);
        end
    end
    
end