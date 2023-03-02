// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/aave/FlashLoanReceiverBase.sol";
import "./utils/aave/Interfaces.sol";

contract MHS is Ownable {
    ISwapRouter internal constant uniswapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    using SafeMath for uint256;

    address public router = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address tokenIn;
    address tokenSwap1;
    address tokenSwap2;
    uint24 fee1;
    uint24 fee2;
    uint24 fee3;

    function setContract(address _contract) external onlyOwner {
        tokenIn = _contract;
    }

    function approval(
        address _contract1,
        address _contract2,
        uint256 amounts
    ) external onlyOwner {
        IERC20(_contract1).approve(_contract2, amounts);
    }

    function checkBalance() internal view returns (uint256) {
        return IERC20(tokenIn).balanceOf(address(this));
    }

    function withdraw() public onlyOwner {
        IERC20(tokenIn).transferFrom(
            address(this),
            payable(msg.sender),
            checkBalance()
        );
    }

    function setParams(
        address token1,
        address token2,
        address token3,
        uint24 fee12,
        uint24 fee23,
        uint24 fee31
    ) external {
        tokenIn = token1;
        tokenSwap1 = token2;
        tokenSwap2 = token3;
        fee1 = fee12;
        fee2 = fee23;
        fee3 = fee31;
    }

    function _swap() internal returns (uint256 amountOut) {
        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: abi.encodePacked(
                    tokenIn,
                    fee1,
                    tokenSwap1,
                    fee2,
                    tokenSwap2,
                    fee3,
                    tokenIn
                ),
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: checkBalance(),
                amountOutMinimum: 0
            });
        amountOut = uniswapRouter.exactInput(params);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        _swap();

        for (uint256 i = 0; i < assets.length; i++) {
            uint256 amountOwing = amounts[i].add(premiums[i]);
            IERC20(assets[i]).approve(
                address(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9),
                amountOwing
            );
        }

        return true;
    }

    receive() external payable {}
}
