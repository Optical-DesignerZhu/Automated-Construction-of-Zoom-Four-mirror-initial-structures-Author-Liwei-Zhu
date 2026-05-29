function shortestDistance = pointToConvexQuadrilateral(x, y, vertices)
    [numVertices, ~] = size(vertices);
    
    shortestDistance = inf;
    
    for i = 1:numVertices
        A = vertices(i, :);
        B = vertices(mod(i, numVertices) + 1, :);
        
        dist = pointToLineDistance([x, y], A, B);
        
        if dist < shortestDistance
            shortestDistance = dist;
        end
    end
end

function dist = pointToLineDistance(point, lineStart, lineEnd)
    v = lineEnd - lineStart;
    w = point - lineStart;
    
    c1 = dot(w, v);
    c2 = dot(v, v);
    
    if c1 <= 0
        dist = norm(w);
    elseif c2 <= c1
        dist = norm(point - lineEnd);
    else
        b = c1 / c2;
        pb = lineStart + b * v;
        dist = norm(point - pb);
    end
end