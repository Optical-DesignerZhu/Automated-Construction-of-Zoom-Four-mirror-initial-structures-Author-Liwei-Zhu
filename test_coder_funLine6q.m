function test_coder_funLine6q()
    % 这是一个专门用于 MATLAB Coder 定义输入类型的极简脚本
    
    tr = struct();
    tr.P_S = zeros(56, 1);    % funLine6q 需要 7 个面，7*8 = 56 个点
    tr.R = [100, 200, 300, 400];
    tr.K_conic = [0, 0, 0, 0];
    tr.O = zeros(4, 2);
    tr.NX = zeros(4, 2);
    tr.NY = zeros(4, 2);
    
    D_max = [20, 20, 20, 20];
    stopPos = 5;
    
    f = funLine6q(tr, D_max, stopPos);
end