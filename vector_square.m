function [vector_square_AB] = vector_square(A,B)
%UNTITLED 此处显示有关此函数的摘要
% 计算向量乘法
%   此处显示详细说明
  vector_square_AB = [A(1)*B(2)+A(2)*B(1) , A(2)*B(2)-A(1)*B(1)];
end