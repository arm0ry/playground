// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {KaliBerger} from "../kali/KaliBerger.sol";

interface IKaliBerger {
    function getTax(address target, uint256 value) external view returns (uint256 _tax);
}
