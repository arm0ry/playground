// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {MerkleProof} from "./utils/MerkleProof.sol";
import {SVG} from "./utils/SVG.sol";
import {JSON} from "./utils/JSON.sol";

import {NTERC1155} from "./utils/NTERC1155.sol";

import {IQuests} from "./interface/IQuests.sol";
import {IMissions} from "./interface/IMissions.sol";

/// @notice Directory for Quests
/// @author Modified from Kali (https://github.com/kalidao/kali-contracts/blob/main/contracts/access/KaliAccessManager.sol)

enum ListType {
    MISSION_START,
    MISSION_COMPLETE,
    ACCESS_LIST
}

struct Listing {
    address account;
    bool approval;
}

contract QuestsDirectory is NTERC1155 {
    /// -----------------------------------------------------------------------
    /// Library Usage
    /// -----------------------------------------------------------------------

    using MerkleProof for bytes32[];

    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error NotOperator();
    error ListClaimed();
    error NotListed();
    error InvalidMission();

    /// -----------------------------------------------------------------------
    /// List Storage
    /// -----------------------------------------------------------------------

    uint256 public listCount;
    IMissions public missions;
    address public admin;
    mapping(uint256 => bytes32) public merkleRoots;
    mapping(uint256 => string) public uris;

    modifier onlyOperator(uint256 id) {
        if (msg.sender != admin || IQuests(msg.sender).mission() != address(missions)) revert NotOperator();
        _;
    }

    function uri(uint256 id) public view override returns (string memory) {
        string memory text;
        if (bytes(uris[id]).length == 0) {
            return _buildURI(id, text);
        } else {
            return uris[id];
        }
    }

    function _buildURI(uint256 id, string memory text) private pure returns (string memory) {
        return JSON._formattedMetadata(
            string.concat("Access # ", text, SVG._uint2str(id)),
            "Kali Access Manager",
            string.concat(
                '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#191919">',
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", "40"),
                        SVG._prop("font-size", "22"),
                        SVG._prop("fill", "white")
                    ),
                    string.concat(SVG._cdata("Access List #"), SVG._uint2str(id))
                ),
                SVG._rect(
                    string.concat(
                        SVG._prop("fill", "maroon"),
                        SVG._prop("x", "20"),
                        SVG._prop("y", "50"),
                        SVG._prop("width", SVG._uint2str(160)),
                        SVG._prop("height", SVG._uint2str(10))
                    ),
                    SVG.NULL
                ),
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", "90"),
                        SVG._prop("font-size", "12"),
                        SVG._prop("fill", "white")
                    ),
                    string.concat(SVG._cdata("The holder of this token can enjoy"))
                ),
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", "110"),
                        SVG._prop("font-size", "12"),
                        SVG._prop("fill", "white")
                    ),
                    string.concat(SVG._cdata("access to restricted functions."))
                ),
                SVG._image(
                    "https://gateway.pinata.cloud/ipfs/Qmb2AWDjE8GNUob83FnZfuXLj9kSs2uvU9xnoCbmXhH7A1",
                    string.concat(SVG._prop("x", "215"), SVG._prop("y", "220"), SVG._prop("width", "80"))
                ),
                "</svg>"
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() {}

    function initialize(IMissions _missions, address _admin) public payable {
        missions = _missions;
        admin = _admin;
    }

    /// -----------------------------------------------------------------------
    /// List Logic
    /// -----------------------------------------------------------------------

    function createList(Listing[] calldata listings, bytes32 merkleRoot, string calldata metadata)
        external
        payable
        returns (uint256 id)
    {
        // cannot realistically overflow on human timescales
        unchecked {
            id = uint256(uint160(msg.sender)) + listCount;
            ++listCount;
        }

        this.listAccounts(id, listings);

        if (merkleRoot != 0) {
            merkleRoots[id] = merkleRoot;
        }

        if (bytes(metadata).length != 0) {
            uris[id] = metadata;
        }
    }

    function listAccount(ListType listType, uint256 missionId, address account, bool approval) external payable {
        // Assign id based on input data
        if (listType == ListType.MISSION_START) {
            _listAccount(account, missionId, approval);
        } else if (listType == ListType.MISSION_COMPLETE) {
            _listAccount(account, type(uint256).max - missionId, approval);
        } else if (listType == ListType.ACCESS_LIST) {
            // Confirm list has been created
            if (_totalSupply[missionId] != 0) {
                _listAccount(account, missionId, approval);
            }
        } else {
            revert InvalidMission();
        }
    }

    function updateList(ListType listType, uint256 missionId, Listing[] calldata listings) external payable {
        // Assign id based on input data
        if (listType == ListType.MISSION_START) {
            this.listAccounts(missionId, listings);
        } else if (listType == ListType.MISSION_COMPLETE) {
            this.listAccounts(type(uint256).max - missionId, listings);
        } else if (listType == ListType.ACCESS_LIST) {
            // Confirm list has been created
            if (_totalSupply[missionId] != 0) {
                this.listAccounts(missionId, listings);
            }
        } else {
            revert InvalidMission();
        }
    }

    function listAccounts(uint256 id, Listing[] calldata listings) external payable onlyOperator(id) {
        if (listings.length != 0) {
            for (uint256 i; i < listings.length;) {
                _listAccount(listings[i].account, id, listings[i].approval);
                // cannot realistically overflow on human timescales
                unchecked {
                    ++i;
                }
            }
        }
    }

    function _listAccount(address account, uint256 id, bool approved) private {
        approved ? _mint(account, id, 1, "") : _burn(account, id, 1);
    }

    /// -----------------------------------------------------------------------
    /// Merkle Logic
    /// -----------------------------------------------------------------------

    function setMerkleRoot(uint256 id, bytes32 merkleRoot) external payable onlyOperator(id) {
        merkleRoots[id] = merkleRoot;
    }

    function claimList(address account, uint256 id, bytes32[] calldata merkleProof) external payable {
        if (balanceOf[account][id] != 0) revert ListClaimed();
        if (!merkleProof.verify(merkleRoots[id], keccak256(abi.encodePacked(account)))) revert NotListed();

        _listAccount(account, id, true);
    }

    /// -----------------------------------------------------------------------
    /// URI Logic
    /// -----------------------------------------------------------------------

    function setURI(uint256 id, string calldata metadata) external payable onlyOperator(id) {
        uris[id] = metadata;
        emit URI(metadata, id);
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function calculateCompletionListId(uint256 missionId) external pure returns (uint256 id) {
        unchecked {
            id = type(uint256).max - missionId;
        }

        return id;
    }
}
