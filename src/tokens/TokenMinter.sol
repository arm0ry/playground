// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC1155} from "lib/solbase/src/tokens/ERC1155/ERC1155.sol";
import {UriBuilder} from "src/tokens/UriBuilder.sol";
import {IBulletin, List} from "src/interface/IBulletin.sol";
import {ITokenMinter, Metadata, Builder, Owner} from "src/interface/ITokenMinter.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
contract TokenMinter is ERC1155 {
    error InvalidConfig();
    error AlreadyConfigured();
    error NextConfigAt(uint256 timestamp);

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    uint256 public tokenId;
    uint256 public configInterval = 7 days;
    mapping(uint256 => Builder) public builders;
    mapping(uint256 => Owner) public owners;
    mapping(uint256 => Metadata) public metadatas;
    mapping(uint256 => address) public markets;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Configuration
    /// -----------------------------------------------------------------------

    function setMinter(Metadata calldata metadata, Builder calldata builder, address market) external payable {
        if (builder.builder == address(0)) revert InvalidConfig();
        List memory list = IBulletin(metadata.bulletin).getList(metadata.listId);
        if (msg.sender != list.owner) revert Unauthorized();

        unchecked {
            ++tokenId;
        }

        builders[tokenId] = Builder({builder: builder.builder, builderId: builder.builderId});
        owners[tokenId] = Owner({lastConfigured: uint48(block.timestamp), owner: msg.sender});
        markets[tokenId] = market;
        metadatas[tokenId] = Metadata({
            name: metadata.name,
            desc: metadata.desc,
            bulletin: metadata.bulletin,
            listId: metadata.listId,
            logger: metadata.logger
        });
    }

    // TODO: Tricky when switching between markets, especially from curved market into a flat one.
    // TODO: Might need a cleanUpCurve() function to equitably distribute residuals in a curve to token holders.
    function updateMarket(uint256 _tokenId, address market) external payable {
        Owner memory owner = owners[tokenId];
        if (owner.owner != msg.sender) revert Unauthorized();
        if (owner.lastConfigured + configInterval > block.timestamp) {
            revert NextConfigAt(owner.lastConfigured + configInterval);
        }
        // (,,,,, address market,) =
        //     abi.decode(metadata[_tokenId], (string, string, address, uint256, address, address, uint256));
    }

    function updateBuilder(uint256 _tokenId, Builder calldata builder) external payable {
        Owner memory owner = owners[tokenId];
        if (owner.owner != msg.sender) revert Unauthorized();
        if (owner.lastConfigured + configInterval > block.timestamp) {
            revert NextConfigAt(owner.lastConfigured + configInterval);
        }

        builders[_tokenId] = Builder({builder: builder.builder, builderId: builder.builderId});
    }

    /// -----------------------------------------------------------------------
    /// Mint / Burn Logic
    /// -----------------------------------------------------------------------

    // TODO: Add other mint functions with non-curve permissions
    function mintByCurve(address to, uint256 id) external payable {
        // Get market.
        address market = markets[id];
        if (market == address(0) || msg.sender != market) revert Unauthorized();

        _mint(to, id, 1, "");
    }

    function burnByCurve(address from, uint256 id) external payable {
        // Get market.
        address market = markets[id];
        if (market == address(0) || msg.sender != market) revert Unauthorized();

        _burn(from, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Uri Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view override returns (string memory) {
        Builder memory builder = builders[id];
        address builderAddr;
        uint256 builderId;

        // Decode data via assembly.
        assembly {
            builderId := builder
            builderAddr := shr(128, builder)
        }

        return UriBuilder(builderAddr).build(builderId, metadatas[id]);
    }
}
