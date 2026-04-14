% =========================================================================
% 微电网日前经济调度 - 粒子群优化算法 (PSO) [最终定稿版]
% =========================================================================
clc; clear; close all;

%% 1. 系统参数初始化
T = 24; % 调度周期 24小时

% 分时电价 (谷段0.3, 平段0.6, 峰段1.0)
price_buy = [0.3*ones(1,7), 0.6*ones(1,3), 1.0*ones(1,5), 0.6*ones(1,3), 1.0*ones(1,5), 0.3];
price_sell = price_buy * 0.8; 

% 负荷：压平基础负荷，保留晚高峰的特征
P_load = [80, 75, 70, 70, 75, 90, 120, 150, 160, 160, 150, 140, 130, 140, 150, 180, 220, 240, 250, 210, 170, 130, 100, 85];
% 光伏：大幅拉高光伏曲线，使其在中午远超负荷，制造“余电上网”
P_pv = [0, 0, 0, 0, 0, 0, 30, 80, 150, 220, 260, 280, 270, 230, 160, 90, 20, 0, 0, 0, 0, 0, 0, 0];

% 储能电池参数
E_bat_max = 200; % 电池容量 200kWh
P_bat_max = 80;  % 最大充放电功率 80kW (允许较大倍率充放电)
SOC_min = 0.2; SOC_max = 0.9;
SOC_init = 0.5; 
K_wear = 0.15; % 显著提高单次循环的电池磨损惩罚，阻止算法无意义地充放电

%% 2. PSO 算法参数设置
N = 300; % 种群规模
Max_Iter = 500; % 迭代次数
c1 = 1.2; c2 = 1.2; % 降低学习因子，使粒子飞行更平滑
w_max = 0.9; w_min = 0.4; 

D = T; 
V_max = 0.1 * P_bat_max; % 降低最大飞行速度，减少剧烈震荡

X = zeros(N, D); V = zeros(N, D); 
pBest_X = zeros(N, D); pBest_F = inf * ones(N, 1); 
gBest_X = zeros(1, D); gBest_F = inf; 

for i = 1:N
    X(i, :) = (rand(1, D)*2 - 1) * P_bat_max; 
    V(i, :) = (rand(1, D)*2 - 1) * V_max;
end

%% 3. 核心迭代寻优过程
disp('开始 PSO 深度寻优计算 (已加入平滑约束，请稍候)...');
convergence_curve = zeros(1, Max_Iter);

for iter = 1:Max_Iter
    w = w_max - (w_max - w_min) * iter / Max_Iter; 
    for i = 1:N
        P_bat_var = X(i, :);
        cost_total = 0; penalty = 0;
        SOC_current = SOC_init;
        
        for t = 1:T
            SOC_next = SOC_current + (P_bat_var(t) * 1) / E_bat_max;
            if SOC_next < SOC_min || SOC_next > SOC_max
                penalty = penalty + 1e6; 
            end
            SOC_current = SOC_next;
            
            % 【核心防震荡机制】：如果充放电方向与前一小时突变，严厉罚款
            if t > 1
                if P_bat_var(t) * P_bat_var(t-1) < 0
                    penalty = penalty + 2000; % 强行阻止锯齿波
                end
            end
            
            P_grid_t = P_load(t) + P_bat_var(t) - P_pv(t);
            if P_grid_t > 0
                cost_grid = P_grid_t * price_buy(t);
            else
                cost_grid = P_grid_t * price_sell(t); 
            end
            cost_wear = abs(P_bat_var(t)) * K_wear;
            cost_total = cost_total + cost_grid + cost_wear;
        end
        
        penalty = penalty + 1e6 * (SOC_current - SOC_init)^2; 
        
        fitness = cost_total + penalty;
        if fitness < pBest_F(i)
            pBest_F(i) = fitness; pBest_X(i, :) = X(i, :);
            if fitness < gBest_F
                gBest_F = fitness; gBest_X = X(i, :);
            end
        end
    end 
    for i = 1:N
        V(i, :) = w * V(i, :) + c1*rand()*(pBest_X(i, :) - X(i, :)) + c2*rand()*(gBest_X - X(i, :));
        V(i, :) = min(max(V(i, :), -V_max), V_max); 
        X(i, :) = X(i, :) + V(i, :);
        X(i, :) = min(max(X(i, :), -P_bat_max), P_bat_max); 
    end
    convergence_curve(iter) = gBest_F;
end
disp('寻优结束！');

%% 4. 提取最优结果并绘图
P_bat_opt = gBest_X;
P_grid_opt = P_load + P_bat_opt - P_pv;
SOC_opt = zeros(1, T+1); SOC_opt(1) = SOC_init;
for t = 1:T
    SOC_opt(t+1) = SOC_opt(t) + (P_bat_opt(t) * 1) / E_bat_max;
end

% ==== 绘图展示 ====
figure('Name', '微电网日前经济调度优化结果', 'Position', [100, 100, 950, 650]);

subplot(2, 2, 1);
plot(1:Max_Iter, convergence_curve, 'LineWidth', 2, 'Color', '#0072BD');
title('PSO 算法收敛曲线'); xlabel('迭代次数'); ylabel('综合运行成本 (元)');
grid on;

subplot(2, 2, 2);
yyaxis left;
ax = gca; ax.YColor = '#D95319'; 
bar(1:T, P_grid_opt, 'FaceColor', '#D95319');
ylabel('网侧交互功率 (kW) [>0购电, <0售电]');
yyaxis right;
ax = gca; ax.YColor = '#0072BD'; 
stairs(1:T, price_buy, 'LineWidth', 2, 'Color', '#0072BD');
ylabel('分时电价 (元/kWh)');
title('网侧交互功率与分时电价关系'); xlabel('时间 (h)'); xlim([0.5, 24.5]); grid on;

subplot(2, 2, 3); hold on;
plot(1:T, P_load, 'k--', 'LineWidth', 1.5); 
plot(1:T, P_pv, 'Color', '#EDB120', 'LineWidth', 2); 
bar(1:T, P_bat_opt, 'FaceColor', '#77AC30'); 
legend('预测负荷', '光伏出力', '储能充放电[>0充, <0放]', 'Location', 'best');
title('微电网源荷储功率平衡调度'); xlabel('时间 (h)'); ylabel('功率 (kW)');
xlim([0.5, 24.5]); grid on;

subplot(2, 2, 4);
plot(0:T, SOC_opt, 'LineWidth', 2, 'Color', '#7E2F8E');
yline(SOC_min, 'r--', 'SOC下限', 'LabelHorizontalAlignment', 'left');
yline(SOC_max, 'r--', 'SOC上限', 'LabelHorizontalAlignment', 'left');
title('储能电池 SOC 变化轨迹'); xlabel('时间 (h)'); ylabel('SOC');
xlim([0, 24]); ylim([0, 1]); grid on;