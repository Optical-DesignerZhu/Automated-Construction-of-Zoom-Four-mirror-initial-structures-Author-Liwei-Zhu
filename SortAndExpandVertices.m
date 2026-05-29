function [Ax, Ay] = SortAndExpandVertices(Bx, By, a)
    %#codegen
    
    % 第一步：使用极速求交函数替代 polyxpoly，判断多边形是否自交 (蝴蝶结形状)
    [xi, ~] = fast_intersect_local([Bx(1), Bx(4)], [By(1), By(4)], [Bx(2), Bx(3)], [By(2), By(3)]);
    
    if ~isempty(xi)
        % 如果相交，则交换 3 和 4 的顺序解开自交
        Ax = [Bx(1), Bx(2), Bx(4), Bx(3)];
        Ay = [By(1), By(2), By(4), By(3)];
    else
        Ax = Bx;
        Ay = By;
    end
    
    % 第二步：计算形心
    cx = mean(Ax);
    cy = mean(Ay);
    
    % 第三步：计算方向和距离
    dx = Ax - cx;
    dy = Ay - cy;
    dist = sqrt(dx.^2 + dy.^2);
    
    % 第四步：归一化方向 (使用 C++ 友好的显式 for 循环替代逻辑索引)
    ux = zeros(1, 4);
    uy = zeros(1, 4);
    for i = 1:4
        if dist(i) > 1e-12 % 规避除零风险
            ux(i) = dx(i) / dist(i);
            uy(i) = dy(i) / dist(i);
        end
    end
    
    % 第五步：向外扩展顶点
    Ax = Ax + a * ux;
    Ay = Ay + a * uy;
end

% =========================================================================
% 🚨 局部极速求交函数 (完全支持 MEX 编译)
% =========================================================================
function [cx, cy] = fast_intersect_local(X1, Y1, X2, Y2)
    x1=X1(1); x2=X1(2); y1=Y1(1); y2=Y1(2);
    x3=X2(1); x4=X2(2); y3=Y2(1); y4=Y2(2);
    
    den = (x1 - x2)*(y3 - y4) - (y1 - y2)*(x3 - x4);
    if abs(den) < 1e-12
        cx = []; cy = []; return;
    end
    
    t = ((x1 - x3)*(y3 - y4) - (y1 - y3)*(x3 - x4)) / den;
    u = ((x1 - x3)*(y1 - y2) - (y1 - y3)*(x1 - x2)) / den;
    
    % 加入微小容差
    if t >= -1e-8 && t <= 1+1e-8 && u >= -1e-8 && u <= 1+1e-8
        cx = x1 + t*(x2 - x1);
        cy = y1 + t*(y2 - y1);
    else
        cx = []; cy = [];
    end
end