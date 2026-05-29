function distance = shortestdistance(A,B,C)
%% A and B represent the two vertex of the line, C reprensent the point
D1 = sqrt((A(1) - C(1))^2+(A(2) - C(2))^2);
D2 = sqrt((B(1) - C(1))^2+(B(2) - C(2))^2);
distance = min(D1,D2);
end