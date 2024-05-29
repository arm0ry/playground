// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC1155Batchless} from "src/tokens/ERC1155Batchless.sol";
import {TokenUriBuilder} from "src/tokens/TokenUriBuilder.sol";
import {IBulletin, List} from "src/interface/IBulletin.sol";
import {ITokenMinter, TokenMetadata, TokenBuilder} from "src/interface/ITokenMinter.sol";
import {OwnableRoles} from "src/auth/OwnableRoles.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
contract TokenMinter is OwnableRoles, ERC1155Batchless {
    error InvalidConfig();
    error AlreadyConfigured();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    uint256 public tokenId;
    mapping(uint256 => TokenBuilder) public builders;
    mapping(uint256 => TokenMetadata) public metadata;
    mapping(uint256 => address) public owners;
    mapping(uint256 => address) public markets;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifiers
    /// -----------------------------------------------------------------------

    function initialize(address admin) public {
        _initializeOwner(admin);
    }

    modifier onlyRegisteredMarket(uint256 id) {
        address market = markets[id];
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
        TokenBuilder memory builder = builders[id];
        return TokenUriBuilder(builder.builder).build(builder.builderId, metadata[id]);
    }

    function svg(uint256 id) public view returns (string memory) {
        TokenBuilder memory builder = builders[id];
        TokenMetadata memory data = metadata[id];
        return TokenUriBuilder(builder.builder).generateSvg(data.bulletin, data.listId);
    }

    /// -----------------------------------------------------------------------
    /// Configuration
    /// -----------------------------------------------------------------------

    function registerMinter(TokenMetadata calldata _metadata, TokenBuilder calldata builder, address market)
        external
        payable
    {
        if (builder.builder == address(0)) revert InvalidConfig();
        List memory list = IBulletin(_metadata.bulletin).getList(_metadata.listId);
        if (msg.sender != list.owner) revert Unauthorized();

        unchecked {
            ++tokenId;
        }

        builders[tokenId] = builder;
        owners[tokenId] = msg.sender;
        markets[tokenId] = market;
        metadata[tokenId] = _metadata;
    }

    function updateBuilder(uint256 id, TokenBuilder calldata builder) external payable onlyTokenOwner(id) {
        builders[id] = builder;
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
        address market = markets[id];
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
}
