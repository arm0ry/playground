// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/// @notice Kali DAO share manager interface
interface IKaliTokenManager {
    function mintTokens(address to, uint256 amount) external;

    function burnTokens(address from, uint256 amount) external;

    function balanceOf(address account) external view returns (uint256);
}
