// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {ERC1155} from "lib/solbase/src/tokens/ERC1155/ERC1155.sol";
import {UriBuilder} from "src/Tokens/UriBuilder.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
contract Token is ERC1155 {
    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public bulletin;
    address public logger;
    address public curve;
    mapping(uint256 => bytes32) public builders;
    mapping(uint256 => bytes) public metadata;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    function init(address _bulletin, address _curve, address _logger) public {
        bulletin = _bulletin;
        curve = _curve;
        logger = _logger;
    }

    modifier onlyCurve() {
        if (msg.sender != curve) revert Unauthorized();
        _;
    }

    modifier onlyOwnerOrCurve(uint256 id) {
        if (balanceOf[msg.sender][id] > 0 && msg.sender != curve) revert Unauthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Configuration
    /// -----------------------------------------------------------------------

    function config(
        uint256 id,
        address builder,
        uint256 builderId,
        string calldata name,
        string calldata desc,
        uint256 listId,
        uint256 curveId
    ) external payable {
        builders[id] = bytes32(abi.encodePacked(builder, builderId));
        metadata[id] = abi.encode(name, desc, bulletin, listId, curve, curveId);
    }

    /// -----------------------------------------------------------------------
    /// Mint / Burn Logic
    /// -----------------------------------------------------------------------

    // TODO: Add other mint functions with non-curve permissions
    function mint(address to, uint256 id, bytes calldata data) external payable onlyCurve {
        _mint(to, id, 1, data);
    }

    function burn(address from, uint256 id) external payable onlyOwnerOrCurve(id) {
        _burn(from, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
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
