// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ERC20Token {
    string public name;
    string public symbol;
    uint8 public decimals = 18; 
    uint256 public totalSupply;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply * 10**decimals;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount * 10**decimals;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    //  便于测试的铸币函数（接受友好数值）
    function mint(address to, uint256 amount) public {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    //  友好的铸币函数（自动转换精度）
    function mintTokens(address to, uint256 tokenAmount) public {
        uint256 amount = tokenAmount * 10**decimals;
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
    
    //  友好的查询余额函数
    function balanceOfTokens(address account) public view returns (uint256) {
        return balanceOf[account] / 10**decimals;
    }
}

// Red Marble代币
contract RedMarble is ERC20Token {
    constructor() ERC20Token("Red Marble", "RED", 1000000) {
        // 初始供应量: 1,000,000 RED
    }
}

// Blue Marble代币
contract BlueMarble is ERC20Token {
    constructor() ERC20Token("Blue Marble", "BLUE", 1000000) {
        // 初始供应量: 1,000,000 BLUE
    }
} 