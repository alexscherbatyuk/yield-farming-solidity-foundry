// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "aave-v3-core/contracts/interfaces/IPool.sol";


contract AaveYieldFarmer {
    IPool public aavePool; // Aave V3 Pool contract
    IERC20 public token;   // The token to deposit (e.g., USDC)
    address public owner;

    constructor(address _aavePool, address _token) {
        aavePool = IPool(_aavePool);
        token = IERC20(_token);
        owner = msg.sender;
    }

    function depositToAave(uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        token.approve(address(aavePool), amount);
        aavePool.supply(address(token), amount, address(this), 0);
    }

    function withdrawFromAave(uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        aavePool.withdraw(address(token), amount, address(this));
        token.transfer(owner, amount);
    }

    // Check aToken balance (your deposit + interest)
    function checkRewards() external view returns (uint256) {
        return IERC20(aavePool.getReserveData(address(token)).aTokenAddress).balanceOf(address(this));
    }
}