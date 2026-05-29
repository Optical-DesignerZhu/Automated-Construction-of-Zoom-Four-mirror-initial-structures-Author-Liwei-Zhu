function test_coder_trace()
    % 这是一个专门用于 MATLAB Coder 定义输入类型的极简测试脚本
    % 仅用于为 trace_single_config_offaxis 提供合法的尺寸和类型声明
    
    % 1. 伪造结构参数 r (必须是 17 维的 double 数组，包含 R, d, alpha, K)
    % 给一些非 0 的安全数据防止底层除以 0 报错
    R_dummy = [1000, -1000, 1000, -1000];
    d_dummy = [100, 100, 100, 100, 50];
    alpha_dummy = [10, -10, 10, -10];
    K_dummy = [0, 0, 0, 0];
    r_dummy = [R_dummy, d_dummy, alpha_dummy, K_dummy]; % 1x17 double
    
    % 2. 伪造入瞳直径 EPD (标量)
    epd_dummy = 60.0;
    
    % 3. 伪造视场角数组 (必须至少有 3 个视场，因为 build_point_data 需要提取第 1 和第 3 个)
    fieldAnglesDeg_dummy = [0, 1, -1]; 
    
    % 4. 伪造光阑位置 (标量)
    stopPos_dummy = 5; 
    
    % 5. 强行调用目标函数触发类型推断
    res = trace_single_config_offaxis(r_dummy, epd_dummy, fieldAnglesDeg_dummy, stopPos_dummy);
end