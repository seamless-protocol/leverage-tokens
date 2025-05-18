// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// Forge imports
import {Test} from "forge-std/Test.sol";

// Dependency imports
import {IMorpho} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {LeverageRouterMintBase} from "src/periphery/LeverageRouterMintBase.sol";
import {ILeverageManager} from "src/interfaces/ILeverageManager.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract LeverageRouterMintBaseHarness is LeverageRouterMintBase, Test {
    event AdditionalData(bytes additionalData);

    IERC20 public collateralAsset;

    constructor(ILeverageManager _leverageManager, IMorpho _morpho, IERC20 _collateralAsset)
        LeverageRouterMintBase(_leverageManager, _morpho)
    {
        collateralAsset = _collateralAsset;
    }

    function exposed_mintAndRepayMorphoFlashLoan(MintParams memory params, uint256 collateralLoanAmount) external {
        // Mock the flash loan occuring beforehand
        deal(address(collateralAsset), address(this), collateralLoanAmount);

        _mintAndRepayMorphoFlashLoan(params, collateralLoanAmount);
    }

    function exposed_mint(MintParams memory params, uint256 collateralLoanAmount) external {
        // Mock the flash loan occuring beforehand
        deal(address(collateralAsset), address(this), collateralLoanAmount);

        _mint(params, collateralAsset, collateralLoanAmount);
    }

    function exposed_getCollateralFromDebt(
        IERC20 debtAsset,
        uint256 debtAmount,
        uint256 minCollateralAmount,
        bytes memory additionalData
    ) external returns (uint256) {
        return _getCollateralFromDebt(debtAsset, debtAmount, minCollateralAmount, additionalData);
    }

    /// @dev Dummy override to emit the additional data event and exchange the debt for collateral for testing purposes
    function _getCollateralFromDebt(
        IERC20 debtAsset,
        uint256 debtAmount,
        uint256 minCollateralAmount,
        bytes memory additionalData
    ) internal override returns (uint256) {
        super._getCollateralFromDebt(debtAsset, debtAmount, minCollateralAmount, additionalData);

        emit AdditionalData(additionalData);

        // Burn the debt to simulate exchanging it for collateral
        MockERC20(address(debtAsset)).burn(address(this), debtAmount);
        deal(address(collateralAsset), address(this), minCollateralAmount);

        return minCollateralAmount;
    }
}
