function initialSys(cv, sysParam, isZoom)
% initialSys - 初始化CODE V光学系统基础结构 (支持任意 N 组态连续变焦版)
%
% 输入参数:
%   cv      - CODE V 的 COM 接口对象
%   sysParam- 系统参数结构体
%   isZoom  - 是否输入变焦参数 (可选参数，1为变焦，0为定焦。默认为 0)

    % 如果调用时没有提供 isZoom 参数，则默认设置为 0 (定焦)
    if nargin < 3
        isZoom = 0; 
    end
    
    SType = sysParam.surfaceType;
    SMposition = sysParam.stopPosition;
    
    % ================= 提取组态数量与组态 1 (短焦) 参数 =================
    if isfield(sysParam, 'N_pos') && isfield(sysParam, 'pos')
        N_pos = sysParam.N_pos;
        EPD_pos1  = sysParam.pos(1).epd;
        HFOV_pos1 = sysParam.pos(1).hfov;
    else
        N_pos = 2; % 兼容旧版双组态
        EPD_pos1  = sysParam.pos1.epd;
        HFOV_pos1 = sysParam.pos1.hfov;
    end
    
    % 1. 基础参数初始化命令 (无论定焦还是变焦都需要的基础搭建，针对组态 1)
    baseCommandStr = sprintf(['Len New; INS S2..4; dim m; INS S1; FVR N; THI S1 400; ' ...
        'RMD S2 REFL; RMD S3 REFL; RMD S4 REFL; RMD S5 REFL; ' ...
        ' BEN S2; BEN S3; BEN S4; BEN S5; ' ...
        'epd %g; INS F2..3; YAN F1 %g; YAN F2 0; YAN F3 %g'], ...
        EPD_pos1, -HFOV_pos1, HFOV_pos1);
        
    cv.Command(baseCommandStr);
    
    % 2. 变焦参数设定 (根据 isZoom 决定是否追加 N 组态的变焦指令)
    if isZoom == 1
        % 先声明哪些变量是允许随变焦改变的 (只需要全局声明一次)
        zoomDefineStr =sprintf(['INS Z1..%g; ZOO EPD; in CV_MACRO:cvzoomfield ZOO Y F1; in CV_MACRO:cvzoomfield ZOO Y F2; in CV_MACRO:cvzoomfield ZOO Y F3; ' ...
            'ZOO THI S2; ZOO THI S3; ZOO THI S4; ZOO THI S5; ' ...
            'ZOO ADE S2; ZOO ADE S3; ZOO ADE S4; ZOO ADE S5;'],N_pos-1);
        cv.Command(zoomDefineStr);
        
        % 循环追加后续组态 (从 Z2 一直加到 Z_N)
        for i = 2:N_pos
            if isfield(sysParam, 'pos')
                EPD_pos_i  = sysParam.pos(i).epd;
                HFOV_pos_i = sysParam.pos(i).hfov;
            else
                EPD_pos_i  = sysParam.pos2.epd;  % 兼容旧版双组态
                HFOV_pos_i = sysParam.pos2.hfov;
            end
            
            % 动态插入第 i 个组态，并赋对应组态的 EPD 和 YAN 值 (修复了参数对不齐的Bug)
            zoomPosStr = sprintf('epd Z%d %g; YAN Z%d F1 %g; YAN Z%d F2 0; YAN Z%d F3 %g', ...
                 i, EPD_pos_i, i, -HFOV_pos_i, i, i, HFOV_pos_i);
            cv.Command(zoomPosStr);
        end
    end
    
    % 3. 追加表面面型定义
    if strcmpi(SType, 'CON')
        surCommandStr = sprintf('CON S2; CON S3; CON S4; CON S5');
        cv.Command(surCommandStr);
    end
    
    % ================= 【处理光阑 0~5 的通用映射逻辑】 =================
    if SMposition == 5
        % 若为5 (实出瞳)，则在M4(S5)后新插入一面S6，并将S6设为光阑 (原像面顺延)
        % 🌟 这里 THI S6 对应的正是“光阑到像面”的距离，使用我们新定义的变量
        ColdAperCommandStr =  sprintf('INS S6; STO S6; THI S6 %g', sysParam.stopToImage);
        cv.Command(ColdAperCommandStr);
    else
        % 否则按常规设定将现有面设为光阑 (SMposition 0~4 分别对应 S1~S5)
        stopCommandStr = sprintf('STO S%d', SMposition + 1);
        cv.Command(stopCommandStr);
    end
    % =========================================================

end