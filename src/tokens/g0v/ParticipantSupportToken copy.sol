// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../../utils/SVG.sol";
import {JSON} from "../../utils/JSON.sol";
import {SupportToken} from "../SupportToken.sol";
import {Mission} from "../../Mission.sol";
import {IMission} from "../../interface/IMission.sol";
import {IQuest} from "../../interface/IQuest.sol";

/// @title Support SVG NFTs.
/// @notice SVG NFTs displaying impact generated from quests.
contract ParticipantSupportToken is SupportToken {
    /// -----------------------------------------------------------------------
    /// SVG Storage
    /// -----------------------------------------------------------------------

    uint8[7] public counters;

    /// -----------------------------------------------------------------------
    /// Core Storage
    /// -----------------------------------------------------------------------

    bool public isInitialized;
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

        isInitialized = true;
    }

    modifier initialized() {
        if (!isInitialized) revert Unauthorized();
        _;
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

    function mint(address to) external payable initialized onlyCurve {
        unchecked {
            ++totalSupply;
        }

        _safeMint(to, totalSupply);
    }

    function burn(uint256 id) external payable initialized onlyOwnerOrCurve(id) {
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
                string.concat(unicode"黑客松新參者一日求生小錦囊")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "140"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"第 ",
                    SVG._uint2str(hackathonCount),
                    unicode" 次參與人數： ",
                    SVG._uint2str(IMission(mission).getTotalTaskCompletionsByMission(missionId, taskId)),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "160"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"👍 幫 g0v 粉專按讚： ", SVG._uint2str(counters[0]), unicode" 人")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "180"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🔔 打開專案頻道通知： ", SVG._uint2str(counters[1]), unicode" 人")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "200"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"📝 截圖任一提案的專案共筆： ", SVG._uint2str(counters[2]), unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "220"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"🧐 加入三個你有興趣的頻道： ", SVG._uint2str(counters[3]), unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "240"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"👀 瀏覽並截圖最新社群九分鐘： ", SVG._uint2str(counters[4]), unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"🏷️ 拿三張符合你身份的技能貼紙：",
                    SVG._uint2str(counters[5]),
                    unicode" 人"
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "280"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    unicode"🎙️ 在有興趣的專案共筆上介紹自己： ",
                    SVG._uint2str(counters[6]),
                    unicode" 人"
                )
            )
        );
    }

    function tally(uint256 taskId) external initialized {
        uint256 response;
        uint256 questId = IQuest(quest).getQuestId();

        if (questId > 0) {
            for (uint256 i = 1; i <= questId; ++i) {
                response = IQuest(quest).getTaskResponse(i, taskId);
                for (uint256 j; j < 7; ++j) {
                    if ((response / (10 ** j)) % 10 == 1) ++counters[j];
                }
            }
        } else {
            revert Unauthorized();
        }
    }
}
