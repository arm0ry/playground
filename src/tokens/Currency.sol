// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC20} from "lib/solbase/src/tokens/ERC20/ERC20.sol";
import {Ownable} from "solady/auth/Ownable.sol";

// TODO: Consider using OwnableRoles
contract Currency is ERC20, Ownable {
    constructor(string memory _name, string memory _symbol, address owner) ERC20(_name, _symbol, 18) {
        _initializeOwner(owner);
    }

    function mint(address to, uint256 amount, address spender) public onlyOwner {
        _mint(to, amount);
        allowance[to][spender] = amount;
    }
}
