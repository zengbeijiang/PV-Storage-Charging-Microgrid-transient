% ==========================================================
% 光储充电站优化运行 - 遗传算法(GA)调用示例
% ==========================================================
% 本脚本演示了如何使用 MATLAB 的 ga 函数来寻找最优的充放电策略
% 目标：使全天的运行总成本最低（购电成本 + 电池损耗）
% ----------------------------------------------------------

% 1. 准备基础数据（假设数据）
% ----------------------------------------------------------
T = 24; % 调度周期为24小时
P_load = 100 + 20*randn(1, T); % 假设的负荷曲线 (kW)
P_pv = [zeros(1,6), 10:10:50, 50:-10:10, zeros(1,5)]; % 假设的光伏出力 (kW)
Price = [0.3*ones(1,7), 0.8*ones(1,14), 0.3*ones(1,3)]; % 分时电价 (元/kWh)

% 2. 设置遗传算法参数
% ----------------------------------------------------------
% 变量个数：24个（代表一天24小时，每个小时电池充放电功率）
nVars = 24; 

% 变量上下界（约束条件）：
% 假设电池最大充电功率 20kW，最大放电功率 20kW
% 正数代表充电，负数代表放电
lb = -20 * ones(1, T); % 下界 (Lower Bound)
ub =  20 * ones(1, T); % 上界 (Upper Bound)

% 3. 定义适应度函数 (Fitness Function)
% ----------------------------------------------------------
% 这是一个匿名函数，输入是 x (即24小时的充放电策略)，输出是 Cost (总成本)
% 'fitness_function' 是我们在下面定义的具体计算逻辑
FitnessFcn = @(x) calculate_cost(x, P_load, P_pv, Price);

% 4. 运行遗传算法
% ----------------------------------------------------------
% options = optimoptions('ga', 'PlotFcn', @gaplotbestf); % (可选) 画出收敛曲线
disp('正在进行遗传算法寻优，请稍候...');
% [x_best, fval] = ga(FitnessFcn, nVars, [], [], [], [], lb, ub); 
% 注意：实际运行时需要 Global Optimization Toolbox
% 这里仅作演示，假设我们已经算出了结果
x_best = zeros(1, 24); % 占位符
fval = 100; % 占位符

disp('优化完成！');
disp(['最低总成本: ', num2str(fval), ' 元']);
disp('最优充放电策略 (x_best):');
disp(x_best);

% ==========================================================
% 附：核心计算逻辑 (这就是你的"模型"与"算法"的接口)
% ==========================================================
function total_cost = calculate_cost(P_bat, P_load, P_pv, Price)
    % P_bat 是遗传算法生成的一组"尝试解" (24个数值)
    
    % A. 计算电网交互功率 P_grid
    % 根据功率平衡：P_grid + P_pv + P_bat_discharge = P_load + P_bat_charge
    % 简化公式：P_grid = P_load + P_bat - P_pv; (注意 P_bat 正负定义)
    P_grid = P_load + P_bat - P_pv;
    
    % B. 处理约束惩罚 (关键步骤！)
    % 如果 P_grid 超过变压器容量，或者 SOC 超限，就给一个巨大的惩罚成本
    penalty = 0;
    
    % 模拟 SOC 变化
    SOC = 0.5; % 初始 SOC
    Bat_Capacity = 100; % 电池容量 100kWh
    for t = 1:24
        SOC = SOC + P_bat(t) * 1 / Bat_Capacity; % 简单积分
        if SOC > 0.9 || SOC < 0.1
            penalty = penalty + 10000; % 越限惩罚，让 GA 自动淘汰这种解
        end
    end
    
    % C. 计算经济成本
    % 购电成本 (假设售电不赚钱，或者价格不同，这里简化为单向)
    cost_grid = sum(P_grid .* Price); 
    
    % 电池损耗成本 (通常按吞吐量计算)
    cost_bat_loss = sum(abs(P_bat)) * 0.1; 
    
    % D. 总目标函数值
    total_cost = cost_grid + cost_bat_loss + penalty;
end
