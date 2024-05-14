// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC20} from "solbase/tokens/ERC20/ERC20.sol";
import {Owned} from "solmate/auth/Owned.sol";

contract Currency is ERC20, Owned {
    constructor(string calldata _name, string calldata _symbol) ERC20(_name, _symbol, 18) Owned(msg.sender) {}

    function mint(address to, uint256 amount, address spender) public onlyOwner {
        _mint(to, amount);
        allowance[to][spender] = amount;
    }
}
