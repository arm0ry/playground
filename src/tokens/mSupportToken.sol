// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {SupportToken} from "./SupportToken.sol";
import {IMission} from "../interface/IMission.sol";
import {IQuest} from "../interface/IQuest.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
contract mSupportToken is SupportToken {
    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public quest;
    address public mission;
    uint256 public missionId;
    address public curve;
    uint256 public totalSupply;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    function init(
        string memory _name,
        string memory _symbol,
        address _quest,
        address _mission,
        uint256 _missionId,
        address _curve
    ) external payable {
        _init(_name, _symbol);

        quest = _quest;
        mission = _mission;
        missionId = _missionId;
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

    function tokenURI(uint256 id) public view override returns (string memory) {
        return _buildURI(id);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 id) private view returns (string memory) {
        return JSON._formattedMetadata("g0v Hackathon Support Token", "", generateSvg(id));
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
                string.concat(unicode"沒有人 #", SVG._uint2str(id))
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
            // buildTaskChart(),
            buildSvgData(),
            "</svg>"
        );
    }

    function buildSvgData() public view returns (string memory) {
        // Okay to use dynamic taskId as intent is to showcase latest attendance.
        uint256 taskId = IMission(mission).getTaskId();

        // The number of hackath0ns hosted by g0v.
        uint256 hackathonCount = 60 + IMission(mission).getMissionTaskCount(missionId);

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                IMission(mission).getMissionTitle(missionId)
            ),
            // SVG._text(
            //     string.concat(
            //         SVG._prop("x", "20"),
            //         SVG._prop("y", "210"),
            //         SVG._prop("font-size", "12"),
            //         SVG._prop("fill", "#00040a")
            //     ),
            //     string.concat(unicode"黑客松次數：", SVG._uint2str(hackathonCount), unicode" 次")
            // ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "230"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"n0body 參與人數：",
                    SVG._uint2str(IQuest(quest).getNumOfStartsByMissionByPublic(mission, missionId)),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "250"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"總參與人數：",
                    SVG._uint2str(IMission(mission).getMissionStarts(missionId)),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "270"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"100% 參與人數：",
                    SVG._uint2str(IMission(mission).getMissionCompletions(missionId)),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "170"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"第 ", SVG._uint2str(hackathonCount), unicode" 次參與人數：")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "140"),
                    SVG._prop("y", "170"),
                    SVG._prop("font-size", "40"),
                    SVG._prop("fill", "#00040a")
                ),
                SVG._uint2str(IMission(mission).getTotalTaskCompletionsByMission(missionId, taskId))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "230"),
                    SVG._prop("y", "170"),
                    SVG._prop("font-size", "11"),
                    SVG._prop("fill", "#00040a")
                ),
                unicode" 人"
            )
        );
    }
}
