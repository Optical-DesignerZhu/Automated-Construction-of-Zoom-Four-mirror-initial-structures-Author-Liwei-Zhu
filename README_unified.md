# 统一优化算法使用说明

## 概述

我已经成功将原来分离的保存图片和不保存图片的算法函数合并为统一的函数。现在只需要一个函数就能处理两种情况，大大简化了代码结构。

## 新增的统一函数

### 1. run_PSO_unified.m
PSO算法的统一版本，支持可选的图片保存功能。

**调用方式：**
```matlab
% 不保存图片
[g, gbest, gb, total_time] = run_PSO_unified(r_initial, Y1, U1, y1, DesignEFL, cv);

% 保存图片
[g, gbest, gb, total_time] = run_PSO_unified(r_initial, Y1, U1, y1, DesignEFL, cv, ...
    'save_folder', '/path/to/save', 'iteration_num', 1);
```

### 2. run_CPSOGSA_unified.m
CPSOGSA算法的统一版本，支持可选的图片保存功能。

**调用方式：**
```matlab
% 不保存图片
[g, gbest, gb, total_time] = run_CPSOGSA_unified(r_initial, Y1, U1, y1, DesignEFL, cv);

% 保存图片
[g, gbest, gb, total_time] = run_CPSOGSA_unified(r_initial, Y1, U1, y1, DesignEFL, cv, ...
    'save_folder', '/path/to/save', 'iteration_num', 1);
```

### 3. run_GA_unified.m
GA算法的统一版本，支持可选的图片保存功能。

**调用方式：**
```matlab
% 不保存图片
[g, gbest, gb, total_time] = run_GA_unified(r_initial, Y1, U1, y1, DesignEFL, cv);

% 保存图片
[g, gbest, gb, total_time] = run_GA_unified(r_initial, Y1, U1, y1, DesignEFL, cv, ...
    'save_folder', '/path/to/save', 'iteration_num', 1);
```

## 主程序文件

### main_AUTFourMirrorCompare_unified.m
这是修改后的主程序，使用统一的算法函数。主要改进：

1. **简化的函数调用**: 使用统一函数，通过参数控制是否保存图片
2. **更清晰的逻辑**: 代码更易读和维护
3. **一致的参数**: 所有算法使用相同的参数设置

## 参数设置

所有算法现在使用一致的参数：

### PSO参数：
- 迭代次数: T_pso = 20
- 梯度下降迭代: T_gd = 100
- 学习率: learning_rate = 0.1
- 学习因子: c1 = 1.2, c2 = 1.2
- 惯性权重: w = 1

### CPSOGSA参数：
- 迭代次数: T_cpsogsa = 20
- 梯度下降迭代: T_gd = 100
- 学习率: learning_rate = 0.1
- phi1 = 2.05, phi2 = 2.05

### GA参数：
- 迭代次数: T_ga = 20
- 梯度下降迭代: T_gd = 100
- 学习率: learning_rate = 0.1
- 交叉概率: pc = 0.8
- 变异概率: pm = 0.2

## 使用方法

### 1. 基本设置
在主程序中设置算法运行参数：
```matlab
% 图片保存控制
enable_image_saving = false;  % true=保存图片, false=不保存

% 算法选择
enable_PSO = true;        % 是否运行PSO算法
enable_CPSOGSA = true;    % 是否运行CPSOGSA算法
enable_GA = true;         % 是否运行GA算法
```

### 2. 运行实验
直接运行主程序：
```matlab
main_AUTFourMirrorCompare_unified
```

## 优势

### 1. 代码简化
- 原来6个算法函数 → 现在3个统一函数
- 减少重复代码，更易维护
- 参数一致性得到保证

### 2. 灵活性提升
- 通过参数控制是否保存图片
- 可以轻松添加新的可选功能
- 函数调用更加直观

### 3. 一致性保证
- 所有算法使用相同的参数设置
- 确保实验结果的公平比较
- 避免了参数不一致的问题

## 向后兼容

原有的分离函数仍然存在，如果需要可以继续使用。但建议使用新的统一函数以获得更好的一致性和可维护性。

## 错误处理

所有统一函数都包含完善的错误处理机制：
- 图片保存失败时的错误提示
- 参数验证
- 边界条件检查

## 文件清单

### 新增文件：
- `run_PSO_unified.m` - PSO统一算法
- `run_CPSOGSA_unified.m` - CPSOGSA统一算法  
- `run_GA_unified.m` - GA统一算法
- `main_AUTFourMirrorCompare_unified.m` - 统一主程序

### 原有文件（保留）：
- `run_PSO_with_initial.m` / `run_PSO_with_initial_and_save.m`
- `run_CPSOGSA_with_initial.m` / `run_CPSOGSA_with_initial_and_save.m`
- `run_GA_with_initial.m` / `run_GA_with_initial_and_save.m`
- `main_AUTFourMirrorCompare.m`
