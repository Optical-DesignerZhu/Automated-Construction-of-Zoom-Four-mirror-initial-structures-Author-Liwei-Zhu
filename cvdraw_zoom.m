function cvdraw_zoom(cv, sysParam)
% cvdraw_zoom - 动态绘制 N 组态连续变焦系统的光路图 (纯净版)
% 强制依赖 sysParam.N_pos，自动补全 SSI Z_i 0 缩放、RET 叠加属性与多组态颜色

    % ================= 1. 获取变焦组态数量 =================
    % 取消兼容模式，直接读取系统参数
    N_pos = sysParam.N_pos;
    
    % ================= 2. 初始化绘图命令 =================
    filename = ['view_' datestr(now,'yyyymmdd_HHMMSS') '.plt'];
    cv.Command(char("GRA " + filename));
    
    % 动态生成 RET 命令: N_pos 个组态对应 (N_pos-1) 个 Y 和 1 个 N
    retCmd = 'RET ';
    for k = 1:(N_pos - 1)
        retCmd = [retCmd, 'Y '];
    end
    retCmd = [retCmd, 'N']; % 例如 3组态生成 'RET Y Y N'
    
    % 根据您的架构：先用 Z1 设定基准缩放，然后赋予动态生成的 RET 叠加模式
    viewCmd = sprintf('VIE; SSI Z1 0; OFS S1 OVE 0 0 0; %s; ', retCmd);
    
    % ================= 3. 动态拼接其他组态的缩放指令 =================
    % 遍历所有组态，跳过已经写在前面的 Z1
    for i = 1:N_pos
        if i ~= 1
            viewCmd = [viewCmd, sprintf('SSI Z%d 0; ', i)];
        end
    end
    
    % ================= 4. 动态拼接光线颜色指令 =================
    % 按照您的示例顺序：1红、2蓝、3黄，后面补充绿、紫、青、黑
    colorList = {'RED', 'BLU', 'YEL', 'GRE', 'MAG', 'CYA', 'BLK'};
    
    for i = 1:N_pos
        % 使用 mod 防止组态数超过颜色数时数组越界
        colorIdx = mod(i - 1, length(colorList)) + 1; 
        
        % 动态拼接: FLD FA Z1 RED; FLD FA Z2 BLU; ...
        viewCmd = [viewCmd, sprintf('FLD FA Z%d %s; ', i, colorList{colorIdx})];
    end
    
    % 拼上结尾的运行命令
    viewCmd = [viewCmd, 'GO;'];
    
    % ================= 5. 执行 CODE V 绘图宏 =================
    cv.Command(viewCmd);
    
    try
        cvcmd('GRA T');
        cvcmd(['GCV PNG '  filename]);
    catch
        cv.Command('GRA T');
        cv.Command(['GCV PNG '  filename]);
    end
    
    pause(0.1);
    
    % winopen([ cvpath '\graphics\' filename]);
    % delete(['C:\CVUSER\' filename]);
end