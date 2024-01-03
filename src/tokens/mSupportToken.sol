// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {SupportToken} from "./SupportToken.sol";
import {IMission} from "../interface/IMission.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Majory inspired by Kali, Async.art
contract mSupportToken is SupportToken {
    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public owner;
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
        address _owner,
        address _mission,
        uint256 _missionId,
        address _curve
    ) external payable {
        _init(_name, _symbol);

        owner = _owner;
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
                string.concat("Support #", SVG._uint2str(id))
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
            buildTaskChart(),
            buildSvgData(),
            "</svg>"
        );
    }

    function buildSvgData() public view returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "90"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Title: ")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "120"),
                    SVG._prop("font-size", "18"),
                    SVG._prop("fill", "#00040a")
                ),
                IMission(mission).getMissionTitle(missionId)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "200"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Ends in: ", SVG._uint2str(IMission(mission).getMissionDeadline(missionId)), " s")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "220"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("# of Starts: ", SVG._uint2str(IMission(mission).getMissionStarts(missionId)))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "240"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("# of Completions: ", SVG._uint2str(IMission(mission).getMissionCompletions(missionId)))
            )
        );
    }

    // function buildTreeRing() public view returns (string memory str) {
    //     uint256[] memory taskIds = IMission(mission).getMissionTaskIds(missionId);

    //     for (uint256 i = 0; i < taskIds.length;) {
    //         uint256 completions = IMission(mission).getTotalTaskCompletionsByMission(missionId, taskIds[i]);
    //         uint256 shade = completions * str = string.concat(
    //             str,
    //             SVG._circle(
    //                 string.concat(
    //                     SVG._prop("cx", "265"),
    //                     SVG._prop("cy", "265"),
    //                     SVG._prop("r", SVG._uint2str(50 + i * 20)),
    //                     SVG._prop("stroke", "#A1662F"),
    //                     SVG._prop("stroke-opacity", "0.1"),
    //                     SVG._prop("stroke-width", "3"),
    //                     SVG._prop("fill", "#FFBE0B"),
    //                     SVG._prop("fill-opacity", SVG._uint2str(baseRadius, "%"))
    //                 ),
    //                 ""
    //             )
    //         );

    //         unchecked {
    //             ++i;
    //         }
    //     }
    // }

    function buildTaskChart() public view returns (string memory str) {
        uint256[] memory taskIds = IMission(mission).getMissionTaskIds(missionId);
        uint256 length = taskIds.length;

        uint256 completions;
        uint256 taskWidth = uint256(250) / length;

        for (uint256 i = 0; i < taskIds.length;) {
            completions = IMission(mission).getTotalTaskCompletionsByMission(missionId, taskIds[i]);

            str = string.concat(
                str,
                SVG._rect(
                    string.concat(
                        SVG._prop("fill", "#FFBE0B"),
                        SVG._prop("x", SVG._uint2str(20 + taskWidth * i)),
                        SVG._prop("y", "140"),
                        SVG._prop("width", SVG._uint2str(taskWidth)),
                        SVG._prop("height", "20"),
                        SVG._prop("fill-opacity", string.concat(SVG._uint2str(completions * 5), "%")),
                        SVG._prop("stroke", "#FFBE0B"),
                        SVG._prop("stroke-opacity", "0.2"),
                        SVG._prop("stroke-width", "1")
                    ),
                    SVG.NULL
                )
            );

            unchecked {
                ++i;
            }
        }
    }
}
