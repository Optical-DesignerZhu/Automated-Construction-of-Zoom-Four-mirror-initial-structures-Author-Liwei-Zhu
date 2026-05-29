function f = funLine6q(tr, D_max, stopPos)
    %#codegen
    if nargin < 3, stopPos = 5; end 
    
    % 1. 提取顶点
    [PointAx, PointAy, PointBx, PointBy] = get_furthest_pairs(tr.P_S(:), 7);

    % 2. 映射真实边界
    for k = 1:4
        if stopPos == 0, s = k + 2; else, s = k + 1; end
        
        y_edge = D_max(k); 
        R_eff = tr.R(k); if k == 2 || k == 4, R_eff = -R_eff; end
        c = 1 / R_eff; K_conic = tr.K_conic(k);
        
        if abs(c) < 1e-12, x_edge = 0;
        else
            radicand = 1 - (1+K_conic)*(c*y_edge)^2;
            if radicand < 0, radicand = 0; end
            x_edge = (c * y_edge^2) / (1 + sqrt(radicand));
        end
        
        ptA_y = tr.O(k,1) + x_edge * tr.NX(k,1) + y_edge * tr.NY(k,1);
        ptA_z = tr.O(k,2) + x_edge * tr.NX(k,2) + y_edge * tr.NY(k,2);
        ptB_y = tr.O(k,1) + x_edge * tr.NX(k,1) - y_edge * tr.NY(k,1);
        ptB_z = tr.O(k,2) + x_edge * tr.NX(k,2) - y_edge * tr.NY(k,2);
        
        PointAx(s) = ptA_z; PointAy(s) = ptA_y;
        PointBx(s) = ptB_z; PointBy(s) = ptB_y;
    end

    D1 = zeros(6, 10); 
    Erf2 = 0;
    
    for i = 1:6   
        [SortPx, SortPy] = SortAndExpandVertices([PointAx(i),PointBx(i),PointAx(i+1),PointBx(i+1)], [PointAy(i),PointBy(i),PointAy(i+1),PointBy(i+1)], 10);
        
        TestAx = PointAx; TestAy = PointAy; TestAx(i:i+1) = []; TestAy(i:i+1) = [];
        TestBx = PointBx; TestBy = PointBy; TestBx(i:i+1) = []; TestBy(i:i+1) = [];
        TestPx = [TestAx TestBx]; TestPy = [TestAy TestBy];
        
        % 计算内点惩罚 Erf1
        for k = 1:10
            if pointInConvexQuadrilateral(TestPx(k), TestPy(k), [SortPx', SortPy'])
                D1(i,k) = pointToConvexQuadrilateral(TestPx(k), TestPy(k), [SortPx', SortPy'])^2 + 10; 
            end
        end
        
        % MEX 友好型线段对映射
        switch i
            case 1
                pairs = [2,3; 3,4; 4,5; 5,6; 6,7];
            case 2
                pairs = [3,4; 4,5; 5,6; 6,7];
            case 3
                pairs = [1,2; 4,5; 5,6; 6,7];
            case 4
                pairs = [1,2; 2,3; 5,6; 6,7];
            case 5
                pairs = [1,2; 2,3; 3,4; 6,7];
            otherwise
                pairs = [1,2; 2,3; 3,4; 4,5];
        end
        
        % 计算线段干涉惩罚 Erf2
        for p = 1:size(pairs, 1)
            w1 = pairs(p, 1); w2 = pairs(p, 2);
            [a1, b1] = fast_intersect(SortPx(1:2), SortPy(1:2), [PointAx(w1), PointAx(w2)], [PointAy(w1), PointAy(w2)]);
            [a2, b2] = fast_intersect(SortPx(1:2), SortPy(1:2), [PointBx(w1), PointBx(w2)], [PointBy(w1), PointBy(w2)]);
            
            if ~isempty(a1), Erf2 = Erf2 + shortestdistance([SortPx(1),SortPy(1)], [SortPx(2),SortPy(2)], [a1,b1])^2 + 10; end
            if ~isempty(a2), Erf2 = Erf2 + shortestdistance([SortPx(1),SortPy(1)], [SortPx(2),SortPy(2)], [a2,b2])^2 + 10; end
        end
    end
    
    f = sum(D1(:)) + Erf2;
end

% =========================================================================
% 🚨 MEX 友好型辅助函数区
% =========================================================================
function [ptAx, ptAy, ptBx, ptBy] = get_furthest_pairs(P_S, num_surfaces)
    ptAx = zeros(1, num_surfaces); ptAy = zeros(1, num_surfaces);
    ptBx = zeros(1, num_surfaces); ptBy = zeros(1, num_surfaces);
    idx1 = [1, 1, 1, 2, 2, 3]; idx2 = [2, 3, 4, 3, 4, 4];
    
    for s = 1:num_surfaces
        offset = (s-1)*8;
        py = P_S(offset+1 : offset+4); pz = P_S(offset+5 : offset+8);
        
        max_sq = -1.0; max_i = 1;
        for i = 1:6
            sq_dist = (py(idx1(i)) - py(idx2(i)))^2 + (pz(idx1(i)) - pz(idx2(i)))^2;
            if sq_dist > max_sq
                max_sq = sq_dist;
                max_i = i;
            end
        end
        
        ptAx(s) = pz(idx1(max_i)); ptAy(s) = py(idx1(max_i));
        ptBx(s) = pz(idx2(max_i)); ptBy(s) = py(idx2(max_i));
    end
end

function [cx, cy] = fast_intersect(X1, Y1, X2, Y2)
    x1=X1(1); x2=X1(2); y1=Y1(1); y2=Y1(2);
    x3=X2(1); x4=X2(2); y3=Y2(1); y4=Y2(2);
    den = (x1 - x2)*(y3 - y4) - (y1 - y2)*(x3 - x4);
    if abs(den) < 1e-12, cx = []; cy = []; return; end
    t = ((x1 - x3)*(y3 - y4) - (y1 - y3)*(x3 - x4)) / den;
    u = ((x1 - x3)*(y1 - y2) - (y1 - y3)*(x1 - x2)) / den;
    if t >= -1e-8 && t <= 1+1e-8 && u >= -1e-8 && u <= 1+1e-8
        cx = x1 + t*(x2 - x1); cy = y1 + t*(y2 - y1);
    else, cx = []; cy = []; end
end