// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC1155} from "lib/solbase/src/tokens/ERC1155/ERC1155.sol";
import {TokenUriBuilder} from "src/tokens/TokenUriBuilder.sol";
import {IBulletin, List} from "src/interface/IBulletin.sol";
import {ITokenMinter, TokenMetadata, TokenBuilder, TokenOwner} from "src/interface/ITokenMinter.sol";

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
    mapping(bytes32 => bool) public initialized; // TODO: Use this to prevent token ids with duplicative metadata.
    mapping(uint256 => TokenBuilder) public builders;
    mapping(uint256 => TokenOwner) public owners;
    mapping(uint256 => TokenMetadata) public metadatas;
    mapping(uint256 => address) public markets;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Configuration
    /// -----------------------------------------------------------------------

    // TODO: Should the same content have more than one token id? Probably not.
    function setMinter(TokenMetadata calldata metadata, TokenBuilder calldata builder, address market)
        external
        payable
    {
        if (builder.builder == address(0)) revert InvalidConfig();
        List memory list = IBulletin(metadata.bulletin).getList(metadata.listId);
        if (msg.sender != list.owner) revert Unauthorized();

        unchecked {
            ++tokenId;
        }

        builders[tokenId] = TokenBuilder({builder: builder.builder, builderId: builder.builderId});
        owners[tokenId] = TokenOwner({lastConfigured: uint48(block.timestamp), owner: msg.sender});
        markets[tokenId] = market;
        metadatas[tokenId] = TokenMetadata({
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
        TokenOwner memory owner = owners[tokenId];
        if (owner.owner != msg.sender) revert Unauthorized();
        if (owner.lastConfigured + configInterval > block.timestamp) {
            revert NextConfigAt(owner.lastConfigured + configInterval);
        }
        // (,,,,, address market,) =
        //     abi.decode(metadata[_tokenId], (string, string, address, uint256, address, address, uint256));
    }

    function updateBuilder(uint256 _tokenId, TokenBuilder calldata builder) external payable {
        TokenOwner memory owner = owners[tokenId];
        if (owner.owner != msg.sender) revert Unauthorized();
        if (owner.lastConfigured + configInterval > block.timestamp) {
            revert NextConfigAt(owner.lastConfigured + configInterval);
        }

        builders[_tokenId] = TokenBuilder({builder: builder.builder, builderId: builder.builderId});
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
    /// Public getter Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view override returns (string memory) {
        TokenBuilder memory builder = builders[id];
        return TokenUriBuilder(builder.builder).build(builder.builderId, metadatas[id]);
    }

    function ownerOf(uint256 id) public view returns (address) {
        TokenOwner memory owner = owners[id];
        return owner.owner;
    }
}
