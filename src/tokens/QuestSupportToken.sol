// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {ERC721} from "solbase/tokens/ERC721/ERC721.sol";

import {Mission} from "../Mission.sol";
import {IMission} from "../interface/IMission.sol";
import {IQuest} from "../interface/IQuest.sol";
import {ImpactCurve} from "../ImpactCurve.sol";
import {IStorage} from "kali-markets/interface/IStorage.sol";

/// @title Support SVG NFTs.
/// @notice SVG NFTs displaying impact generated from quests.
contract QuestSupportToken is ERC721 {
    /// -----------------------------------------------------------------------
    /// Custom Error
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error NotActive();
    error TransferFailed();
    error InvalidAmount();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public quest;
    address public mission;
    address public curve;
    mapping(address => uint256) public unclaimed;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    constructor(address _quest, address _mission, address _curve) {
        quest = _quest;
        mission = _mission;
        curve = _curve;
    }

    modifier onlyActive(address user, address _mission, uint256 missionId) {
        if (!IQuest(quest).isQuestActive(user, _mission, missionId)) revert NotActive();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 id) public view override returns (string memory) {
        return _buildURI(id);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 id) private view returns (string memory) {
        return JSON._formattedMetadata("Quest", "Description", generateSvg(id));
    }

    function generateSvg(uint256 id) public view returns (string memory) {
        (address user, uint256 missionId, uint256 curveId) = this.decodeTokenId(id);
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            buildSvgData(missionId, curveId),
            buildSvgProgress(IQuest(quest).getQuestProgress(user, mission, missionId)),
            buildSvgProfile(IQuest(quest).getProfilePicture(user)),
            "</svg>"
        );
    }

    function buildSvgProgress(uint256 progress) public pure returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "145"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Progress: ", SVG._uint2str(progress), "%")
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#ffecb6"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "165"),
                    SVG._prop("width", SVG._uint2str(250)),
                    SVG._prop("height", SVG._uint2str(20)),
                    SVG._prop("opacity", SVG._uint2str(25))
                ),
                SVG.NULL
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#C60000"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "165"),
                    SVG._prop("width", SVG._uint2str(uint256(250) * uint256(progress) / uint256(100))),
                    SVG._prop("height", SVG._uint2str(20))
                ),
                SVG.NULL
            )
        );
    }

    function buildSvgData(uint256 missionId, uint256 curveId) public view returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Mission #", SVG._uint2str(missionId))
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
                IMission(mission).getMissionTitle(missionId)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "220"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Mint Price: ", SVG._uint2str(ImpactCurve(curve).getPrice(true, curveId)))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "240"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Mint Price: ", SVG._uint2str(ImpactCurve(curve).getPrice(false, curveId)))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Cooldown: ", SVG._uint2str(IQuest(quest).getCooldown()))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "280"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    "Review required: ", IQuest(quest).getReviewStatus() ? unicode"🧑‍🏫" : unicode"🙅"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "300"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Deadline: ", SVG._uint2str(IMission(mission).getMissionDeadline(missionId)))
            )
        );
    }

    function buildSvgProfile(string memory url) public pure returns (string memory) {
        return string.concat(
            SVG._image(url, string.concat(SVG._prop("x", "220"), SVG._prop("y", "230"), SVG._prop("width", "50")))
        );
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function getTokenId(address user, uint256 missionId, uint256 curveId) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(user, uint48(missionId), uint48(curveId))));
    }

    function decodeTokenId(uint256 tokenId) external pure returns (address, uint256, uint256) {
        // Convert tokenId from type uint256 to bytes32.
        bytes32 key = bytes32(tokenId);

        // Declare variables to return later.
        uint48 curveId;
        uint48 missionId;
        address user;

        // Parse data via assembly.
        assembly {
            curveId := key
            missionId := shr(48, key)
            user := shr(96, key)
        }

        return (user, uint256(missionId), uint256(curveId));
    }
}
