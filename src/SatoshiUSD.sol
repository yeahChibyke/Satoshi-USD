// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * ███████╗ █████╗ ████████╗ ██████╗ ███████╗██╗  ██╗██╗    ██╗   ██╗███████╗██████╗
 * ██╔════╝██╔══██╗╚══██╔══╝██╔═══██╗██╔════╝██║  ██║██║    ██║   ██║██╔════╝██╔══██╗
 * ███████╗███████║   ██║   ██║   ██║███████╗███████║██║    ██║   ██║███████╗██║  ██║
 * ╚════██║██╔══██║   ██║   ██║   ██║╚════██║██╔══██║██║    ██║   ██║╚════██║██║  ██║
 * ███████║██║  ██║   ██║   ╚██████╔╝███████║██║  ██║██║    ╚██████╔╝███████║██████╔╝
 * ╚══════╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝     ╚═════╝ ╚══════╝╚═════╝
 */

/**
 * @title: Satoshi USD (`saUSD`)
 * @author: Chukwubuike Victory Chime GH/Twitter: yeahChibyke
 * @notice: This contract is just the ERC20 implementation of the stablecoin, and it will be governed by the SatoshiEngine contract
 * @notice: saUSD has 6 decimals, similar to `USDC`
 * @dev: Collateral: Exogenous (`BTC`)
 * @dev: Stability Mechanism: Algorithmic
 * @dev: Relative Stability: Pegged to `USD`
 */

// ------------------------------------------------------------------
//                             IMPORTS
// ------------------------------------------------------------------
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// ------------------------------------------------------------------
//                             CONTRACT
// ------------------------------------------------------------------
contract SatoshiUSD is ERC20Burnable, Ownable {
    // ------------------------------------------------------------------
    //                              ERRORS
    // ------------------------------------------------------------------
    error SAUSD__ZeroAmount();
    error SAUSD__BalanceExceeded();
    error SAUSD__ZeroAddress();

    // ------------------------------------------------------------------
    //                             STORAGE
    // ------------------------------------------------------------------
    uint8 private immutable dec = 6;

    // ------------------------------------------------------------------
    //                           CONSTRUCTOR
    // ------------------------------------------------------------------
    constructor() ERC20("SatoshiUSD", "saUSD") Ownable(msg.sender) {}

    // ------------------------------------------------------------------
    //                        EXTERNAL FUNCTION
    // ------------------------------------------------------------------
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert SAUSD__ZeroAddress();
        }
        if (_amount == 0) {
            revert SAUSD__ZeroAmount();
        }

        _mint(_to, _amount);
        return true;
    }

    // ------------------------------------------------------------------
    //                         PUBLIC FUNCTION
    // ------------------------------------------------------------------
    function burn(uint256 _amount) public override {
        if (_amount == 0) {
            revert SAUSD__ZeroAmount();
        }

        uint256 bal = balanceOf(msg.sender);
        if (bal < _amount) {
            revert SAUSD__BalanceExceeded();
        }

        super.burn(_amount);
    }

    // ------------------------------------------------------------------
    //                             OVERRIDE
    // ------------------------------------------------------------------
    function decimals() public pure override returns (uint8) {
        return dec;
    }
}
