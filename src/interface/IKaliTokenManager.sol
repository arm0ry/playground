// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Kali DAO share manager interface
interface IKaliTokenManager {
    function mintShares(address to, uint256 amount) external;

    function burnShares(address from, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);
}
