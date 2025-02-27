// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface ICERC20 {
    function mint(uint256 mintAmount) external returns (uint256);
    function redeem(uint256 redeemTokens) external returns (uint256);
    function balanceOf(address owner) external view returns (uint256);
    function exchangeRateStored() external view returns (uint256);
}

interface IComptroller {
    function claimComp(address holder) external;
    function compAccrued(address holder) external view returns (uint256);
}

contract CompoundYieldFarmer {
    ICERC20 public cToken;          
    IERC20 public underlyingToken;  
    IComptroller public comptroller;
    IERC20 public compToken;        // Added as a state variable
    address public owner;

    constructor(
        address _cToken, 
        address _underlyingToken, 
        address _comptroller, 
        address _compToken      // New parameter //0xc00e94Cb662C3520082E9755463369f410B67b24
    ) {
        cToken = ICERC20(_cToken);
        underlyingToken = IERC20(_underlyingToken);
        comptroller = IComptroller(_comptroller);
        compToken = IERC20(_compToken); // Set once at deployment
        owner = msg.sender;
    }

    function depositToCompound(uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        require(underlyingToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        underlyingToken.approve(address(cToken), amount);
        require(cToken.mint(amount) == 0, "Mint failed");
    }

    function withdrawFromCompound(uint256 cTokenAmount) external {
        require(msg.sender == owner, "Only owner");
        require(cToken.redeem(cTokenAmount) == 0, "Redeem failed");
        uint256 balance = underlyingToken.balanceOf(address(this));
        require(underlyingToken.transfer(owner, balance), "Transfer failed");
    }

    // Claim COMP rewards (if any)
    function claimCompRewards() external {
        require(msg.sender == owner, "Only owner");
        comptroller.claimComp(address(this));
        uint256 compBalance = compToken.balanceOf(address(this));
        if (compBalance > 0) {
            compToken.transfer(owner, compBalance);
        }
    }

    function checkTotalBalance() external view returns (uint256) {
        uint256 cTokenBalance = cToken.balanceOf(address(this));
        uint256 exchangeRate = cToken.exchangeRateStored();
        return (cTokenBalance * exchangeRate) / 1e18;
    }

    function checkCompRewards() external view returns (uint256) {
        return comptroller.compAccrued(address(this));
    }
}