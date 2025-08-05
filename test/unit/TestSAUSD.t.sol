// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SatoshiUSD} from "../../src/SatoshiUSD.sol";

contract TestSAUSD is Test {
    SatoshiUSD saUSD;

    address owner;
    address user;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");

        vm.prank(owner);
        saUSD = new SatoshiUSD();
    }

    function testSetUp() public view {
        assertEq(saUSD.name(), "SatoshiUSD");
        assertEq(saUSD.symbol(), "saUSD");
        assert(saUSD.decimals() == 6);
    }

    function testsaUSDMintSuccessful() public {
        vm.prank(owner);
        saUSD.mint(user, 1_000);

        assert(saUSD.balanceOf(user) == 1_000);
    }

    function testsaUSDMintZeroAmountFail() public {
        vm.prank(owner);
        vm.expectRevert(SatoshiUSD.SAUSD__ZeroAmount.selector);
        saUSD.mint(user, 0);

        assert(saUSD.balanceOf(user) == 0);
    }

    function testsaUSDMintZeroAddressFail() public {
        vm.prank(owner);
        vm.expectRevert(SatoshiUSD.SAUSD__ZeroAddress.selector);
        saUSD.mint(address(0), 1_000);
    }

    function testsaUSDBurnSuccessful() public {
        _minted();

        uint256 balPreBurn = saUSD.balanceOf(user);

        vm.prank(user);
        saUSD.burn(1_000);

        uint256 balPostBurn = saUSD.balanceOf(user);

        assert(balPreBurn > balPostBurn);
    }

    function testsaUSDBurnMoreThanBalanceFail() public {
        _minted();

        uint256 balPreBurn = saUSD.balanceOf(user);

        vm.prank(user);
        vm.expectRevert(SatoshiUSD.SAUSD__BalanceExceeded.selector);
        saUSD.burn(10_000);

        uint256 balPostburn = saUSD.balanceOf(user);

        assert(balPreBurn == balPostburn);
    }

    function testsaUSDBurnZeroFail() public {
        _minted();

        uint256 balPreBurn = saUSD.balanceOf(user);

        vm.prank(user);
        vm.expectRevert(SatoshiUSD.SAUSD__ZeroAmount.selector);
        saUSD.burn(0);

        uint256 balPostBurn = saUSD.balanceOf(user);

        assert(balPostBurn == balPreBurn);
    }

    function _minted() public {
        vm.prank(owner);
        saUSD.mint(user, 1_000);
    }
}
