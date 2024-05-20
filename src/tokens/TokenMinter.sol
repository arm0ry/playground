// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC1155} from "lib/solbase/src/tokens/ERC1155/ERC1155.sol";
import {UriBuilder} from "src/Tokens/UriBuilder.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
contract TokenMinter is ERC1155 {
    error InvalidConfiguration();
    error AlreadyConfigured();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    mapping(uint256 => bytes32) public builders;
    mapping(uint256 => bytes) public metadata;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Configuration
    /// -----------------------------------------------------------------------

    function config(
        uint256 id,
        address builder,
        uint256 builderId,
        string calldata name,
        string calldata desc,
        address bulletin,
        uint256 listId,
        address logger,
        address market
    ) external payable {
        if (builder == address(0)) revert InvalidConfiguration();
        if (builders[id] > 0) revert AlreadyConfigured();
        builders[id] = bytes32(abi.encodePacked(builder, builderId));
        metadata[id] = abi.encode(name, desc, bulletin, listId, logger, market);
    }

    /// -----------------------------------------------------------------------
    /// Mint / Burn Logic
    /// -----------------------------------------------------------------------

    // TODO: Add other mint functions with non-curve permissions
    function mintByCurve(address to, uint256 id) external payable {
        // Get market.
        (,,,,, address market,) =
            abi.decode(metadata[id], (string, string, address, uint256, address, address, uint256));
        if (market == address(0) || msg.sender != market) revert Unauthorized();

        _mint(to, id, 1, "");
    }

    function burnByCurve(address from, uint256 id) external payable {
        // Get market.
        (,,,,, address market,) =
            abi.decode(metadata[id], (string, string, address, uint256, address, address, uint256));
        if (market == address(0) || msg.sender != market) revert Unauthorized();

        _burn(from, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Uri Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view override returns (string memory) {
        bytes32 builder = builders[id];
        address builderAddr;
        uint256 builderId;

        // Decode data via assembly.
        assembly {
            builderId := builder
            builderAddr := shr(128, builder)
        }

        return UriBuilder(builderAddr).build(builderId, metadata[id]);
    }
}
