function [Wrms] = funWavefront_SM2(r, U1, y1, H_array)
% funWavefront_SM2 - 计算离轴系统全视场下的平均波前 (自适应 SPH/CON 版, M2上)

    if nargin < 4 || isempty(H_array)
        H_array = [0, 0; 0, 1; 0, -1; 1, 0];
    end

    r = r(:)'; 
    if length(r) == 13
        r = [r, 0, 0, 0, 0];
    elseif length(r) < 13
        error('输入参数矩阵维度不足，至少需要 13 维。');
    end

    r(5) = [];
    r(8) = [];
    lamda = 10 * 10^(-3); 
    
    %% ================= 计算各个表面球面 Seidel 贡献 =================
    S1_sp_surface1 =(-2).*r(1).^(-3).*y1.^4;
    S1_sp_surface2 = 2.*r(1).^(-4).*r(2).^(-3).*(r(1)+(-2).*r(5)).^2.*(r(1)+(-2).*(r(2)+r(5))).^2.* y1.^4;
    S1_sp_surface3 = (-2).*r(1).^(-4).*r(2).^(-4).*r(3).^(-3).*((-2).*r(2).*r(5)+r(1).*(r(2)+(-2).* ...
      r(6))+2.*r(2).*r(6)+4.*r(5).*r(6)).^2.*(4.*r(5).*(r(3)+r(6))+2.*r(2).*(r(3)+(-1).*r(5)+ ...
      r(6))+r(1).*(r(2)+(-2).*(r(3)+r(6)))).^2.*y1.^4;
    S1_sp_surface4 =2.*r(1).^(-4).*r(2).^(-4).*r(3).^(-4).*r(4).^(-3).*(4.*r(2).*(r(5)+(-1).*r(6)).* ...
      (r(4)+r(7))+(-8).*r(5).*r(6).*(r(4)+r(7))+(-4).*r(3).*r(5).*(r(4)+(-1).*r(6)+r(7))+(-2) ...
      .*r(2).*r(3).*(r(4)+r(5)+(-1).*r(6)+r(7))+r(1).*r(2).*(r(3)+(-2).*(r(4)+r(7)))+2.*r(1).*( ...
      2.*r(6).*(r(4)+r(7))+r(3).*(r(4)+(-1).*r(6)+r(7)))).^2.*(r(1).*((-2).*r(3).*r(6)+r(2).*( ...
      r(3)+(-2).*r(7))+2.*r(3).*r(7)+4.*r(6).*r(7))+(-2).*(4.*r(5).*r(6).*r(7)+2.*r(2).*(( ...
      -1).*r(5)+r(6)).*r(7)+2.*r(3).*r(5).*((-1).*r(6)+r(7))+r(2).*r(3).*(r(5)+(-1).*r(6)+r(7))) ...
      ).^2.*y1.^4;
      
    U2 = U1/(-1+2/r(1)*r(5));
    
    S2_sp_surface1 = 2.*r(1).^(-3).*(r(1)+(-1).*r(5)).*U2.*y1.^3;
    S2_sp_surface2 = 2.*r(1).^(-3).*r(2).^(-2).*(r(1)+(-2).*r(5)).^2.*(r(1)+(-2).*(r(2)+r(5))).*U2.* y1.^3;
    S2_sp_surface3 =(2).*r(1).^(-3).*r(2).^(-3).*r(3).^(-3).*(r(3)+r(6)).*((-2).*r(2).*r(5)+r(1).*( ...
      r(2)+(-2).*r(6))+2.*r(2).*r(6)+4.*r(5).*r(6)).^2.*(4.*r(5).*(r(3)+r(6))+2.*r(2).*(r(3)+( ...
      -1).*r(5)+r(6))+r(1).*(r(2)+(-2).*(r(3)+r(6)))).*U2.*y1.^3;
    S2_sp_surface4 = 2.*r(1).^(-3).*r(2).^(-3).*r(3).^(-4).*r(4).^(-3).*(2.*r(6).*(r(4)+r(7))+r(3).*( ...
      r(4)+(-1).*r(6)+r(7))).*(8.*r(5).*r(6).*r(7)+4.*r(2).*((-1).*r(5)+r(6)).*r(7)+4.*r(3).* ...
      r(5).*((-1).*r(6)+r(7))+2.*r(2).*r(3).*(r(5)+(-1).*r(6)+r(7))+r(1).*((-1).*r(2).*r(3)+ ...
      2.*r(3).*r(6)+2.*r(2).*r(7)+(-2).*r(3).*r(7)+(-4).*r(6).*r(7))).^2.*(4.*r(2).*(r(5)+( ...
      -1).*r(6)).*(r(4)+r(7))+(-8).*r(5).*r(6).*(r(4)+r(7))+(-4).*r(3).*r(5).*(r(4)+(-1).* ...
      r(6)+r(7))+(-2).*r(2).*r(3).*(r(4)+r(5)+(-1).*r(6)+r(7))+r(1).*r(2).*(r(3)+(-2).*(r(4)+r(7)) ...
      )+2.*r(1).*(2.*r(6).*(r(4)+r(7))+r(3).*(r(4)+(-1).*r(6)+r(7)))).*U2.*y1.^3;
      
    S3_sp_surface1 =(-2).*r(1).^(-3).*(r(1)+(-1).*r(5)).^2.*U2.^2.*y1.^2;
    S3_sp_surface2 = 2.*r(1).^(-2).*r(2).^(-1).*(r(1)+(-2).*r(5)).^2.*U2.^2.*y1.^2;
    S3_sp_surface3 = (-2).*r(1).^(-2).*r(2).^(-2).*r(3).^(-3).*(r(3)+r(6)).^2.*((-2).*r(2).*r(5)+r(1).* ...
      (r(2)+(-2).*r(6))+2.*r(2).*r(6)+4.*r(5).*r(6)).^2.*U2.^2.*y1.^2;
    S3_sp_surface4 = 2.*r(1).^(-2).*r(2).^(-2).*r(3).^(-4).*r(4).^(-3).*(2.*r(6).*(r(4)+r(7))+r(3).*( ...
      r(4)+(-1).*r(6)+r(7))).^2.*(8.*r(5).*r(6).*r(7)+4.*r(2).*((-1).*r(5)+r(6)).*r(7)+4.* ...
      r(3).*r(5).*((-1).*r(6)+r(7))+2.*r(2).*r(3).*(r(5)+(-1).*r(6)+r(7))+r(1).*((-1).*r(2).* ...
      r(3)+2.*r(3).*r(6)+2.*r(2).*r(7)+(-2).*r(3).*r(7)+(-4).*r(6).*r(7))).^2.*U2.^2.* y1.^2;
      
    S4_sp_surface1 =2.*r(1).^(-1).*U1.^2.*y1.^2;
    S4_sp_surface2 = (-2).*r(2).^(-1).*U1.^2.*y1.^2;
    S4_sp_surface3 = 2.*r(3).^(-1).*U1.^2.*y1.^2;
    S4_sp_surface4 = (-2).*r(4).^(-1).*U1.^2.*y1.^2;
    
    %% ================= 计算各个表面非球面和球面 Seidel 叠加贡献 =================
    S1_asp_surface1 = (-2).*r(12).*r(1).^(-3).*y1.^4;
    S1_asp_surface2 = 2.*r(13).*r(1).^(-4).*r(2).^(-3).*(r(1)+(-2).*r(5)).^4.*y1.^4;
    S1_asp_surface3 =(-2).*r(14).*r(1).^(-4).*r(2).^(-4).*r(3).^(-3).*((-2).*r(2).*r(5)+r(1).*(r(2)+(-2) ...
      .*r(6))+2.*r(2).*r(6)+4.*r(5).*r(6)).^4.*y1.^4;
    S1_asp_surface4 =2.*r(15).*r(1).^(-4).*r(2).^(-4).*r(3).^(-4).*r(4).^(-3).*(r(1).*((-2).*r(3).*r(6)+ ...
      r(2).*(r(3)+(-2).*r(7))+2.*r(3).*r(7)+4.*r(6).*r(7))+(-2).*(4.*r(5).*r(6).*r(7)+2.* ...
      r(2).*((-1).*r(5)+r(6)).*r(7)+2.*r(3).*r(5).*((-1).*r(6)+r(7))+r(2).*r(3).*(r(5)+(-1).* ...
      r(6)+r(7)))).^4.*y1.^4;
      
    S1_surface1 = S1_sp_surface1 + S1_asp_surface1;
    S1_surface2 = S1_sp_surface2 + S1_asp_surface2;
    S1_surface3 = S1_sp_surface3 + S1_asp_surface3;
    S1_surface4 = S1_sp_surface4 + S1_asp_surface4;
    
    S2_asp_surface1 = 2.*r(12).*r(1).^(-3).*r(5).*U2.*y1.^3;
    S2_asp_surface2 = 0;
    S2_asp_surface3 = 2.*r(14).*r(1).^(-3).*r(2).^(-3).*r(3).^(-3).*r(6).*((-2).*r(2).*r(5)+r(1).*(r(2)+( ...
      -2).*r(6))+2.*r(2).*r(6)+4.*r(5).*r(6)).^3.*U2.*y1.^3;
    S2_asp_surface4 = (-2).*r(15).*r(1).^(-3).*r(2).^(-3).*r(3).^(-4).*r(4).^(-3).*(r(3).*(r(6)+(-1).* ...
      r(7))+(-2).*r(6).*r(7)).*(r(1).*((-2).*r(3).*r(6)+r(2).*(r(3)+(-2).*r(7))+2.*r(3).*r(7)+ ...
      4.*r(6).*r(7))+(-2).*(4.*r(5).*r(6).*r(7)+2.*r(2).*((-1).*r(5)+r(6)).*r(7)+2.*r(3).* ...
      r(5).*((-1).*r(6)+r(7))+r(2).*r(3).*(r(5)+(-1).*r(6)+r(7)))).^3.*U2.*y1.^3;
      
    S2_surface1 = S2_sp_surface1 + S2_asp_surface1;
    S2_surface2 = S2_sp_surface2 + S2_asp_surface2;
    S2_surface3 = S2_sp_surface3 + S2_asp_surface3;
    S2_surface4 = S2_sp_surface4 + S2_asp_surface4;
    
    S3_asp_surface1 = (-2).*r(12).*r(1).^(-3).*r(5).^2.*U2.^2.*y1.^2;
    S3_asp_surface2 = 0;
    S3_asp_surface3 = (-2).*r(14).*r(1).^(-2).*r(2).^(-2).*r(3).^(-3).*r(6).^2.*((-2).*r(2).*r(5)+r(1).*( ...
      r(2)+(-2).*r(6))+2.*r(2).*r(6)+4.*r(5).*r(6)).^2.*U2.^2.*y1.^2;
    S3_asp_surface4 =2.*r(15).*r(1).^(-2).*r(2).^(-2).*r(3).^(-4).*r(4).^(-3).*(r(3).*(r(6)+(-1).*r(7))+ ...
      (-2).*r(6).*r(7)).^2.*(8.*r(5).*r(6).*r(7)+4.*r(2).*((-1).*r(5)+r(6)).*r(7)+4.*r(3).* ...
      r(5).*((-1).*r(6)+r(7))+2.*r(2).*r(3).*(r(5)+(-1).*r(6)+r(7))+r(1).*((-1).*r(2).*r(3)+ ...
      2.*r(3).*r(6)+2.*r(2).*r(7)+(-2).*r(3).*r(7)+(-4).*r(6).*r(7))).^2.*U2.^2.*y1.^2; 
      
    S3_surface1 = S3_sp_surface1 + S3_asp_surface1;
    S3_surface2 = S3_sp_surface2 + S3_asp_surface2;
    S3_surface3 = S3_sp_surface3 + S3_asp_surface3;
    S3_surface4 = S3_sp_surface4 + S3_asp_surface4;
    
    S4_asp_surface1 = 0; S4_asp_surface2 = 0; S4_asp_surface3 = 0; S4_asp_surface4 = 0;
    S4_surface1 = S4_sp_surface1 + S4_asp_surface1;
    S4_surface2 = S4_sp_surface2 + S4_asp_surface2;
    S4_surface3 = S4_sp_surface3 + S4_asp_surface3;
    S4_surface4 = S4_sp_surface4 + S4_asp_surface4;

    %% ================= 计算各个表面波像差(球面与非球面拆分) =================
    W040_Sp = [(1/8)*S1_sp_surface1/lamda, (1/8)*S1_sp_surface2/lamda, (1/8)*S1_sp_surface3/lamda, (1/8)*S1_sp_surface4/lamda];
    W040_asp = [(1/8)*S1_asp_surface1/lamda, (1/8)*S1_asp_surface2/lamda, (1/8)*S1_asp_surface3/lamda, (1/8)*S1_asp_surface4/lamda];
    W131_Sp = [(1/2)*S2_sp_surface1/lamda, (1/2)*S2_sp_surface2/lamda, (1/2)*S2_sp_surface3/lamda, (1/2)*S2_sp_surface4/lamda];
    W131_asp = [(1/2)*S2_asp_surface1/lamda, (1/2)*S2_asp_surface2/lamda, (1/2)*S2_asp_surface3/lamda, (1/2)*S2_asp_surface4/lamda];
    W222_Sp = [(1/2)*S3_sp_surface1/lamda, (1/2)*S3_sp_surface2/lamda, (1/2)*S3_sp_surface3/lamda, (1/2)*S3_sp_surface4/lamda];
    W222_asp = [(1/2)*S3_asp_surface1/lamda, (1/2)*S3_asp_surface2/lamda, (1/2)*S3_asp_surface3/lamda, (1/2)*S3_asp_surface4/lamda];
    W220_Sp = [(1/4)*(S3_sp_surface1+S4_sp_surface1)/lamda, (1/4)*(S3_sp_surface2+S4_sp_surface2)/lamda, (1/4)*(S3_sp_surface3+S4_sp_surface3)/lamda, (1/4)*(S3_sp_surface4+S4_sp_surface4)/lamda];
    W220_asp = [(1/4)*(S3_asp_surface1+S4_asp_surface1)/lamda, (1/4)*(S3_asp_surface2+S4_asp_surface2)/lamda, (1/4)*(S3_asp_surface3+S4_asp_surface3)/lamda, (1/4)*(S3_asp_surface4+S4_asp_surface4)/lamda];
    W220M_Sp = W220_Sp + 0.5*W222_Sp;
    
    %% ================= 获取系统的倾斜角度 =================
    tiltXM1 = r(8); tiltXM2 = r(9); tiltXM3 = r(10); tiltXM4 = r(11);
    
    I1 = -((-1).*r(1).^(-1).*r(5).*U2+((-1)+2.*r(1).^(-1).*r(5)).*U2);
    I2 = -U2;
    I3 = -((-1).*U2+(-1).*r(3).^(-1).*r(6).*U2);
    I4 = -((1+2.*r(3).^(-1).*r(6)).*U2+(-1).*r(4).^(-1).*((-1).*r(7)+r(6).*(1+(-2).*r(3).^(-1).*r(7))).*U2);

    sigma_Sp_S1 = [0 sind(tiltXM1)]/I1;
    sigma_Sp_S2 = [0 sind(tiltXM2)]/I2;
    sigma_Sp_S3 = [0 sind(tiltXM3)]/I3;
    sigma_Sp_S4 = [0 sind(tiltXM4)]/I4;
    
    %% ================= 计算 波前RMS (动态对称视场循环采样) =================
    W040_sum = sum(W040_Sp + W040_asp);
    W131_sum = sum(W131_Sp + W131_asp);
    W220_sum = sum(W220_Sp + W220_asp);
    W222_sum = sum(W222_Sp + W222_asp);
    W220m_sum = W220_sum + 0.5*W222_sum;
    
    A131 = W131_Sp(1)*sigma_Sp_S1 + W131_Sp(2)*sigma_Sp_S2 + W131_Sp(3)*sigma_Sp_S3 + W131_Sp(4)*sigma_Sp_S4;
    A222 = W222_Sp(1)*sigma_Sp_S1 + W222_Sp(2)*sigma_Sp_S2 +  W222_Sp(3)*sigma_Sp_S3 +  W222_Sp(4)*sigma_Sp_S4;
    B222_2 = W222_Sp(1)*vector_square(sigma_Sp_S1,sigma_Sp_S1) + W222_Sp(2)*vector_square(sigma_Sp_S2,sigma_Sp_S2) + W222_Sp(3)*vector_square(sigma_Sp_S3,sigma_Sp_S3)+ W222_Sp(4)*vector_square(sigma_Sp_S4,sigma_Sp_S4);
    
    A220M = W220M_Sp(1)*sigma_Sp_S1 + W220M_Sp(2)*sigma_Sp_S2 +  W220M_Sp(3)*sigma_Sp_S3 +  W220M_Sp(4)*sigma_Sp_S4;
    B220M = W220M_Sp(1)*dot(sigma_Sp_S1,sigma_Sp_S1) + W220M_Sp(2)*dot(sigma_Sp_S2,sigma_Sp_S2) +  W220M_Sp(3)*dot(sigma_Sp_S3,sigma_Sp_S3) +  W220M_Sp(4)*dot(sigma_Sp_S4,sigma_Sp_S4);
    
    total_Wrms = 0;
    N_fields = size(H_array, 1);
    
    for idx = 1:N_fields
        H = H_array(idx, :);
        Fai_131 = W131_sum*H - A131;
        Fai_222 = W222_sum*vector_square(H,H) - 2*vector_square(H,A222) + B222_2;
        Fai_220M = W220m_sum*dot(H,H) - 2*dot(H,A220M) + B220M;
        
        defocus = -(W040_sum + Fai_220M);
        current_Wrms = sqrt( (1/12)*(defocus+W040_sum + Fai_220M )^2 + (1/180)*W040_sum^2 +(1/24)*(dot(Fai_222,Fai_222))  + (1/4)*( dot((2/3)*Fai_131,(2/3)*Fai_131)) + (1/72)*dot(Fai_131,Fai_131));
        total_Wrms = total_Wrms + current_Wrms;
    end
    
    Wrms = total_Wrms / N_fields;
end