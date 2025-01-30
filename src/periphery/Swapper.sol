// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Internal imports
import {ISwapper} from "../interfaces/ISwapper.sol";
import {SwapperStorage as Storage} from "../storage/SwapperStorage.sol";

contract Swapper is ISwapper, Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    function initialize(address initialAdmin) external initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, initialAdmin);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    /// @inheritdoc ISwapper
    function getLifi() external view returns (address lifi) {
        return Storage.layout().lifi;
    }

    /// @inheritdoc ISwapper
    function getProvider() external view returns (ISwapper.Provider provider) {
        return Storage.layout().provider;
    }

    /// @inheritdoc ISwapper
    function setLifi(address lifi) external onlyRole(MANAGER_ROLE) {
        Storage.layout().lifi = lifi;
    }

    /// @inheritdoc ISwapper
    function setProvider(ISwapper.Provider provider) external onlyRole(MANAGER_ROLE) {
        Storage.layout().provider = provider;
    }

    /// @inheritdoc ISwapper
    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes calldata providerSwapData
    ) external returns (uint256 toAmount) {
        SafeERC20.safeTransferFrom(fromToken, msg.sender, address(this), fromAmount);
        return _swapLiFi(fromToken, toToken, fromAmount, minToAmount, providerSwapData);
    }

    /// @notice Swap tokens using LiFi
    /// @param fromToken Token to swap from
    /// @param toToken Token to swap to
    /// @param fromAmount Amount of tokens to swap
    /// @param minToAmount Minimum expected amount of tokens to receive
    /// @param providerSwapData Encoded swap data to use for the swap using the provider
    function _swapLiFi(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        uint256 minToAmount,
        bytes calldata providerSwapData
    ) internal returns (uint256) {
        address lifi = Storage.layout().lifi;
        fromToken.approve(lifi, fromAmount);
        (bool success,) = lifi.call{value: msg.value}(providerSwapData);

        if (!success) {
            revert SwapFailed();
        }

        uint256 toAmount = toToken.balanceOf(address(this));
        if (toAmount < minToAmount) {
            revert SlippageTooHigh(toAmount, minToAmount);
        } else {
            return toAmount;
        }
    }
}
