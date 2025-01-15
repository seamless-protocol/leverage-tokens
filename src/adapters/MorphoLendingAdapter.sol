// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Dependency imports
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// Internal imports
import {ILendingAdapter} from "src/interfaces/ILendingAdapter.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {Id, IMorpho, MarketParams} from "src/interfaces/IMorpho.sol";
import {IMorphoLendingAdapter} from "src/interfaces/IMorphoLendingAdapter.sol";

contract MorphoLendingAdapter is IMorphoLendingAdapter, Initializable {
    /// @inheritdoc IMorphoLendingAdapter
    ILeverageManager public immutable leverageManager;

    /// @inheritdoc IMorphoLendingAdapter
    IMorpho public immutable morpho;

    /// @inheritdoc IMorphoLendingAdapter
    MarketParams public marketParams;

    /// @notice Creates a new Morpho lending adapter
    /// @param _leverageManager The Seamless ilm-v2 LeverageManager contract
    /// @param _morpho The Morpho core protocol contract
    constructor(ILeverageManager _leverageManager, IMorpho _morpho) {
        leverageManager = _leverageManager;
        morpho = _morpho;
    }

    /// @notice Initializes the Morpho lending adapter
    /// @param morphoMarketId The Morpho market ID
    function initialize(Id morphoMarketId) external initializer {
        marketParams = morpho.idToMarketParams(morphoMarketId);
    }

    /// @inheritdoc ILendingAdapter
    function getCollateral() external view returns (uint256 collateral) {
        // TODO: Implement this
        return block.timestamp;
    }

    /// @inheritdoc ILendingAdapter
    function getEquityInDebtAsset() external view returns (uint256 equity) {
        // TODO: Implement this
        return block.timestamp;
    }

    /// @inheritdoc ILendingAdapter
    function convertCollateralToDebtAsset(uint256 /* collateral */ ) external view returns (uint256 debt) {
        // TODO: Implement this
        return block.timestamp;
    }

    /// @inheritdoc ILendingAdapter
    function addCollateral(uint256 amount) external {
        IMorpho _morpho = morpho;

        MarketParams memory _marketParams = marketParams;

        // Transfer the collateral from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(_marketParams.collateralToken), msg.sender, address(this), amount);

        // Supply the collateral to the Morpho market
        IERC20(_marketParams.collateralToken).approve(address(_morpho), amount);
        _morpho.supplyCollateral(_marketParams, amount, address(this), hex"");
    }

    /// @inheritdoc ILendingAdapter
    function removeCollateral(uint256 amount) external onlyLeverageManager {
        // Withdraw the collateral from the Morpho market and send it to msg.sender
        morpho.withdrawCollateral(marketParams, amount, address(this), msg.sender);
    }

    /// @inheritdoc ILendingAdapter
    function borrow(uint256 amount) external onlyLeverageManager {
        // Borrow the debt asset from the Morpho market and send it to the caller
        morpho.borrow(marketParams, amount, 0, address(this), msg.sender);
    }

    /// @inheritdoc ILendingAdapter
    function repay(uint256 amount) external {
        IMorpho _morpho = morpho;

        MarketParams memory _marketParams = marketParams;

        // Transfer the debt asset from msg.sender to this contract
        SafeERC20.safeTransferFrom(IERC20(_marketParams.loanToken), msg.sender, address(this), amount);

        // Repay the debt asset to the Morpho market
        IERC20(_marketParams.loanToken).approve(address(_morpho), amount);
        _morpho.repay(_marketParams, amount, 0, address(this), hex"");
    }

    modifier onlyLeverageManager() {
        if (msg.sender != address(leverageManager)) revert Unauthorized();
        _;
    }
}
