// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ImpactNft} from "./tokens/ImpactNft.sol";
import {SupportToken} from "./tokens/SupportToken.sol";

/// @title Minter of Playground NFTs
contract Minter {
    receive() external payable virtual {}
}
