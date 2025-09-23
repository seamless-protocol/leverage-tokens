// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// Dependency imports
import {IMorpho, Id} from "@morpho-blue/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Internal imports
import {ILeverageToken} from "src/interfaces/ILeverageToken.sol";
import {IntegrationTestUtils} from "../IntegrationTestUtils.t.sol";

contract IntegrationTestBase is IntegrationTestUtils {
    uint256 public constant FORK_BLOCK_NUMBER = 25473904;

    IERC20 public constant WETH = IERC20(0x4200000000000000000000000000000000000006);
    IERC20 public constant USDC = IERC20(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
    IMorpho public constant MORPHO = IMorpho(0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb);
    Id public constant WETH_USDC_MARKET_ID = Id.wrap(0x8793cf302b8ffd655ab97bd1c695dbd967807e8367a65cb2f4edaf1380ba1bda);
    Id public constant USDC_WETH_MARKET_ID = Id.wrap(0x3b3769cfca57be2eaed03fcc5299c25691b77781a1e124e7a8d520eb9a7eabb5);

    address public constant AUGUSTUS_REGISTRY = 0x7E31B336F9E8bA52ba3c4ac861b033Ba90900bb3;
    address public constant AUGUSTUS_V6_2 = 0x6A000F20005980200259B80c5102003040001068;

    address public constant LIFI_DIAMOND = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), FORK_BLOCK_NUMBER);

        _deployIntegrationTestContracts();
    }

    function testFork_setUp() public view virtual {
        assertEq(address(morphoLendingAdapter.leverageManager()), address(leverageManager));
        assertEq(address(morphoLendingAdapter.morpho()), address(MORPHO));
        assertEq(leverageManager.getTreasury(), treasury);
        assertEq(address(morphoLendingAdapter.getCollateralAsset()), address(WETH));
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
            minColRatio, targetCollateralRatio, maxColRatio, mintFee, redeemFee, WETH_USDC_MARKET_ID
        );
    }

    function _deployIntegrationTestContracts() internal {
        _deployIntegrationTestContracts(MORPHO, WETH_USDC_MARKET_ID, AUGUSTUS_REGISTRY);
    }
}
