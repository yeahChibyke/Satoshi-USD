// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {SatoshiUSD, SatoshiUSDEngine} from "../src/SatoshiUSDEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeploySatoshiUSD is Script {
    SatoshiUSD saUSD;
    SatoshiUSDEngine saUSDE;
    HelperConfig helper;

    function run() external returns (SatoshiUSD, SatoshiUSDEngine, HelperConfig) {
        helper = new HelperConfig();
        (address btcUsdPriceFeed, address wBtc, uint256 deployerKey) = helper.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        saUSD = new SatoshiUSD();
        saUSDE = new SatoshiUSDEngine(wBtc, btcUsdPriceFeed, address(saUSD));
        saUSD.transferOwnership(address(saUSDE));
        vm.stopBroadcast();

        return (saUSD, saUSDE, helper);
    }
}
