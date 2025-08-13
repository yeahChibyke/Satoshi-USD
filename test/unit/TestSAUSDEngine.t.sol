// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {SatoshiUSD} from "../../src/SatoshiUSD.sol";
import {SatoshiUSDEngine} from "../../src/SatoshiUSDEngine.sol";
import {DeploySatoshiUSD} from "../../script/DeploySatoshiUSD.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockBTC} from "../mocks/MockBTC.sol";

contract TestSAUSDEngine is Test {
    SatoshiUSD saUSD;
    SatoshiUSDEngine saUSDE;
    DeploySatoshiUSD deployer;
    HelperConfig config;
    address wBTC;
    address btcUsdPriceFeed;
    uint256 deployKey;

    address user = makeAddr("user");

    function setUp() public {
        deployer = new DeploySatoshiUSD();
        (saUSD, saUSDE, config) = deployer.run();
        (btcUsdPriceFeed, wBTC, deployKey) = config.activeNetworkConfig();

        MockBTC(wBTC).mint(user, 1000);
    }

    function testEngineSetUp() public view {
        assert(saUSDE.getBTC() == wBTC);
        assert(saUSDE.getBTCPriceFeed() == btcUsdPriceFeed);
    }

    // ------------------------------------------------------------------
    //                           PRICE TESTS
    // ------------------------------------------------------------------

    function testEngineUsdValue() public view {
        console2.log(saUSDE.getBTCAmountFromUSD(100_000));
    }
}
