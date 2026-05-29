function result = pointInConvexQuadrilateral(x, y, vertices)
    %#codegen
    [numVertices, ~] = size(vertices);
    result = true;
    
    % 1. 提前初始化变量，彻底规避 "未完全定义" 报错
    % 并且避免使用内置函数名 'sign'
    ref_sign = 0.0; 
    
    for i = 1:numVertices
        A = vertices(i, :);
        
        % 2. 使用 C++ 友好的显式索引，规避 mod 函数开销
        if i == numVertices
            B = vertices(1, :);
        else
            B = vertices(i + 1, :);
        end
        
        % 3. 标量展开，彻底取代耗时的 dot() 泛型函数
        N_AB_x = B(2) - A(2);
        N_AB_y = A(1) - B(1);
        V_AP_x = x - A(1);
        V_AP_y = y - A(2);
        
        dot_product = V_AP_x * N_AB_x + V_AP_y * N_AB_y;
        
        if i == 1
            ref_sign = dot_product;
        else
            if dot_product * ref_sign < 0
                result = false;
                break;
            end
        end
    end
end