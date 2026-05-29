function cv = cvon_inter(PID)
    cvloc = actxserver('CVLocator.Locator');  % Interactive COM
    cv = cvloc.GetCVAPI(PID);                 % Interactive COM
    
    % 如果 interactive COM 连接失败 (UIpid=0 或无效)，要求用户输入 UIpid
    while isempty(cv)  
        prompt = {['Hint: type in "eva (pid UI)" in the command window of the running CODE V session.' newline 'Enter UIpid:']};
        dlgtitle = 'Input UIpid';
        answers = inputdlg(prompt, dlgtitle);
        
        % 增加鲁棒性：如果用户点击了"取消"或关闭了对话框，安全退出
        if isempty(answers)
            disp('Connection cancelled by user.');
            return;
        end
        
        UIpid = str2double(answers{1});
        cv = cvloc.GetCVAPI(UIpid);           % 再次尝试连接 Interactive COM
    end
    
    % === 逻辑反转：默认尝试开启，报错则跳过 ===
    try
        cv.StartCodeV; 
        disp('CODE V engine has been started successfully.');
        
    catch ME
        % 捕获到错误，说明 CODE V 很可能已经处于交互模式的运行状态
        % 在 API 手册中，重复启动通常会返回 FACILITY_ITF 错误
        disp('StartCodeV skipped: CODE V session is likely already active.');
        % 可选：打印一下预期内捕获的错误信息，方便调试时查看
        % disp(['(Expected error caught: ', ME.message, ')']);
        
        % 稳妥起见，既然没法通过 StartCodeV 启动，那就用 EvaluateExpression 确认一下进程是否真的存活
        try
            current_pid = cv.EvaluateExpression("(pid ui)"); 
            disp(['Verified active interactive connection. PID UI: ', current_pid]);
        catch ME_verify
            warning('CODE V is not responding to commands. The COM handle might be completely dead.');
            disp(['Error Details: ', ME_verify.message]);
        end
    end
end