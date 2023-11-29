// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {Base64} from "solbase/utils/Base64.sol";
import {LibString} from "solbase/utils/LibString.sol";
import {ERC721} from "solbase/tokens/ERC721/ERC721.sol";

import {IMission} from "../interface/IMission.sol";
import {IQuest} from "../interface/IQuest.sol";
import {IStorage} from "kali-markets/interface/IStorage.sol";
import {IKaliBerger} from "kali-markets/interface/IKaliBerger.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Majory inspired by Kali, Async.art
contract MissionBergerToken is ERC721 {
    /// -----------------------------------------------------------------------
    /// DAO Storage
    /// -----------------------------------------------------------------------

    address public dao;
    address public kaliBerger;

    /// -----------------------------------------------------------------------
    /// Modifier
    /// -----------------------------------------------------------------------

    modifier onlyDao() {
        if (msg.sender != dao) revert Unauthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _dao, address _kaliBerger, string memory name, string memory symbol) ERC721(name, symbol) {
        dao = _dao;
        kaliBerger = _kaliBerger;
    }

    modifier onlyMissionCreators(address missions, uint256 missionId, address user) {
        if (IMission(missions).getMissionCreator(missionId) != msg.sender) revert Unauthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _buildURI(tokenId);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 tokenId) private view returns (string memory) {
        return JSON._formattedMetadata("Mission Berger Token", "", generateSvg(tokenId));
    }

    function generateSvg(uint256 tokenId) public view returns (string memory) {
        (address missions, uint256 missionId) = this.decodeTokenId(tokenId);
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            buildSvgData(missions, missionId),
            buildTreeRing(missions, missionId),
            "</svg>"
        );
    }

    function buildSvgData(address missions, uint256 missionId) public view returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Patron Impact")
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#FFBE0B"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "50"),
                    SVG._prop("width", SVG._uint2str(160)),
                    SVG._prop("height", SVG._uint2str(5))
                ),
                SVG.NULL
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "80"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Title: ")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "110"),
                    SVG._prop("font-size", "18"),
                    SVG._prop("fill", "#00040a")
                ),
                IMission(missions).getMissionTitle(missionId)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "170"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    "Harberger Tax: ",
                    SVG._uint2str((kaliBerger == address(0)) ? IKaliBerger(kaliBerger).getTax(missions, missionId) : 0),
                    "%"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "210"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("# of completions: ", SVG._uint2str(IMission(missions).getMissionCompletions(missionId)))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "190"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Complete by: ", SVG._uint2str(IMission(missions).getMissionDeadline(missionId)))
            )
        );
    }

    function buildTreeRing(address missions, uint256 missionId) public view returns (string memory str) {
        uint256 baseRadius = 500;
        uint256[] memory taskIds = IMission(missions).getMissionTaskIds(missionId);

        for (uint256 i = 0; i < taskIds.length;) {
            uint256 completions = IMission(missions).getTaskCompletions(taskIds[i]);

            // radius = completions * max radius / max completions at max radius + base radius
            uint256 radius = completions * 500 / 100;
            baseRadius += radius / 10;

            str = string.concat(
                str,
                SVG._circle(
                    string.concat(
                        SVG._prop("cx", "265"),
                        SVG._prop("cy", "265"),
                        SVG._prop("r", SVG._uint2str(baseRadius / 10)),
                        SVG._prop("stroke", "#A1662F"),
                        SVG._prop("stroke-opacity", "0.1"),
                        SVG._prop("stroke-width", "3"),
                        SVG._prop("fill", "#FFBE0B"),
                        SVG._prop("fill-opacity", "0.1")
                    ),
                    ""
                )
            );

            unchecked {
                ++i;
            }
        }

        return str;
    }

    /// -----------------------------------------------------------------------
    /// DAO Logic
    /// -----------------------------------------------------------------------

    function setKaliBerger(address _kaliBerger) external payable onlyDao {
        kaliBerger = _kaliBerger;
    }

    /// -----------------------------------------------------------------------
    /// Mission Creator Logic
    /// -----------------------------------------------------------------------

    function mint(address missions, uint256 missionId)
        external
        payable
        onlyMissionCreators(missions, missionId, msg.sender)
    {
        _mint(msg.sender, this.getTokenId(missions, missionId));
    }

    function burn(address missions, uint256 missionId)
        external
        payable
        onlyMissionCreators(missions, missionId, msg.sender)
    {
        _burn(this.getTokenId(missions, missionId));
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function getTokenId(address missions, uint256 missionId) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(missions, uint96(missionId))));
    }

    function decodeTokenId(uint256 tokenId) external pure returns (address missions, uint256 missionId) {
        uint96 _id;
        bytes32 key = bytes32(tokenId);
        assembly {
            _id := key
            missions := shr(96, key)
        }
        return (missions, uint256(_id));
    }
}
