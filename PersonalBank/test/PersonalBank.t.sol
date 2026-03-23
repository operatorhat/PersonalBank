// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PersonalBank} from "../src/PersonalBank.sol";

contract MockAavePool {
    bool public shouldRevert;

    address public lastSupplyAsset;
    uint256 public lastSupplyAmount;
    address public lastSupplyOnBehalfOf;

    address public lastWithdrawAsset;
    uint256 public lastWithdrawAmount;
    address public lastWithdrawTo;

    function setRevert(bool _revert) external {
        shouldRevert = _revert;
    }

    function supply(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16
    ) external {
        if (shouldRevert) revert("mock: supply failed");
        lastSupplyAsset = asset;
        lastSupplyAmount = amount;
        lastSupplyOnBehalfOf = onBehalfOf;
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256) {
        if (shouldRevert) revert("mock: withdraw failed");
        lastWithdrawAsset = asset;
        lastWithdrawAmount = amount;
        lastWithdrawTo = to;
        return amount;
    }
}

contract MockERC20 {
    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function balanceOf(address) external pure returns (uint256) {
        return type(uint256).max;
    }
}

contract MockERC20FalseApprove {
    function approve(address, uint256) external pure returns (bool) {
        return false;
    }
}

contract MockERC20Weird {
    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address, uint256) external pure returns (bool) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool) {
        return true;
    }

    function balanceOf(address) external pure returns (uint256) {
        return type(uint256).max;
    }
}

contract PersonalBankTest is Test {
    PersonalBank internal bank;
    MockAavePool internal pool;
    MockERC20 internal token;

    address internal owner;
    address internal stranger;

    function setUp() public {
        owner = makeAddr("owner");
        stranger = makeAddr("stranger");

        pool = new MockAavePool();
        token = new MockERC20();

        vm.prank(owner);
        bank = new PersonalBank(address(pool));
    }

    function test_constructor_ZeroPool_RevertsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(PersonalBank.ZeroAddress.selector);
        new PersonalBank(address(0));
    }

    function test_constructor_ValidPool_SetsOwner() public view {
        assertEq(bank.OWNER(), owner);
    }

    function test_constructor_ValidPool_SetsAavePool() public view {
        assertEq(address(bank.aavePool()), address(pool));
    }

    function test_supply_NonOwner_RevertsNotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(PersonalBank.NotOwner.selector);
        bank.supply(address(token), 1e18);
    }

    function test_withdraw_NonOwner_RevertsNotOwner() public {
        vm.prank(stranger);
        vm.expectRevert(PersonalBank.NotOwner.selector);
        bank.withdraw(address(token), 1e18);
    }

    function test_setAavePool_NonOwner_RevertsNotOwner() public {
        address newPool = makeAddr("newPool");
        vm.prank(stranger);
        vm.expectRevert(PersonalBank.NotOwner.selector);
        bank.setAavePool(newPool);
    }

    function test_supply_ZeroAmount_RevertsZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(PersonalBank.ZeroAmount.selector);
        bank.supply(address(token), 0);
    }

    function test_withdraw_ZeroAmount_RevertsZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(PersonalBank.ZeroAmount.selector);
        bank.withdraw(address(token), 0);
    }

    function test_supply_ValidCall_ApprovesAndCallsAave() public {
        vm.prank(owner);
        bank.supply(address(token), 1e18);

        assertEq(pool.lastSupplyAsset(), address(token));
        assertEq(pool.lastSupplyAmount(), 1e18);
        assertEq(pool.lastSupplyOnBehalfOf(), address(bank));
        assertEq(token.allowance(address(bank), address(pool)), 1e18);
    }

    function test_supply_ExactApproval_NotInfinite() public {
        vm.prank(owner);
        bank.supply(address(token), 500);

        assertEq(token.allowance(address(bank), address(pool)), 500);
        assertTrue(token.allowance(address(bank), address(pool)) != type(uint256).max);
    }

    function test_supply_EmitsSupplied() public {
        vm.expectEmit(true, false, false, true);
        emit PersonalBank.Supplied(address(token), 1e18);

        vm.prank(owner);
        bank.supply(address(token), 1e18);
    }

    function test_withdraw_CallsAaveToThis() public {
        vm.prank(owner);
        bank.withdraw(address(token), 1e18);

        assertEq(pool.lastWithdrawAsset(), address(token));
        assertEq(pool.lastWithdrawAmount(), 1e18);
        assertEq(pool.lastWithdrawTo(), address(bank));
    }

    function test_withdraw_MaxUint_FullExit() public {
        vm.prank(owner);
        bank.withdraw(address(token), type(uint256).max);

        assertEq(pool.lastWithdrawAsset(), address(token));
        assertEq(pool.lastWithdrawAmount(), type(uint256).max);
        assertEq(pool.lastWithdrawTo(), address(bank));
    }

    function test_withdraw_EmitsWithdrawn() public {
        vm.expectEmit(true, false, false, true);
        emit PersonalBank.Withdrawn(address(token), 1e18);

        vm.prank(owner);
        bank.withdraw(address(token), 1e18);
    }

    function test_setAavePool_RejectsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(PersonalBank.ZeroAddress.selector);
        bank.setAavePool(address(0));
    }

    function test_setAavePool_UpdatesStorage() public {
        address newPool = makeAddr("newPool");

        vm.prank(owner);
        bank.setAavePool(newPool);

        assertEq(address(bank.aavePool()), newPool);
    }

    function test_setAavePool_EmitsAavePoolUpdated() public {
        address newPool = makeAddr("newPool");

        vm.expectEmit(true, false, false, true);
        emit PersonalBank.AavePoolUpdated(newPool);

        vm.prank(owner);
        bank.setAavePool(newPool);
    }

    function test_supply_AfterPoolUpdate_UsesNewPool() public {
        MockAavePool newPool = new MockAavePool();

        vm.prank(owner);
        bank.setAavePool(address(newPool));

        vm.prank(owner);
        bank.supply(address(token), 1e18);

        assertEq(newPool.lastSupplyAsset(), address(token));
        assertEq(newPool.lastSupplyAmount(), 1e18);
        assertEq(newPool.lastSupplyOnBehalfOf(), address(bank));
        assertEq(token.allowance(address(bank), address(newPool)), 1e18);
        assertEq(token.allowance(address(bank), address(pool)), 0);
    }

    function test_setAavePool_SameAddress_NoChange() public {
        vm.prank(owner);
        bank.setAavePool(address(pool));

        assertEq(address(bank.aavePool()), address(pool));
    }

    function test_supply_RevertPropagatesAaveError() public {
        pool.setRevert(true);

        vm.prank(owner);
        vm.expectRevert(bytes("mock: supply failed"));
        bank.supply(address(token), 1e18);
    }

    function test_withdraw_RevertPropagatesAaveError() public {
        pool.setRevert(true);

        vm.prank(owner);
        vm.expectRevert(bytes("mock: withdraw failed"));
        bank.withdraw(address(token), 1e18);
    }

    function test_supply_ApproveFalse_DoesNotRevertInMockButIsRisky() public {
        MockERC20FalseApprove badToken = new MockERC20FalseApprove();

        vm.prank(owner);
        bank.supply(address(badToken), 1e18);
    }

    function test_supply_WeirdToken_DoesNotBreakForwarding() public {
        MockERC20Weird weird = new MockERC20Weird();

        vm.prank(owner);
        bank.supply(address(weird), 123);

        assertEq(weird.allowance(address(bank), address(pool)), 123);
        assertEq(pool.lastSupplyAsset(), address(weird));
        assertEq(pool.lastSupplyAmount(), 123);
        assertEq(pool.lastSupplyOnBehalfOf(), address(bank));
    }
}
