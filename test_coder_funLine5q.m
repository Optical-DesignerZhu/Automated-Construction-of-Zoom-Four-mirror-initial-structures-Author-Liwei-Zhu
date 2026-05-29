function test_coder_funLine5q()
    % 这是一个专门用于 MATLAB Coder 定义输入类型的极简脚本
    
    % 1. 伪造 tr 结构体 (尺寸和类型必须和真实情况一致)
    tr = struct();
    tr.P_S = zeros(48, 1);    % funLine5q 需要 6 个面，6*8 = 48 个点
    tr.R = [100, 200, 300, 400];
    tr.K_conic = [0, 0, 0, 0];
    tr.O = zeros(4, 2);
    tr.NX = zeros(4, 2);
    tr.NY = zeros(4, 2);
    
    % 2. 伪造 D_max
    D_max = [20, 20, 20, 20];
    
    % 3. 伪造 stopPos
    stopPos = 1;
    
    % 4. 强行调用目标函数！
    f = funLine5q(tr, D_max, stopPos);
end