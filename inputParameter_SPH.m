function [] = inputParameter_SPH(cv, r, sysParam, posName)
% inputParameter_SPH - 向 CODE V 输入球面系统的结构参数 (纯净版)
% 变量统一为 13 维: [R1~R4(1:4), r5(5), d1~d4(6:9), alpha1~alpha4(10:13)]

    if nargin < 3 || isempty(sysParam)
        writePupilField = false;
        stopPos = 0; 
    else
        writePupilField = true;
        if nargin < 4, posName = 'pos1'; end
        
        if isfield(sysParam, 'stopPosition')
            stopPos = sysParam.stopPosition;
        else
            stopPos = 0;
        end
    end
    
    r = r(:)'; 
    if numel(r) < 13
        error('输入矩阵 r 必须严格包含 13 维基础变量。');
    end
    
    R1 = r(1);  R2 = r(2);  R3 = r(3);  R4 = r(4);
    r5 = r(5);  
    d1 = r(6);  d2 = r(7);  d3 = r(8);  d4 = r(9);
    a1 = r(10); a2 = r(11); a3 = r(12); a4 = r(13);
    
    if stopPos == 5
        commandStr = sprintf(['RDY S2 %g; RDY S3 %g; RDY S4 %g; RDY S5 %g; ' ...
                              'THI S1 400; THI S2 %g; THI S3 %g; THI S4 %g; THI S5 %g; THI S6 %g; ' ...
                              'ADE S2 %g; ADE S3 %g; ADE S4 %g; ADE S5 %g;'], ...
                              R1, R2, R3, R4, ...               
                              d1, d2, d3, d4 - r5, r5, ...  
                              a1, a2, a3, a4);              
    else
        commandStr = sprintf(['RDY S2 %g; RDY S3 %g; RDY S4 %g; RDY S5 %g; ' ...
                              'THI S1 %g; THI S2 %g; THI S3 %g; THI S4 %g; THI S5 %g; ' ...
                              'ADE S2 %g; ADE S3 %g; ADE S4 %g; ADE S5 %g;'], ...
                              R1, R2, R3, R4, ...               
                              r5, d1, d2, d3, d4, ...         
                              a1, a2, a3, a4);              
    end
                           
    if writePupilField
        % 智能提取后缀数字，例如 'pos3' -> 提取出 3
        idxStr = regexp(posName, '\d+', 'match');
        if ~isempty(idxStr)
            idx = str2double(idxStr{1});
        else
            idx = 1;
        end
        
        % 直接从新的结构体数组 sysParam.pos(i) 中取值
        EPD  = sysParam.pos(idx).epd;
        HFOV = sysParam.pos(idx).hfov;
        
        addonStr = sprintf(' EPD %g; YAN F1 %g; YAN F2 0; YAN F3 %g;', EPD, -HFOV, HFOV);
        commandStr = [commandStr, addonStr];
    end
                           
    cv.Command(commandStr);
end