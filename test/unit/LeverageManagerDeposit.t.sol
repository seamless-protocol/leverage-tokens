// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Forge imports
import {Test, console} from "forge-std/Test.sol";
import {stdStorage, StdStorage} from "forge-std/Test.sol";

// Dependency imports
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

// Internal imports
import {ILendingContract} from "src/interfaces/ILendingContract.sol";
import {LeverageManager} from "src/LeverageManager.sol";
import {LeverageManagerStorage as Storage} from "src/storage/LeverageManagerStorage.sol";
import {LeverageManagerBaseTest} from "./LeverageManagerBase.t.sol";

contract LeverageManagerDepositTest is LeverageManagerBaseTest {
    using stdStorage for StdStorage;

    bytes32 internal constant LEVERAGE_MANAGER_STORAGE_SLOT =
        0x326e20d598a681eb69bc11b5176604d340fccf9864170f09484f3c317edf3600;

    function setUp() public override {
        super.setUp();
    }

    // Define the struct for the test parameters for fuzz deposit test, all parameters are on uint128 to avoid overflows
    struct DepositFuzzTestParams {
        /// @dev Amount of collateral to deposit (leveraged amount)
        uint128 depositAmount;
        /// @dev Equity value in base asset that user will receive through shares
        uint128 depositEquity;
        /// @dev Amount of debt asset that will be borrowed and sent to user
        uint128 debtToReceive;
        /// @dev Total equity of the strategy before deposit
        uint128 prevTotalEquity;
        /// @dev Total shares in circulation before deposit
        uint128 prevTotalShares;
        /// @dev Shares of the user before deposit
        uint128 prevUserShares;
    }

    function testFuzz_deposit_FirstDeposit() public {
        // Create new strategy and configure collateral ratios
        (address strategy, address lendingContract, ERC20Mock collateralToken, ERC20Mock debtToken) =
            _createAndConfigureNewStrategy();

        // User deposits 5 ETH into ETH/USDC 2x
        uint128 depositAmount = 10 ether;
        uint128 depositEquityValue = 5 ether;
        uint128 debtToReceive = 5 ether;

        DepositFuzzTestParams memory params = DepositFuzzTestParams({
            depositAmount: depositAmount,
            depositEquity: depositEquityValue,
            debtToReceive: debtToReceive,
            prevTotalEquity: 0,
            prevTotalShares: 0,
            prevUserShares: 0
        });

        // Mock external contract calls and overrides storage
        _setUpStateAndMockExternalCalls(strategy, lendingContract, params);

        // Mint tokens to the user and mint debt token to leverage manager to simulate borrow
        collateralToken.mint(address(this), depositAmount);
        debtToken.mint(address(leverageManager), debtToReceive);

        // Deposit
        collateralToken.approve(address(leverageManager), depositAmount);
        leverageManager.deposit(strategy, depositAmount, address(this), 0);

        // Check that leveraged amount is properly transferred to leverage manager contract
        assertEq(collateralToken.balanceOf(address(this)), 0);
        assertEq(collateralToken.balanceOf(address(leverageManager)), depositAmount);

        // Check that caller received debt from leverage manager
        assertEq(debtToken.balanceOf(address(this)), debtToReceive);
        assertEq(debtToken.balanceOf(address(leverageManager)), 0);
    }

    function testFuzz_deposit(DepositFuzzTestParams memory params) public {
        // This test mocks all external calls that leverage manager makes to lending contract
        // This test also overrides storage of leverage manager to simulate state of the contract
        // Storage override is done by manually calculating storage slot and storing the value in that slot
        // Storage override is done to simulate that strategy already has some shares in circulation and user has some shares

        // Create new strategy and configure collateral ratios
        (address strategy, address lendingContract, ERC20Mock collateralToken, ERC20Mock debtToken) =
            _createAndConfigureNewStrategy();

        // Mock external contract calls and overrides storage
        _setUpStateAndMockExternalCalls(strategy, lendingContract, params);

        // Destruct params
        uint256 depositAmount = params.depositAmount;
        uint256 depositEquity = params.depositEquity;
        uint256 debtToReceive = params.debtToReceive;
        uint256 prevTotalShares = params.prevTotalShares;
        uint256 prevUserShares = params.prevUserShares;
        uint256 prevTotalEquity = params.prevTotalEquity;

        // Mint collateral token to the caller and mint debt token to LeverageManager to simulate borrowed assets
        collateralToken.mint(address(this), depositAmount);
        debtToken.mint(address(leverageManager), debtToReceive);

        collateralToken.approve(address(leverageManager), depositAmount);
        leverageManager.deposit(strategy, depositAmount, address(this), 0);

        // Check that the collateral tokens are transferred to the leverage manager
        assertEq(collateralToken.balanceOf(address(this)), 0);
        assertEq(collateralToken.balanceOf(address(leverageManager)), depositAmount);

        // Check that the debt tokens are transferred to the user
        assertEq(debtToken.balanceOf(address(this)), debtToReceive);
        assertEq(debtToken.balanceOf(address(leverageManager)), 0);

        // If _decimalsOffset() is changed in leverage contract this need to be changed also
        uint256 expectedShareIncrease = depositEquity * (prevTotalShares + 1) / (prevTotalEquity + 1);

        // Check that total supply of shares is properly increased and that user's balance of shares is properly increased also
        assertEq(leverageManager.getTotalStrategyShares(strategy), prevTotalShares + expectedShareIncrease);
        assertEq(leverageManager.getUserStrategyShares(strategy, address(this)), prevUserShares + expectedShareIncrease);
    }

    function _createAndConfigureNewStrategy()
        private
        returns (address strategy, address lendingContract, ERC20Mock collateral, ERC20Mock debt)
    {
        // Make addresses for lending contract to mock, strategy to deposit into and collateral ratio
        // None of this parameters are important for this test
        lendingContract = makeAddr("lendingContract");
        strategy = makeAddr("strategy");
        uint256 targetRatio = vm.randomUint();

        // Make addresses for collateral and debt tokens
        ERC20Mock collateralToken = new ERC20Mock();
        ERC20Mock debtToken = new ERC20Mock();

        // Manager sets up the strategy
        vm.startPrank(manager);

        leverageManager.setLendingContract(lendingContract);

        leverageManager.setStrategyCore(
            strategy, Storage.StrategyCore({collateral: address(collateralToken), debt: address(debtToken)})
        );
        // None of this parameters are important for this test because we are mocking all external calls
        leverageManager.setStrategyCollateralRatios(
            strategy,
            Storage.CollateralRatios({minForRebalance: 0, maxForRebalance: type(uint256).max, target: targetRatio})
        );

        vm.stopPrank();

        return (strategy, lendingContract, collateralToken, debtToken);
    }

    function _setUpStateAndMockExternalCalls(
        address strategy,
        address lendingContract,
        DepositFuzzTestParams memory params
    ) private {
        // Mock call that calculates how much debt should be borrowed and sent to user
        vm.mockCall(
            lendingContract,
            abi.encodeWithSelector(ILendingContract.convertCollateralToDebtAsset.selector),
            abi.encode(params.debtToReceive)
        );

        // Mock call that calculates equity of users deposit, equity value in base asset
        vm.mockCall(
            lendingContract,
            abi.encodeWithSelector(ILendingContract.convertCollateralToBaseAsset.selector),
            abi.encode(params.depositEquity)
        );

        // Mocks strategy equity prior to user's deposit
        vm.mockCall(
            lendingContract,
            abi.encodeWithSelector(ILendingContract.getStrategyEquityInBaseAsset.selector),
            abi.encode(params.prevTotalEquity)
        );

        // Mock total shares of a strategy in storage in leverage manager contract
        // Calculate the slot for totalShares[strategy]
        // Base slot for `totalShares` (offset = 2 from LEVERAGE_MANAGER_STORAGE_SLOT)
        uint256 baseSlot = uint256(LEVERAGE_MANAGER_STORAGE_SLOT) + 2;
        bytes32 slot = keccak256(abi.encode(strategy, baseSlot));
        vm.store(address(leverageManager), slot, bytes32(uint256(params.prevTotalShares)));

        // Validate that the state is set correctly
        assertEq(leverageManager.getTotalStrategyShares(strategy), params.prevTotalShares);

        // Mock user's shares in a strategy in storage in leverage manager contract
        // Calculate the slot for userShares[strategy][user]
        // Base slot for `userShares` (offset = 3 from LEVERAGE_MANAGER_STORAGE_SLOT)
        baseSlot = uint256(LEVERAGE_MANAGER_STORAGE_SLOT) + 3;
        slot = keccak256(abi.encode(address(this), keccak256(abi.encode(strategy, baseSlot))));
        vm.store(address(leverageManager), slot, bytes32(uint256(params.prevUserShares)));

        // Validate that the state is set correctly
        assertEq(leverageManager.getUserStrategyShares(strategy, address(this)), params.prevUserShares);
    }
}
