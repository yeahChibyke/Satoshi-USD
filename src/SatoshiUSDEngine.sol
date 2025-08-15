// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

/**
 * ███████╗ █████╗ ████████╗ ██████╗ ███████╗██╗  ██╗██╗    ██╗   ██╗███████╗██████╗     ███████╗███╗   ██╗ ██████╗ ██╗███╗   ██╗███████╗
 * ██╔════╝██╔══██╗╚══██╔══╝██╔═══██╗██╔════╝██║  ██║██║    ██║   ██║██╔════╝██╔══██╗    ██╔════╝████╗  ██║██╔════╝ ██║████╗  ██║██╔════╝
 * ███████╗███████║   ██║   ██║   ██║███████╗███████║██║    ██║   ██║███████╗██║  ██║    █████╗  ██╔██╗ ██║██║  ███╗██║██╔██╗ ██║█████╗
 * ╚════██║██╔══██║   ██║   ██║   ██║╚════██║██╔══██║██║    ██║   ██║╚════██║██║  ██║    ██╔══╝  ██║╚██╗██║██║   ██║██║██║╚██╗██║██╔══╝
 * ███████║██║  ██║   ██║   ╚██████╔╝███████║██║  ██║██║    ╚██████╔╝███████║██████╔╝    ███████╗██║ ╚████║╚██████╔╝██║██║ ╚████║███████╗
 * ╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═════╝ ╚══════╝╚═════╝     ╚══════╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚══════╝
 */

/**
 * @title: Satoshi USD Engine (SUE)
 * @author: Chukwubuike Victory Chime GH/Twitter: @yeahChibyke
 * @notice: This contract is the core of the Satoshi USD system. It handles all the logic for minting and redeeming saUSD, as well as depositing and withdrawing collateral
 * @notice: The SUE is designed to be as minimal as possible, and ensure the maintenance of 1 saUSD == 1 USD at all times
 * @dev: The system should always be "overcollateralized", at no point should the value of all collateral be less than the USD value of all minted saUSD
 * @dev: This contract is based on the MakerDAO DSS system; it is similar to DAI if DAI had no governance, no fees, and was backed by only wBTC
 */

// ------------------------------------------------------------------
//                             IMPORTS
// ------------------------------------------------------------------
import {SatoshiUSD} from "./SatoshiUSD.sol";
import {OracleChecker} from "./library/OracleChecker.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AggregatorV3Interface} from "chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// ------------------------------------------------------------------
//                             CONTRACT
// ------------------------------------------------------------------
contract SatoshiUSDEngine is ReentrancyGuard {
    // ------------------------------------------------------------------
    //                              ERRORS
    // ------------------------------------------------------------------
    error SUE__ZeroAmount();
    error SUE__ZeroAddress();
    error SUE__NotAllowedToken();
    error SUE__TransferFailed();
    error SUE__HealthFactorIsBroken(uint256 healthFactor);
    error SUE__MintFailed();
    error SUE__RedeemFailed();
    error SUE__HealthFactorIsHealthy();
    error SUE__HealthFactorNotImproved();

    // ------------------------------------------------------------------
    //                               TYPE
    // ------------------------------------------------------------------
    using OracleChecker for AggregatorV3Interface;

    // ------------------------------------------------------------------
    //                             STORAGE
    // ------------------------------------------------------------------
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private LIQUIDATION_BONUS = 10; // This mean a 10% bonus

    mapping(address btc => address priceFeed) private s_priceFeed;
    mapping(address user => mapping(address btc => uint256 amount)) private s_btcDeposited;
    mapping(address user => uint256 amountOfSAUSDMinted) private s_saUSDMinted;

    SatoshiUSD private immutable i_saUSD;
    IERC20Metadata private immutable i_BTC;

    // ------------------------------------------------------------------
    //                              EVENTS
    // ------------------------------------------------------------------
    event BTCDeposited(address indexed user, uint256 indexed amount);
    event BTCRedeemed(address indexed redeemedFrom, address indexed redeemedTo, uint256 indexed amount);

    // ------------------------------------------------------------------
    //                             MODIFIER
    // ------------------------------------------------------------------
    modifier cannotbeZero(uint256 _amount) {
        if (_amount == 0) {
            revert SUE__ZeroAmount();
        }
        _;
    }

    // ------------------------------------------------------------------
    //                           CONSTRUCTOR
    // ------------------------------------------------------------------
    constructor(address _btc, address _btc_usdPriceFeed, address _saUSD) {
        if (_btc == address(0) || _btc_usdPriceFeed == address(0) || _saUSD == address(0)) {
            revert SUE__ZeroAddress();
        }

        i_BTC = IERC20Metadata(_btc);

        s_priceFeed[_btc] = _btc_usdPriceFeed;

        i_saUSD = SatoshiUSD(_saUSD);
    }

    // ------------------------------------------------------------------
    //                        EXTERNAL FUNCTIONS
    // ------------------------------------------------------------------

    /**
     * @notice and @dev This function will deposit `BTC` and mint `saUSD` in one transaction
     * @param _btcAmount: Amount of `BTC` being deposited
     * @param _amountOfsaUSDToMint: Amount of `saUSD` to mint in return
     */
    function depositBTCAndMintsaUSD(uint256 _btcAmount, uint256 _amountOfsaUSDToMint)
        external
        cannotbeZero(_btcAmount)
    {
        depositBTC(_btcAmount);
        mintsaUSD(_amountOfsaUSDToMint);
    }

    /**
     * @notice and @dev This function will burn `saSUD` and redeem `BTC` in one transaction
     * @param amountToRedeem: Amount of `BTC` to redeem
     * @param _amountOfsaUSDToBurn: Amount of `saUSD` to be burnt in return
     */
    function redeemBTCForsaUSD(uint256 amountToRedeem, uint256 _amountOfsaUSDToBurn)
        external
        cannotbeZero(amountToRedeem)
    {
        _burnsaUSD(_amountOfsaUSDToBurn, msg.sender, msg.sender);
        _redeemBTC(amountToRedeem, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice and @dev This function will redeem specified amount of `BTC` when called
     * @param _amountOfBTCToRedeem: Amount of `BTC` to be redeemed
     */
    function redeemBTC(uint256 _amountOfBTCToRedeem) public cannotbeZero(_amountOfBTCToRedeem) nonReentrant {
        _redeemBTC(_amountOfBTCToRedeem, msg.sender, msg.sender);

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice and @dev This function will burn the specified amount of `saUSD`
     * @param _amountOfsaUSDToBurn: The amount of `saUSD` to be burnt
     */
    function burnsaUSD(uint256 _amountOfsaUSDToBurn) public cannotbeZero(_amountOfsaUSDToBurn) {
        _burnsaUSD(_amountOfsaUSDToBurn, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // likelihood of this happening is very very unlikely
    }

    /**
     * @notice and @dev A user can be partially liquidated
     * @notice and @dev There is a liquidation bonus for liquidating a user
     * @notice and @dev The protocol has to be 200% over-collaterized for this function to work
     * @param user: Address of the user to be liquidated. Their `_healthFactor` must be lower than `MIN_HEALTH_FACTOR`
     * @param debtToCover: Amount of `saUSD` to be burnt to improve `user` health factor
     */
    function liquidate(address user, uint256 debtToCover) external cannotbeZero(debtToCover) nonReentrant {
        // check to see that `user` is in fact liquidatable
        uint256 initialUserHealthFactor = _healthFactor(user);
        if (initialUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SUE__HealthFactorIsHealthy();
        }

        // We need to know the USD equivalent of debt to be covered.
        //      E.g. If covering 100 of saUSD, we need to know what the BTC equivalent of that debt is
        uint256 tokenAmountFromDebtCovered = getBTCAmountFromUSD(debtToCover);

        // We also want to give liquidators a 10% bonus
        //      i.e., They are getting 110 wBTC for 100 saUSD
        uint256 bonusBTC = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalBTCToRedeem = bonusBTC + tokenAmountFromDebtCovered;

        _redeemBTC(totalBTCToRedeem, user, msg.sender);
        _burnsaUSD(debtToCover, user, msg.sender);

        uint256 finalUserHealthFactor = _healthFactor(user);
        // This condition should never hit, but no harm in being too careful
        if (finalUserHealthFactor <= initialUserHealthFactor) {
            revert SUE__HealthFactorNotImproved();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // ------------------------------------------------------------------
    //                         PUBLIC FUNCTIONS
    // ------------------------------------------------------------------

    /**
     * @notice and @dev This function will deposit `BTC` when called
     * @param _btcAmount: Amount of `BTC` to deposit
     */
    function depositBTC(uint256 _btcAmount) public cannotbeZero(_btcAmount) nonReentrant {
        s_btcDeposited[msg.sender][address(i_BTC)] += _btcAmount;

        emit BTCDeposited(msg.sender, _btcAmount);

        bool transferSuccessful = IERC20(i_BTC).transferFrom(msg.sender, address(this), _btcAmount);
        if (!transferSuccessful) {
            revert SUE__TransferFailed();
        }
    }

    /**
     * @notice and @dev This function wil mint `saUSD` when called
     * @param _amountOfsaUSDToMint: Amount of `saUSD` to mint
     */
    function mintsaUSD(uint256 _amountOfsaUSDToMint) public cannotbeZero(_amountOfsaUSDToMint) nonReentrant {
        s_saUSDMinted[msg.sender] += _amountOfsaUSDToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool mintSuccessful = i_saUSD.mint(msg.sender, _amountOfsaUSDToMint);

        if (!mintSuccessful) {
            revert SUE__MintFailed();
        }
    }

    // ------------------------------------------------------------------
    //                        PRIVATE FUNCTIONS
    // ------------------------------------------------------------------

    function _redeemBTC(uint256 _btcAmount, address from, address to) private {
        s_btcDeposited[from][address(i_BTC)] -= _btcAmount;
        emit BTCRedeemed(from, to, _btcAmount);

        bool redeemSuccessful = IERC20(i_BTC).transfer(to, _btcAmount);
        if (!redeemSuccessful) {
            revert SUE__RedeemFailed();
        }
    }

    function _burnsaUSD(uint256 _amountsaUSDToBurn, address onBehalfOf, address _saUSDFrom) private {
        s_saUSDMinted[onBehalfOf] -= _amountsaUSDToBurn;

        bool success = i_saUSD.transferFrom(_saUSDFrom, address(this), _amountsaUSDToBurn);
        if (!success) {
            revert SUE__TransferFailed();
        }

        i_saUSD.burn(_amountsaUSDToBurn);
    }

    // ------------------------------------------------------------------
    //               PRIVATE AND INTERNAL VIEW FUNCTIONS
    // ------------------------------------------------------------------

    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalsaUSDMinted, uint256 btcValueInUSD)
    {
        totalsaUSDMinted = s_saUSDMinted[user];
        btcValueInUSD = getAccountBTCValue(user);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalsaUSDMinted, uint256 btcValueInUSD) = _getAccountInformation(user);
        return _calculateHealthFactor(totalsaUSDMinted, btcValueInUSD);
    }

    function _getUsdValue(uint256 amount) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[address(i_BTC)]);
        (, int256 answer,,,) = priceFeed.staleDataCheck();
        // Most USD pairs have 8 decimals, so we will assume they all do
        // We want to have everything in terms of wei, so we add 10 zeros at the end
        return ((uint256(answer) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _calculateHealthFactor(uint256 totalsaUSDMinted, uint256 btcValueInUSD) internal pure returns (uint256) {
        if (totalsaUSDMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (btcValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalsaUSDMinted;
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);

        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SUE__HealthFactorIsBroken(userHealthFactor);
        }
    }

    // ------------------------------------------------------------------
    //                         GETTER FUNCTIONS
    // ------------------------------------------------------------------

    function calculateHealthFactor(uint256 totalYDMinted, uint256 collateralValueInUsd)
        external
        pure
        returns (uint256)
    {
        return _calculateHealthFactor(totalYDMinted, collateralValueInUsd);
    }

    function getBTCAmountFromUSD(uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeed[address(i_BTC)]);
        (, int256 answer,,,) = priceFeed.staleDataCheck();
        return (usdAmountInWei * PRECISION) / (uint256(answer) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalsaUSDMinted, uint256 btcValueInUSD)
    {
        (totalsaUSDMinted, btcValueInUSD) = _getAccountInformation(user);
    }

    function getAccountBTCValue(address user) public view returns (uint256 totalBTCValueInUSD) {
        uint256 amount = s_btcDeposited[user][address(i_BTC)];
        totalBTCValueInUSD += _getUsdValue(amount);

        return totalBTCValueInUSD;
    }

    function getUsdValue(uint256 amountInWei) public view returns (uint256) {
        return _getUsdValue(amountInWei);
    }

    function getCollateralBalanceOfUser(address user) external view returns (uint256) {
        return s_btcDeposited[user][address(i_BTC)];
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external view returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getBTC() external view returns (address) {
        return address(i_BTC);
    }

    function getsaUSD() external view returns (address) {
        return address(i_saUSD);
    }

    function getBTCPriceFeed() external view returns (address) {
        return s_priceFeed[address(i_BTC)];
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
