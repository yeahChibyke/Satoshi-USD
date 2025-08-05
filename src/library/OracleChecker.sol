// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * ██████╗ ██████╗  █████╗  ██████╗██╗     ███████╗     ██████╗██╗  ██╗███████╗ ██████╗██╗  ██╗███████╗██████╗
 * ██╔═══██╗██╔══██╗██╔══██╗██╔════╝██║     ██╔════╝    ██╔════╝██║  ██║██╔════╝██╔════╝██║ ██╔╝██╔════╝██╔══██╗
 * ██║   ██║██████╔╝███████║██║     ██║     █████╗      ██║     ███████║█████╗  ██║     █████╔╝ █████╗  ██████╔╝
 * ██║   ██║██╔══██╗██╔══██║██║     ██║     ██╔══╝      ██║     ██╔══██║██╔══╝  ██║     ██╔═██╗ ██╔══╝  ██╔══██╗
 * ╚██████╔╝██║  ██║██║  ██║╚██████╗███████╗███████╗    ╚██████╗██║  ██║███████╗╚██████╗██║  ██╗███████╗██║  ██║
 *  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚══════╝     ╚═════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
 */

/**
 * @title: Oracle Checker
 * @author: Chukwubuike Victory Chime GH/Twitter: @yeahChibyke
 * @dev: This library is used to query the Chainlink oracle for stale data. It is designed such that if a price is stale, the function wil revert and the SatoshiUSDEngine will be rendered unusable
 * @notice: If the Chainlink network is attacked, all user funds locked in the protocol will result in a state of 😬😱
 */

// ------------------------------------------------------------------
//                             IMPORTS
// ------------------------------------------------------------------
import {AggregatorV3Interface} from "chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// ------------------------------------------------------------------
//                             LIBRARY
// ------------------------------------------------------------------
library OracleChecker {
    // ------------------------------------------------------------------
    //                              ERROR
    // ------------------------------------------------------------------
    error OracleChecker__StaleData();

    // ------------------------------------------------------------------
    //                             STORAGE
    // ------------------------------------------------------------------
    uint256 private constant s_TIMEOUT = 60 seconds;

    // ------------------------------------------------------------------
    //                        INTERNAL FUNCTION
    // ------------------------------------------------------------------
    function staleDataCheck(AggregatorV3Interface priceFeed)
        internal
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            priceFeed.latestRoundData();

        uint256 secondsSince = block.timestamp - updatedAt;

        if (secondsSince > s_TIMEOUT) revert OracleChecker__StaleData();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
