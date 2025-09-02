// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Dependency imports
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";

/**
 * @dev The LeverageToken contract is an upgradeable ERC20 token that represents a claim to the equity held by the LeverageToken.
 * It is used to represent a user's claim to the equity held by the LeverageToken in the LeverageManager.
 *
 * @custom:contact security@seamlessprotocol.com
 */
contract LeverageToken is
    Initializable,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    OwnableUpgradeable,
    ILeverageToken
{
    /// @inheritdoc ILeverageToken
    ILeverageManager public immutable leverageManager;

    constructor(ILeverageManager _leverageManager) {
        leverageManager = _leverageManager;
    }

    function initialize(address _owner, string memory _name, string memory _symbol) external initializer {
        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __Ownable_init(_owner);

        emit ILeverageToken.LeverageTokenInitialized(_name, _symbol);
    }

    /// @inheritdoc ILeverageToken
    function convertToAssets(uint256 shares) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            uint256 leverageTokenDecimals = decimals();
            uint256 collateralDecimals = IERC20Metadata(
                address(leverageManager.getLeverageTokenLendingAdapter(this).getCollateralAsset())
            ).decimals();

            if (collateralDecimals > leverageTokenDecimals) {
                uint256 scalingFactor = 10 ** (collateralDecimals - leverageTokenDecimals);
                return shares * scalingFactor;
            } else {
                uint256 scalingFactor = 10 ** (leverageTokenDecimals - collateralDecimals);
                return shares / scalingFactor;
            }
        }

        return Math.mulDiv(
            shares,
            leverageManager.getLeverageTokenLendingAdapter(this).getEquityInCollateralAsset(),
            _totalSupply,
            Math.Rounding.Floor
        );
    }

    /// @inheritdoc ILeverageToken
    function convertToShares(uint256 assets) public view returns (uint256) {
        uint256 _totalSupply = totalSupply();

        ILendingAdapter lendingAdapter = leverageManager.getLeverageTokenLendingAdapter(this);

        if (_totalSupply == 0) {
            uint256 leverageTokenDecimals = decimals();
            uint256 collateralDecimals = IERC20Metadata(address(lendingAdapter.getCollateralAsset())).decimals();

            if (collateralDecimals > leverageTokenDecimals) {
                uint256 scalingFactor = 10 ** (collateralDecimals - leverageTokenDecimals);
                return assets / scalingFactor;
            } else {
                uint256 scalingFactor = 10 ** (leverageTokenDecimals - collateralDecimals);
                return assets * scalingFactor;
            }
        }

        if (lendingAdapter.getEquityInCollateralAsset() == 0) {
            return 0;
        }

        return Math.mulDiv(
            assets,
            _totalSupply,
            leverageManager.getLeverageTokenLendingAdapter(this).getEquityInCollateralAsset(),
            Math.Rounding.Floor
        );
    }

    /// @inheritdoc ILeverageToken
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @inheritdoc ILeverageToken
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
