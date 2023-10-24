// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {Base64} from "../../lib/solbase/src/utils/Base64.sol";
import {LibString} from "../../lib/solbase/src/utils/LibString.sol";
import {ERC721} from "../../lib/solbase/src/tokens/ERC721/ERC721.sol";

import {IMissions, Mission, Task} from "../interface/IMissions.sol";
import {IStorage} from "../interface/IStorage.sol";
import {IQuest} from "../interface/IQuest.sol";
import {IKaliBerger} from "../interface/IKaliBerger.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Majory inspired by Kali, Async.art
contract MissionsBergerToken is ERC721 {
    /// -----------------------------------------------------------------------
    /// Custom Errors
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// DAO Storage
    /// -----------------------------------------------------------------------

    address public dao;
    address public missions;
    address public kaliBerger;

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _dao, address _kaliBerger, address _missions) ERC721("Mission Berger Token", "MBT") {
        dao = _dao;
        kaliBerger = _kaliBerger;
        missions = _missions;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return _buildURI(tokenId);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 tokenId) private view returns (string memory) {
        (address _missions, uint256 missionId) = this.decodeTokenId(tokenId);
        return JSON._formattedMetadata(
            "Mission Berger Token",
            "",
            generateSvg(
                (_missions == address(0) ? missions : _missions), (_missions == address(0) ? tokenId : missionId)
            )
        );
    }

    function generateSvg(address _missions, uint256 missionId) public view returns (string memory) {
        string memory title = IMissions(_missions).getMissionTitle(missionId);
        uint256 deadline = IMissions(_missions).getMissionDeadline(missionId);
        uint256 completions =
            IStorage(_missions).getUint(keccak256(abi.encodePacked(_missions, missionId, ".completions")));

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            buildSvgLogo(),
            buildSvgData(_missions, missionId, title, deadline, completions),
            buildTreeRing(_missions, missionId),
            "</svg>"
        );
    }

    function buildSvgLogo() public pure returns (string memory) {
        return string.concat(
            '<g filter="url(#a)">',
            '<path stroke="#FFBE0B" stroke-linecap="round" stroke-width="2.1" d="M207 48.3c12.2-8.5 65-24.8 87.5-21.6" fill="none"/></g><path fill="#00040a" d="M220.2 38h-.8l-2.2-.4-1 4.6-2.9-.7 1.5-6.4 1.6-8.3c1.9-.4 3.9-.6 6-.8l1.9 8.5 1.5 7.4-3 .5-1.4-7.3-1.2-6.1c-.5 0-1 0-1.5.2l-1 6 3.1.1-.4 2.6h-.2Zm8-5.6v-2.2l2.6-.3.5 1.9 1.8-2.1h1.5l.6 2.9-2 .4-1.8.4-.2 8.5-2.8.2-.2-9.7Zm8.7-2.2 2.6-.3.4 1.9 2.2-2h2.4c.3 0 .6.3 1 .6.4.4.7.9.7 1.3l2.1-1.8h3l.6.3.6.6.2.5-.4 10.7-2.8.2v-9.4a4.8 4.8 0 0 0-2.2.2l-1 .3-.3 8.7-2.7.2v-9.4a5 5 0 0 0-2.3.2l-.9.3-.3 8.6-2.7.2-.2-11.9Zm28.6 3.5a19.1 19.1 0 0 1-.3 4.3 15.4 15.4 0 0 1-.8 3.6c-.1.3-.3.4-.5.5l-.8.2h-2.3c-2 0-3.2-.2-3.6-.6-.4-.5-.8-2.1-1-5a25.7 25.7 0 0 1 0-5.6l.4-.5c.1-.2.5-.4 1-.5 2.3-.5 4.8-.8 7.4-.8h.4l.3 3-.6-.1h-.5a23.9 23.9 0 0 0-5.3.5 25.1 25.1 0 0 0 .3 7h2.4c.2-1.2.4-2.8.5-4.9v-.7l3-.4Zm3.7-1.3v-2.2l2.6-.3.5 1.9 1.9-2.1h1.4l.6 2.9-1.9.4-2 .4V42l-2.9.2-.2-9.7Zm8.5-2.5 3-.6.2 10 .8.1h.9l1.5-.6V30l2.8-.3.2 13.9c0 .4-.3.8-.8 1.1l-3 2-1.8 1.2-1.6.9-1.5-2.7 6-3-.1-3.1-1.9 2h-3.1c-.3 0-.5-.1-.8-.4-.4-.3-.6-.6-.6-1l-.2-10.7Z"/>',
            "<defs>",
            '<filter id="a" width="91.743" height="26.199" x="204.898" y="24.182" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse">',
            '<feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape"/>',
            "</filter>",
            "</defs>"
        );
    }

    function buildSvgData(
        address _missions,
        uint256 missionId,
        string memory title,
        uint256 deadline,
        uint256 completions
    ) public view returns (string memory) {
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
                title
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
                    SVG._uint2str((kaliBerger == address(0)) ? IKaliBerger(kaliBerger).getTax(_missions, missionId) : 0),
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
                string.concat("# of completions: ", SVG._uint2str(completions))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "190"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Complete by: ", SVG._uint2str(deadline))
            )
        );
    }

    function buildTreeRing(address _missions, uint256 missionId) public view returns (string memory str) {
        uint256 baseRadius = 500;
        uint256[] memory taskIds = IMissions(_missions).getMissionTaskIds(missionId);
        string[] memory strArray;

        for (uint256 i = 0; i < taskIds.length;) {
            uint256 completions = IMissions(_missions).getTaskCompletions(taskIds[i]);

            // radius = completions * max radius / max completions at max radius + base radius
            uint256 radius = completions * 500 / 100;
            baseRadius += radius / 10;

            strArray[i] = SVG._circle(
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
            );

            unchecked {
                ++i;
            }
        }

        return str;
    }

    /// -----------------------------------------------------------------------
    // Mint Logic
    /// -----------------------------------------------------------------------

    function mint(address to, uint256 id) external payable {
        _mint(to, id);
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function getTokenId(address _missions, uint256 missionId) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(_missions, uint96(missionId))));
    }

    function decodeTokenId(uint256 tokenId) external pure returns (address _missions, uint256 missionId) {
        uint96 _id;
        bytes32 key = bytes32(tokenId);
        assembly {
            _id := key
            _missions := shr(96, key)
        }
        return (_missions, uint256(_id));
    }
}
