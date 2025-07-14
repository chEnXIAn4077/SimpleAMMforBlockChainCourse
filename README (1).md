# 简单AMM合约 (Simple AMM Contract)

这是一个基于Solidity的简单自动做市商（AMM）合约实现，支持Red Marble和Blue Marble两种代币的交换。

## 文件结构

```
├── SimpleAMM.sol      # 主AMM合约（包含便捷函数）
├── TestTokens.sol     # 测试代币合约 (decimals=6，便于操作)
└── README.md         # 说明文档
```

## 便捷操作方式 (推荐)

### 使用SimpleAMM内置的便捷函数
为了简化操作，避免输入大量零，我们在SimpleAMM中提供了便捷函数，名称以"Tokens"结尾，接收代币逻辑数量（而非实际存储数值）作为输入。

#### **铸币操作**
```solidity
// 使用TestTokens的便捷函数
RedMarble.mintTokens(userAddress, 1000);    // 铸造1000个RED
BlueMarble.mintTokens(userAddress, 1000);   // 铸造1000个BLUE

// 查看余额
RedMarble.balanceOfTokens(userAddress);     // 返回代币数量而非最小单位
```

#### **添加流动性**
```solidity
// 便捷方式：以代币为单位，自动计算滑点
SimpleAMM.addLiquidityTokens(100, 200, 5);  // 100 RED + 200 BLUE，5%滑点

// 传统方式：
// SimpleAMM.addLiquidity(100000000, 200000000, minLiquidity)
```

#### **移除流动性**
```solidity
// 便捷方式：以代币为单位
SimpleAMM.removeLiquidityTokens(lpTokens, 5);  // 移除LP代币，5%滑点

// 传统方式：
// SimpleAMM.removeLiquidity(lpTokens, minRed, minBlue)
```

#### **代币交换**
```solidity
// 便捷方式：以代币为单位
SimpleAMM.swapRedForBlueTokens(10, 3);  // 10个RED换BLUE，3%滑点
SimpleAMM.swapBlueForRedTokens(5, 3);   // 5个BLUE换RED，3%滑点

// 传统方式：
// SimpleAMM.swapRedForBlue(10000000, minBlueAmount)
```

#### **查询信息**
```solidity
// 便捷查询（返回代币数量）
SimpleAMM.getReservesTokens();              // 返回: (redTokens, blueTokens)
SimpleAMM.getUserLiquidityInfo(userAddress); // 返回: (lpTokens, redTokens, blueTokens)
SimpleAMM.getCurrentRate();                 // 返回汇率
SimpleAMM.previewSwapRedForBlueTokens(10);  // 预览10个RED能换多少BLUE
```

## 核心功能

### 1. 添加流动性 (Add Liquidity)
- **基础函数**: `addLiquidity(uint256 redAmount, uint256 blueAmount, uint256 minLiquidity)`
- **便捷函数**: `addLiquidityTokens(uint256 redTokens, uint256 blueTokens, uint256 slippagePercent)`
- **功能**: 向流动性池添加Red Marble和Blue Marble代币
- **返回**: LP代币作为流动性凭证

### 2. 移除流动性 (Remove Liquidity)
- **基础函数**: `removeLiquidity(uint256 liquidity, uint256 minRedAmount, uint256 minBlueAmount)`
- **便捷函数**: `removeLiquidityTokens(uint256 liquidityTokens, uint256 slippagePercent)`
- **功能**: 燃烧LP代币，按比例提取两种代币

### 3. 代币交换 (Swap)
- **基础函数**: 
  - `swapRedForBlue(uint256 redAmountIn, uint256 minBlueAmountOut)`
  - `swapBlueForRed(uint256 blueAmountIn, uint256 minRedAmountOut)`
- **便捷函数**:
  - `swapRedForBlueTokens(uint256 redTokens, uint256 slippagePercent)`
  - `swapBlueForRedTokens(uint256 blueTokens, uint256 slippagePercent)`
- **功能**: 基于恒定乘积公式进行代币交换