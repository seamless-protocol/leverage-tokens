// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockLiFi is Test {
    struct SwapParams {
        IERC20 fromToken;
        IERC20 toToken;
        uint256 fromAmount;
        uint256 toAmount;
    }

    SwapParams public swapParams;

    function mockNextLifiSwapCall(SwapParams memory _swapParams) external {
        swapParams = _swapParams;
    }

    fallback() external payable {
        return _handleCall();
    }

    receive() external payable {
        return _handleCall();
    }

    function _handleCall() internal {
        SwapParams memory _swapParams = swapParams;
        if (_swapParams.fromToken != IERC20(address(0))) {
            SafeERC20.safeTransferFrom(_swapParams.fromToken, msg.sender, address(this), _swapParams.fromAmount);

            deal(
                address(_swapParams.toToken),
                address(this),
                _swapParams.toToken.balanceOf(address(this)) + _swapParams.toAmount
            );
            SafeERC20.safeTransfer(_swapParams.toToken, msg.sender, _swapParams.toAmount);

            delete swapParams;
        } else {
            revert("MockLiFi: No swap data available");
        }
    }
}
