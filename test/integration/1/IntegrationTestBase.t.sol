// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// Dependency imports
import {IMorpho, Id} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IntegrationTestUtils} from "../IntegrationTestUtils.t.sol";

contract IntegrationTestBase is IntegrationTestUtils {
    uint256 public constant FORK_BLOCK_NUMBER = 23290619;

    IERC20 public constant CBBTC = IERC20(0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf);
    IERC20 public constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IMorpho public constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    Id public constant CBBTC_USDC_MARKET_ID =
        Id.wrap(0x64d65c9a2d91c36d56fbc42d69e979335320169b3df63bf92789e2c8883fcc64);

    address public constant AUGUSTUS_REGISTRY = 0xa68bEA62Dc4034A689AA0F58A76681433caCa663;
    address public constant AUGUSTUS_V6_2 = 0x6A000F20005980200259B80c5102003040001068;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK_NUMBER);

        _deployIntegrationTestContracts();
    }

    function testFork_setUp() public view virtual {
        assertEq(address(morphoLendingAdapter.leverageManager()), address(leverageManager));
        assertEq(address(morphoLendingAdapter.morpho()), address(MORPHO));
        assertEq(leverageManager.getTreasury(), treasury);
        assertEq(address(morphoLendingAdapter.getCollateralAsset()), address(CBBTC));
        assertEq(address(morphoLendingAdapter.getDebtAsset()), address(USDC));

        assertEq(morphoLendingAdapter.getCollateral(), 0);
        assertEq(morphoLendingAdapter.getCollateralInDebtAsset(), 0);
        assertEq(morphoLendingAdapter.getDebt(), 0);
        assertEq(morphoLendingAdapter.getEquityInCollateralAsset(), 0);
        assertEq(morphoLendingAdapter.getEquityInDebtAsset(), 0);
    }

    function _createNewLeverageToken(
        uint256 minColRatio,
        uint256 targetCollateralRatio,
        uint256 maxColRatio,
        uint256 mintFee,
        uint256 redeemFee
    ) internal returns (ILeverageToken) {
        return _createNewLeverageToken(
            minColRatio, targetCollateralRatio, maxColRatio, mintFee, redeemFee, CBBTC_USDC_MARKET_ID
        );
    }

    function _deployIntegrationTestContracts() internal {
        _deployIntegrationTestContracts(MORPHO, CBBTC_USDC_MARKET_ID, AUGUSTUS_REGISTRY);
    }
}
