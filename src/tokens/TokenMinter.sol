// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC1155Batchless} from "src/tokens/ERC1155Batchless.sol";
import {TokenUriBuilder} from "src/tokens/TokenUriBuilder.sol";
import {IBulletin, List} from "src/interface/IBulletin.sol";
import {ITokenMinter, TokenTitle, TokenSource, TokenBuilder, TokenMarket} from "src/interface/ITokenMinter.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
contract TokenMinter is ERC1155Batchless {
    error InvalidConfig();
    error AlreadyConfigured();
    error Unauthorized();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    uint256 public tokenId;
    mapping(uint256 => TokenTitle) public titles;
    mapping(uint256 => TokenBuilder) public builders;
    mapping(uint256 => TokenSource) public sources;
    mapping(uint256 => TokenMarket) public markets;
    mapping(uint256 => address) public owners;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifiers
    /// -----------------------------------------------------------------------

    modifier onlyRegisteredMarket(uint256 id) {
        (address market,) = getTokenMarket(id);
        if (market == address(0) || msg.sender != market) revert Unauthorized();
        _;
    }

    modifier onlyTokenOwner(uint256 id) {
        address owner = owners[id];
        if (owner == address(0) || msg.sender != owner) revert Unauthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view override returns (string memory) {
        (address builder, uint256 builderId) = getTokenBuilder(id);
        return TokenUriBuilder(builder).build(builderId, titles[id], sources[id]);
    }

    function svg(uint256 id) public view returns (string memory) {
        (address builder, uint256 builderId) = getTokenBuilder(id);
        (address bulletin, uint256 listId, address logger) = getTokenSource(id);
        return TokenUriBuilder(builder).generateSvg(builderId, bulletin, listId, logger);
    }

    /// -----------------------------------------------------------------------
    /// Configuration
    /// -----------------------------------------------------------------------

    function registerMinter(
        TokenTitle calldata title,
        TokenSource calldata source,
        TokenBuilder calldata builder,
        TokenMarket calldata market
    ) external payable {
        if (builder.builder == address(0)) revert InvalidConfig();
        List memory list = IBulletin(source.bulletin).getList(source.listId);
        if (msg.sender != list.owner) revert Unauthorized();

        unchecked {
            ++tokenId;
        }

        titles[tokenId] = title;
        builders[tokenId] = builder;
        markets[tokenId] = market;
        sources[tokenId] = source;
        owners[tokenId] = msg.sender;
    }

    /// -----------------------------------------------------------------------
    /// Mint by owner of token id / Burn by owner of token
    /// -----------------------------------------------------------------------

    /// @notice Mint function limited to owner of token.
    function mint(address to, uint256 id) external payable onlyTokenOwner(id) {
        _mint(to, id, 1, "");
    }

    /// @notice Burn function limited to owner of token.
    function burn(address from, uint256 id) external payable {
        if (balanceOf[from][id] == 0) revert Unauthorized();
        _burn(from, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Mint / Burn by registered market
    /// -----------------------------------------------------------------------

    /// @notice Mint function limited to market registered by token owner.
    function mintByMarket(address to, uint256 id) external payable onlyRegisteredMarket(id) {
        // Get market.
        (address market,) = getTokenMarket(id);
        if (market == address(0) || msg.sender != market) revert Unauthorized();

        _mint(to, id, 1, "");
    }

    /// @notice Burn function limited to market registered by token owner.
    function burnByMarket(address from, uint256 id) external payable onlyRegisteredMarket(id) {
        _burn(from, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Public getter Logic
    /// -----------------------------------------------------------------------

    function ownerOf(uint256 id) public view returns (address) {
        return owners[id];
    }

    function getTokenTitle(uint256 id) public view returns (string memory, string memory) {
        TokenTitle memory title = titles[id];
        return (title.name, title.desc);
    }

    function getTokenBuilder(uint256 id) public view returns (address, uint256) {
        TokenBuilder memory builder = builders[id];
        return (builder.builder, builder.builderId);
    }

    function getTokenSource(uint256 id) public view returns (address, uint256, address) {
        TokenSource memory source = sources[id];
        return (source.bulletin, source.listId, source.logger);
    }

    function getTokenMarket(uint256 id) public view returns (address, uint256) {
        TokenMarket memory market = markets[id];
        return (market.market, market.limit);
    }
}
