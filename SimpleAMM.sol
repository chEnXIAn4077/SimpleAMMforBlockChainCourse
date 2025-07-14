// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

contract SimpleAMM {
    // 代币合约地址
    IERC20 public immutable redMarble;
    IERC20 public immutable blueMarble;
    
    // 流动性储备
    uint256 public reserveRed;
    uint256 public reserveBlue;
    
    // LP代币相关
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    
    // 手续费设置 (基点，例如30 = 0.3%)
    uint256 public feeRate = 30;
    address public owner;
    
    // 最小流动性锁定
    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    
    // 代币单位转换
    uint256 public immutable UNIT;
    
    // 事件
    event AddLiquidity(address indexed provider, uint256 redAmount, uint256 blueAmount, uint256 liquidity);
    event RemoveLiquidity(address indexed provider, uint256 redAmount, uint256 blueAmount, uint256 liquidity);
    event Swap(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 amountOut);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    constructor(address _redMarble, address _blueMarble) {
        redMarble = IERC20(_redMarble);
        blueMarble = IERC20(_blueMarble);
        owner = msg.sender;
        
        //  获取代币精度，假设两个代币精度相同
        UNIT = 10**redMarble.decimals();
    }
    
    // ==================== 基础函数 ====================
    
    /**
     * @dev 添加流动性
     * @param redAmount Red Marble代币数量
     * @param blueAmount Blue Marble代币数量
     * @param minLiquidity 最小接受的LP代币数量（滑点保护）
     */
    function addLiquidity(
        uint256 redAmount, 
        uint256 blueAmount, 
        uint256 minLiquidity
    ) public returns (uint256 liquidity) {
        require(redAmount > 0 && blueAmount > 0, "Invalid amounts");
        
        // 转移代币到合约
        redMarble.transferFrom(msg.sender, address(this), redAmount);
        blueMarble.transferFrom(msg.sender, address(this), blueAmount);
        
        if (totalSupply == 0) {
            // 首次添加流动性
            liquidity = sqrt(redAmount * blueAmount);
            require(liquidity > MINIMUM_LIQUIDITY, "Insufficient liquidity");
            // 锁定最小流动性
            liquidity -= MINIMUM_LIQUIDITY;
        } else {
            // 后续添加流动性，按比例计算
            liquidity = min(
                (redAmount * totalSupply) / reserveRed,
                (blueAmount * totalSupply) / reserveBlue
            );
        }
        
        require(liquidity >= minLiquidity, "Slippage too high");
        
        // 更新储备和总供应量
        reserveRed += redAmount;
        reserveBlue += blueAmount;
        totalSupply += liquidity;
        balanceOf[msg.sender] += liquidity;
        
        emit AddLiquidity(msg.sender, redAmount, blueAmount, liquidity);
    }
    
    /**
     * @dev 移除流动性
     * @param liquidity 要移除的LP代币数量
     * @param minRedAmount 最小接受的Red Marble数量
     * @param minBlueAmount 最小接受的Blue Marble数量
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 minRedAmount,
        uint256 minBlueAmount
    ) public returns (uint256 redAmount, uint256 blueAmount) {
        require(liquidity > 0, "Invalid liquidity");
        require(balanceOf[msg.sender] >= liquidity, "Insufficient balance");
        
        // 计算可提取的代币数量
        redAmount = (liquidity * reserveRed) / totalSupply;
        blueAmount = (liquidity * reserveBlue) / totalSupply;
        
        require(redAmount >= minRedAmount && blueAmount >= minBlueAmount, "Slippage too high");
        
        // 更新状态
        balanceOf[msg.sender] -= liquidity;
        totalSupply -= liquidity;
        reserveRed -= redAmount;
        reserveBlue -= blueAmount;
        
        // 转移代币给用户
        redMarble.transfer(msg.sender, redAmount);
        blueMarble.transfer(msg.sender, blueAmount);
        
        emit RemoveLiquidity(msg.sender, redAmount, blueAmount, liquidity);
    }
    
    /**
     * @dev 交换代币：Red Marble -> Blue Marble
     * @param redAmountIn 输入的Red Marble数量
     * @param minBlueAmountOut 最小接受的Blue Marble数量
     */
    function swapRedForBlue(
        uint256 redAmountIn,
        uint256 minBlueAmountOut
    ) public returns (uint256 blueAmountOut) {
        require(redAmountIn > 0, "Invalid input amount");
        
        // 计算输出数量（扣除手续费）
        blueAmountOut = getAmountOut(redAmountIn, reserveRed, reserveBlue);
        require(blueAmountOut >= minBlueAmountOut, "Slippage too high");
        
        // 转移代币
        redMarble.transferFrom(msg.sender, address(this), redAmountIn);
        blueMarble.transfer(msg.sender, blueAmountOut);
        
        // 更新储备
        reserveRed += redAmountIn;
        reserveBlue -= blueAmountOut;
        
        emit Swap(msg.sender, address(redMarble), redAmountIn, blueAmountOut);
    }
    
    /**
     * @dev 交换代币：Blue Marble -> Red Marble
     * @param blueAmountIn 输入的Blue Marble数量
     * @param minRedAmountOut 最小接受的Red Marble数量
     */
    function swapBlueForRed(
        uint256 blueAmountIn,
        uint256 minRedAmountOut
    ) public returns (uint256 redAmountOut) {
        require(blueAmountIn > 0, "Invalid input amount");
        
        // 计算输出数量（扣除手续费）
        redAmountOut = getAmountOut(blueAmountIn, reserveBlue, reserveRed);
        require(redAmountOut >= minRedAmountOut, "Slippage too high");
        
        // 转移代币
        blueMarble.transferFrom(msg.sender, address(this), blueAmountIn);
        redMarble.transfer(msg.sender, redAmountOut);
        
        // 更新储备
        reserveBlue += blueAmountIn;
        reserveRed -= redAmountOut;
        
        emit Swap(msg.sender, address(blueMarble), blueAmountIn, redAmountOut);
    }
    
    // ==================== 便捷函数（以代币为单位） ====================
    
    /**
     * @dev  便捷添加流动性（以代币为单位）
     * @param redTokens Red代币数量（如100表示100个代币）
     * @param blueTokens Blue代币数量
     * @param slippagePercent 滑点容忍度百分比（如5表示5%）
     */
    function addLiquidityTokens(
        uint256 redTokens,
        uint256 blueTokens,
        uint256 slippagePercent
    ) external returns (uint256 liquidity) {
        uint256 redAmount = redTokens * UNIT;
        uint256 blueAmount = blueTokens * UNIT;
        
        // 计算最小流动性
        uint256 minLiquidity = 0;
        if (totalSupply > 0) {
            uint256 expectedLiquidity = min(
                (redAmount * totalSupply) / reserveRed,
                (blueAmount * totalSupply) / reserveBlue
            );
            minLiquidity = expectedLiquidity * (100 - slippagePercent) / 100;
        }
        
        return addLiquidity(redAmount, blueAmount, minLiquidity);
    }
    
    /**
     * @dev  便捷移除流动性（以代币为单位）
     * @param liquidityTokens LP代币数量
     * @param slippagePercent 滑点容忍度百分比
     */
    function removeLiquidityTokens(
        uint256 liquidityTokens,
        uint256 slippagePercent
    ) external returns (uint256 redTokens, uint256 blueTokens) {
        // 计算预期输出
        uint256 redAmount = (liquidityTokens * reserveRed) / totalSupply;
        uint256 blueAmount = (liquidityTokens * reserveBlue) / totalSupply;
        
        // 应用滑点保护
        uint256 minRedAmount = redAmount * (100 - slippagePercent) / 100;
        uint256 minBlueAmount = blueAmount * (100 - slippagePercent) / 100;
        
        (redAmount, blueAmount) = removeLiquidity(liquidityTokens, minRedAmount, minBlueAmount);
        
        return (redAmount / UNIT, blueAmount / UNIT);
    }
    
    /**
     * @dev  便捷交换：Red -> Blue（以代币为单位）
     * @param redTokens 输入的Red代币数量
     * @param slippagePercent 滑点容忍度百分比
     */
    function swapRedForBlueTokens(
        uint256 redTokens,
        uint256 slippagePercent
    ) external returns (uint256 blueTokensOut) {
        uint256 redAmount = redTokens * UNIT;
        uint256 blueAmountOut = getAmountOut(redAmount, reserveRed, reserveBlue);
        uint256 minBlueAmount = blueAmountOut * (100 - slippagePercent) / 100;
        
        blueAmountOut = swapRedForBlue(redAmount, minBlueAmount);
        return blueAmountOut / UNIT;
    }
    
    /**
     * @dev  便捷交换：Blue -> Red（以代币为单位）
     * @param blueTokens 输入的Blue代币数量
     * @param slippagePercent 滑点容忍度百分比
     */
    function swapBlueForRedTokens(
        uint256 blueTokens,
        uint256 slippagePercent
    ) external returns (uint256 redTokensOut) {
        uint256 blueAmount = blueTokens * UNIT;
        uint256 redAmountOut = getAmountOut(blueAmount, reserveBlue, reserveRed);
        uint256 minRedAmount = redAmountOut * (100 - slippagePercent) / 100;
        
        redAmountOut = swapBlueForRed(blueAmount, minRedAmount);
        return redAmountOut / UNIT;
    }
    
    // ==================== 查询函数 ====================
    
    /**
     * @dev 计算输出数量（基于恒定乘积公式）
     * @param amountIn 输入数量
     * @param reserveIn 输入代币储备
     * @param reserveOut 输出代币储备
     */
    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public view returns (uint256 amountOut) {
        require(amountIn > 0, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");
        
        // 应用手续费：amountInWithFee = amountIn * (10000 - feeRate) / 10000
        uint256 amountInWithFee = amountIn * (10000 - feeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        amountOut = numerator / denominator;
    }
    
    /**
     * @dev  预览交换结果（以代币为单位）
     */
    function previewSwapRedForBlueTokens(uint256 redTokens) external view returns (uint256 blueTokensOut) {
        uint256 redAmount = redTokens * UNIT;
        uint256 blueAmount = getAmountOut(redAmount, reserveRed, reserveBlue);
        return blueAmount / UNIT;
    }
    
    function previewSwapBlueForRedTokens(uint256 blueTokens) external view returns (uint256 redTokensOut) {
        uint256 blueAmount = blueTokens * UNIT;
        uint256 redAmount = getAmountOut(blueAmount, reserveBlue, reserveRed);
        return redAmount / UNIT;
    }
    
    /**
     * @dev 获取当前储备
     */
    function getReserves() external view returns (uint256 _reserveRed, uint256 _reserveBlue) {
        _reserveRed = reserveRed;
        _reserveBlue = reserveBlue;
    }
    
    /**
     * @dev  获取当前储备（以代币为单位）
     */
    function getReservesTokens() external view returns (uint256 redTokens, uint256 blueTokens) {
        return (reserveRed / UNIT, reserveBlue / UNIT);
    }
    
    /**
     * @dev  获取用户LP代币余额和对应的代币数量
     */
    function getUserLiquidityInfo(address user) external view returns (
        uint256 lpTokens,
        uint256 redTokens,
        uint256 blueTokens
    ) {
        lpTokens = balanceOf[user];
        if (totalSupply > 0) {
            redTokens = (lpTokens * reserveRed) / totalSupply / UNIT;
            blueTokens = (lpTokens * reserveBlue) / totalSupply / UNIT;
        }
    }
    
    /**
     * @dev  计算当前汇率
     */
    function getCurrentRate() external view returns (uint256 redPerBlue, uint256 bluePerRed) {
        if (reserveRed > 0 && reserveBlue > 0) {
            redPerBlue = (reserveRed * 1000) / reserveBlue;  // 1 BLUE = X/1000 RED
            bluePerRed = (reserveBlue * 1000) / reserveRed;  // 1 RED = X/1000 BLUE
        }
    }
    
    // ==================== 管理函数 ====================
    
    /**
     * @dev 设置手续费率（仅限所有者）
     * @param newFeeRate 新的手续费率（基点）
     */
    function setFeeRate(uint256 newFeeRate) external onlyOwner {
        require(newFeeRate <= 1000, "Fee rate too high"); // 最高10%
        uint256 oldRate = feeRate;
        feeRate = newFeeRate;
        emit FeeRateUpdated(oldRate, newFeeRate);
    }
    
    /**
     * @dev 转移所有权
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
    
    // ==================== 辅助函数 ====================
    
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function sqrt(uint256 x) private pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
} 