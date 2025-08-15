// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SatoshiUSD} from "../../src/SatoshiUSD.sol";
import {SatoshiUSDEngine} from "../../src/SatoshiUSDEngine.sol";
import {DeploySatoshiUSD} from "../../script/DeploySatoshiUSD.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract TestSAUSDEngine is Test {
    SatoshiUSD saUSD;
    SatoshiUSDEngine saUSDE;
    DeploySatoshiUSD deployer;
    HelperConfig config;
    ERC20Mock btc;
    address wBTC;
    address btcUsdPriceFeed;
    uint256 deployKey;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 public constant BTC_DEPOSIT_AMOUNT = 1000;

    function setUp() public {
        deployer = new DeploySatoshiUSD();
        (saUSD, saUSDE, config) = deployer.run();
        (btcUsdPriceFeed, wBTC, deployKey) = config.activeNetworkConfig();

        btc = ERC20Mock(wBTC);

        btc.mint(alice, BTC_DEPOSIT_AMOUNT);
        btc.mint(bob, BTC_DEPOSIT_AMOUNT);
    }

    function testEngineSetUp() public view {
        assert(saUSDE.getBTC() == address(btc));
        assert(saUSDE.getBTCPriceFeed() == btcUsdPriceFeed);
    }

    // ------------------------------------------------------------------
    //                           PRICE TESTS
    // ------------------------------------------------------------------

    function testEngineGetUSDValue() public view {
        uint256 btcAmount = 1e18; // 1 BTC
        uint256 expectedUSDValue = 100_000e18; // As gotten from HelperConfig
        uint256 actualUSDValue = saUSDE.getUsdValue(btcAmount);

        assert(actualUSDValue == expectedUSDValue);
    }

    function testEngineGetBTCAmountFromUSD() public view {
        uint256 usdAmount = 50_000e18;
        uint256 expectedBTCAmount = 0.5e18;
        uint256 actualBTCAmount = saUSDE.getBTCAmountFromUSD(usdAmount);

        assert(expectedBTCAmount == actualBTCAmount);
    }

    // ------------------------------------------------------------------
    //                          DEPOSIT TESTS
    // ------------------------------------------------------------------

    function testEngineBTCZeroDepositReverts() public {
        vm.startPrank(alice);
        btc.approve(address(saUSDE), BTC_DEPOSIT_AMOUNT);
        vm.expectRevert(SatoshiUSDEngine.SUE__ZeroAmount.selector);
        saUSDE.depositBTC(0);
        vm.stopPrank();

        assert(btc.balanceOf(address(saUSDE)) == 0);
    }

    function testEngineBTCZeroDepositAndMintReverts() public {
        vm.startPrank(alice);
        btc.approve(address(saUSDE), BTC_DEPOSIT_AMOUNT);
        vm.expectRevert(SatoshiUSDEngine.SUE__ZeroAmount.selector);
        saUSDE.depositBTCAndMintsaUSD(0, 1);
        vm.stopPrank();

        assert(btc.balanceOf(address(saUSDE)) == 0);
        assert(saUSD.balanceOf(alice) == 0);
    }

    function testEngineDepositBTC() public {
        vm.startPrank(alice);
        btc.approve(address(saUSDE), BTC_DEPOSIT_AMOUNT);
        saUSDE.depositBTC(BTC_DEPOSIT_AMOUNT);
        vm.stopPrank();

        assert(btc.balanceOf(address(saUSDE)) == BTC_DEPOSIT_AMOUNT);
        assert(btc.balanceOf(alice) == 0);
    }
}
