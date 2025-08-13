// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockBTC is ERC20 {
    uint8 private decimal;

    constructor() ERC20("Mock BTC", "mBTC") {
        decimal = 6;
    }

    function decimals() public view override returns (uint8) {
        return decimal;
    }

    function mint(address account, uint256 amount) public {
        uint256 mint_amount = (amount * (1 * (10 ** decimal)));
        _mint(account, mint_amount);
    }

    function burn(address account, uint256 amount) public {
        uint256 burn_amount = (amount * (1 * (10 ** decimal)));
        _burn(account, burn_amount);
    }

    function transferInternal(address from, address to, uint256 value) public {
        uint256 transfer_value = (value * (1 * (10 ** decimal)));
        _transfer(from, to, transfer_value);
    }

    function approveInternal(address owner, address spender, uint256 value) public {
        uint256 approve_value = (value * (1 * (10 ** decimal)));
        _approve(owner, spender, approve_value);
    }
}
