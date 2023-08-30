// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UniPancake is Ownable, IFlashLoanRecipient {
    ISwapRouter internal constant uniswapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    ISwapRouter internal constant pancakeRouter = 
        ISwapRouter(0x1b81D678ffb9C0263b24A97847620C99d213eB14);
    IVault internal constant vault = 
        IVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    using SafeMath for uint256;

    struct SwapParams{
        bool direction;
        address token0;
        address token1;
        uint24 poolFeeU;
        uint24 poolFeeP;
        uint256 amountIn; 
    }

    function _swapU2P(
        address tokenIn,
        address tokenOut,
        uint24 poolFeeU,
        uint24 poolFeeP,
        uint256 amountIn
        ) internal returns (uint256) {

        ISwapRouter.ExactInputSingleParams memory paramsU = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFeeU,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        uint256 amountOut = uniswapRouter.exactInputSingle(paramsU);

        ISwapRouter.ExactInputSingleParams memory paramsP = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenOut,
                tokenOut: tokenIn,
                fee: poolFeeP,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountOut,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        return pancakeRouter.exactInputSingle(paramsP);
    }

    function _swapP2U(
        address tokenIn,
        address tokenOut,
        uint24 poolFeeU,
        uint24 poolFeeP,
        uint256 amountIn 
        ) internal returns (uint256) {

        ISwapRouter.ExactInputSingleParams memory paramsP = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFeeP,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        uint256 amountOut = pancakeRouter.exactInputSingle(paramsP);

        ISwapRouter.ExactInputSingleParams memory paramsU = 
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenOut,
                tokenOut: tokenIn,
                fee: poolFeeU,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountOut,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        return uniswapRouter.exactInputSingle(paramsU);
    }

    function approval(
        address _contract1,
        address _contract2,
        uint256 amounts ) external onlyOwner {
        IERC20(_contract1).approve(_contract2, amounts);
    }

    function routerApproval(
        address _erc20Token,
        uint256 amounts ) external onlyOwner {
            IERC20(_erc20Token).approve(0xE592427A0AEce92De3Edee1F18E0157C05861564, amounts);
            IERC20(_erc20Token).approve(0x1b81D678ffb9C0263b24A97847620C99d213eB14, amounts);
    }

    function checkBalance(address token) internal view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function withdraw(address token) external onlyOwner {
        IERC20(token).transferFrom(
            address(this),
            payable(msg.sender),
            checkBalance(token)
        );
    }

    function makeFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        bytes memory userData
    ) external onlyOwner{
        vault.flashLoan(this, tokens, amounts, userData);
        require(checkBalance(tokens[0]) > amounts[0] , "Less than");
    }

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == 0xBA12222222228d8Ba445958a75a0704d566BF2C8);
        
        SwapParams memory swapParams = abi.decode(userData, (SwapParams));

        if (swapParams.direction) {
            _swapU2P(
                swapParams.token0,
                swapParams.token1,
                swapParams.poolFeeU,
                swapParams.poolFeeP,
                amounts[0]
            );
        } else {
            _swapP2U(
                swapParams.token0,
                swapParams.token1,
                swapParams.poolFeeU,
                swapParams.poolFeeP,
                amounts[0]
            );
        }

        IERC20(tokens[0]).transfer(0xBA12222222228d8Ba445958a75a0704d566BF2C8, amounts[0]);
    }
}