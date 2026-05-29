% 获取当前目录路径
currentDir = pwd;

% 构建文件搜索模式
filePattern = fullfile(currentDir, '*.plt');

% 获取匹配模式的文件列表
fileList = dir(filePattern);

% 循环遍历并删除每个文件
for i = 1:numel(fileList)
    fileName = fileList(i).name;
    filePath = fullfile(currentDir, fileName);
    
    % 删除文件
    delete(filePath);
    
    disp(['Deleted: ' fileName]);
end