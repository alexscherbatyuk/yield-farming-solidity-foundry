// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

contract UniswapYieldFarmer {
    INonfungiblePositionManager public nftManager; // Uniswap V3 Position Manager
    IERC20 public token0;                          // First token in pair (e.g., USDC)
    IERC20 public token1;                          // Second token in pair (e.g., WETH)
    address public pool;                           // Uniswap V3 pool address
    address public owner;
    uint256 public tokenId;                        // NFT ID of the liquidity position
    int24 public tickLower;                        // Lower price range for position
    int24 public tickUpper;                        // Upper price range for position

    constructor(
        address _nftManager,
        address _token0,
        address _token1,
        address _pool,
        int24 _tickLower,
        int24 _tickUpper
    ) {
        nftManager = INonfungiblePositionManager(_nftManager);
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        pool = _pool;
        tickLower = _tickLower;
        tickUpper = _tickUpper;
        owner = msg.sender;
    }

    // Deposit tokens into Uniswap V3 pool as liquidity
    function depositToUniswap(uint256 amount0, uint256 amount1) external {
        require(msg.sender == owner, "Only owner");
        require(tokenId == 0, "Position already exists");

        // Transfer tokens from owner to contract
        require(token0.transferFrom(msg.sender, address(this), amount0), "Token0 transfer failed");
        require(token1.transferFrom(msg.sender, address(this), amount1), "Token1 transfer failed");

        // Approve NFT Manager to spend tokens
        token0.approve(address(nftManager), amount0);
        token1.approve(address(nftManager), amount1);

        // Mint liquidity position
        INonfungiblePositionManager.MintParams memory params = INonfungiblePositionManager.MintParams({
            token0: address(token0),
            token1: address(token1),
            fee: IUniswapV3Pool(pool).fee(), // Pool fee tier (e.g., 3000 for 0.3%)
            tickLower: tickLower,
            tickUpper: tickUpper,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0, // No slippage protection for simplicity
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp + 15 minutes
        });

        (uint256 _tokenId, , , ) = nftManager.mint(params);
        tokenId = _tokenId;
    }

    // Collect trading fees from the position
    function collectFees() external {
        require(msg.sender == owner, "Only owner");
        require(tokenId != 0, "No position exists");

        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max, // Collect all available fees
            amount1Max: type(uint128).max
        });

        (uint256 amount0, uint256 amount1) = nftManager.collect(params);
        if (amount0 > 0) token0.transfer(owner, amount0);
        if (amount1 > 0) token1.transfer(owner, amount1);
    }

    // Withdraw liquidity and collect remaining fees
    function withdrawFromUniswap() external {
        require(msg.sender == owner, "Only owner");
        require(tokenId != 0, "No position exists");

        // Collect any unclaimed fees first
        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this),
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });
        nftManager.collect(collectParams);

        // Burn position and withdraw liquidity
        (uint256 amount0, uint256 amount1) = nftManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams({
                tokenId: tokenId,
                liquidity: nftManager.positions(tokenId).liquidity,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp + 15 minutes
            })
        );

        // Transfer withdrawn tokens and fees to owner
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        if (balance0 > 0) token0.transfer(owner, balance0);
        if (balance1 > 0) token1.transfer(owner, balance1);

        // Burn the NFT
        nftManager.burn(tokenId);
        tokenId = 0; // Reset for reuse
    }

    // Check position details (liquidity, fees owed)
    function checkPosition() external view returns (uint128 liquidity, uint256 fee0, uint256 fee1) {
        if (tokenId == 0) return (0, 0, 0);
        ( , , , , , , , liquidity, , , fee0, fee1) = nftManager.positions(tokenId);
    }
}