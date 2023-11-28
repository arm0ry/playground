// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {LibClone} from "solbase/utils/LibClone.sol";

contract TokenFactory {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using LibClone for address;

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    uint256 public count;
    mapping(uint256 => string) public tokenTypes;
    mapping(uint256 => address) public tokenTemplates;

    function addToken(address tokenTemplate, string calldata tokenType) external payable {
        unchecked {
            ++count;
        }

        if (tokenTemplate != address(0) && bytes(tokenType).length > 0) {
            tokenTemplates[count] = tokenTemplate;
            tokenTypes[count] = tokenType;
        }
    }

    /// -----------------------------------------------------------------------
    /// Deployment Logic
    /// -----------------------------------------------------------------------

    function determineAddress(uint256 order) public view virtual returns (address) {
        return tokenTemplates[order].predictDeterministicAddress(
            abi.encodePacked(msg.sender), bytes32(uint256(uint160(msg.sender)) << order), address(this)
        );
    }

    function deploy(uint256 order) public payable virtual returns (address) {
        address token = tokenTemplates[order].cloneDeterministic(
            abi.encodePacked(msg.sender), bytes32(uint256(uint160(msg.sender)) << order)
        );
        return token;
    }
}
