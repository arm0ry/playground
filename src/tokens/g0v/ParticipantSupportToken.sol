// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../../utils/SVG.sol";
import {JSON} from "../../utils/JSON.sol";
import {SupportToken} from "../SupportToken.sol";
import {Mission} from "../../Mission.sol";
import {IMission} from "../../interface/IMission.sol";
import {IQuest} from "../../interface/IQuest.sol";

struct QuestData {
    address user;
    address mission;
    uint256 missionId;
    uint256 taskCount;
    string feedback;
}

/// @title Support SVG NFTs.
/// @notice SVG NFTs displaying impact generated from quests.
contract ParticipantSupportToken is SupportToken {
    /// -----------------------------------------------------------------------
    /// Errors
    /// -----------------------------------------------------------------------

    error InvalidQuest();

    /// -----------------------------------------------------------------------
    /// Core Storage
    /// -----------------------------------------------------------------------

    address public quest;
    address public curve;
    uint256 public totalSupply;

    // tokenId => questId
    mapping(uint256 => QuestData) public data;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    constructor(string memory _name, string memory _symbol, address _quest, address _curve) {
        _init(_name, _symbol);

        quest = _quest;
        curve = _curve;
    }

    modifier onlyCurve() {
        if (msg.sender != curve) revert Unauthorized();
        _;
    }

    modifier onlyOwnerOrCurve(uint256 id) {
        if (msg.sender != ownerOf(id) && msg.sender != curve) revert Unauthorized();

        _;
    }

    /// -----------------------------------------------------------------------
    /// Mint / Burn Logic
    /// -----------------------------------------------------------------------

    function mint(address to) external payable onlyCurve {
        unchecked {
            ++totalSupply;
        }

        _safeMint(to, totalSupply);
    }

    function burn(uint256 id) external payable onlyOwnerOrCurve(id) {
        unchecked {
            --totalSupply;
        }

        _burn(id);
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function populate(uint256 tokenId, uint256 questId) external payable {
        if (msg.sender != ownerOf(tokenId)) revert Unauthorized();

        (address user, address mission, uint256 missionId) = IQuest(quest).getQuest(questId);
        if (user == address(0) || questId > IQuest(quest).getQuestId()) revert InvalidQuest();

        uint256 taskCount = IMission(mission).getMissionTaskCount(missionId);
        uint256 taskId = IMission(mission).getMissionTaskId(missionId, taskCount);
        string memory feedback = IQuest(quest).getTaskFeedback(questId, taskId);

        data[tokenId].user = user;
        data[tokenId].mission = mission;
        data[tokenId].missionId = missionId;
        data[tokenId].taskCount = taskCount;
        data[tokenId].feedback = feedback;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        return _buildURI(id);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 id) private view returns (string memory) {
        return JSON._formattedMetadata("Support Token", "", generateSvg(id));
    }

    function generateSvg(uint256 id) public view returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"台灣零時政府黑客松")
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#FFBE0B"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "50"),
                    SVG._prop("width", "200"),
                    SVG._prop("height", "5")
                ),
                SVG.NULL
            ),
            buildSvgData(id),
            "</svg>"
        );
    }

    function buildSvgData(uint256 id) public view returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                unicode"參加過"
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "65"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("font-weight", "bolder"),
                    SVG._prop("fill", "#018edf")
                ),
                SVG._uint2str(
                    IQuest(quest).getNumOfCompletedTasksInMission(data[id].user, data[id].mission, data[id].missionId)
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "90"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                unicode"次大松的"
            ),
            (data[id].user != address(0))
                ? SVG._image(
                    IQuest(quest).getProfilePicture(data[id].user),
                    string.concat(SVG._prop("x", "150"), SVG._prop("y", "70"), SVG._prop("width", "40"))
                )
                : SVG._rect(
                    string.concat(
                        SVG._prop("fill", "#FFBE0B"),
                        SVG._prop("x", "150"),
                        SVG._prop("y", "70"),
                        SVG._prop("rx", "10"),
                        SVG._prop("ry", "10"),
                        SVG._prop("width", "40"),
                        SVG._prop("height", "40")
                    ),
                    SVG.NULL
                ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "200"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                unicode"，在"
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "160"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                unicode"最近的第"
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "90"),
                    SVG._prop("y", "160"),
                    SVG._prop("font-size", "40"),
                    SVG._prop("fill", "#018edf")
                ),
                SVG._uint2str(60 + data[id].taskCount)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "160"),
                    SVG._prop("y", "160"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                unicode"次零時政府黑客松"
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "210"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                unicode"發表了以下的言論："
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "255"),
                    SVG._prop("font-size", "16"),
                    SVG._prop("fill", "#FFBE0B")
                ),
                (bytes(data[id].feedback).length == 0) ? unicode"等待中..." : data[id].feedback
            )
        );
    }
}
