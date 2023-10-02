// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {Base64} from "../../lib/solbase/src/utils/Base64.sol";
import {LibString} from "../../lib/solbase/src/utils/LibString.sol";
import {ERC721} from "../../lib/solbase/src/tokens/ERC721/ERC721.sol";

import {IMissions, Mission, Task, Metric} from "../interface/IMissions.sol";
import {IStorage} from "../interface/IStorage.sol";
import {IQuest, QuestDetail} from "../interface/IQuest.sol";
import {IKaliBerger} from "../interface/IKaliBerger.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Major inspiration from Kali, Async.art
contract ImpactToken is ERC721 {
    /// -----------------------------------------------------------------------
    /// Custom Error
    /// -----------------------------------------------------------------------

    error NotAuthorized();

    /// -----------------------------------------------------------------------
    /// Emoji Storage
    /// -----------------------------------------------------------------------

    bool useEmoji;

    /// -----------------------------------------------------------------------
    /// Harberger Tax Storage
    /// -----------------------------------------------------------------------

    address public kaliBerger;

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor(address _kaliBerger) ERC721("PatronImpact", "PI") {
        kaliBerger = _kaliBerger;
    }

    modifier onlyBerger() {
        if (msg.sender != kaliBerger) revert NotAuthorized();
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
        (address missions, uint256 missionId) = this.decodeTokenId(tokenId);
        return JSON._formattedMetadata("Patron Impage", "", generateSvg(missions, missionId));
    }

    function generateSvg(address missions, uint256 missionId) public view returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#191919">',
            buildSvgLogo(),
            buildSvgData(missions, missionId),
            buildSvgMetrics(missions, missionId),
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

    function buildSvgData(address missions, uint256 missionId) public view returns (string memory) {
        uint256 deadline = IMissions(missions).getMissionDeadline(missionId);
        uint256 completions =
            IStorage(missions).getUint(keccak256(abi.encodePacked(missions, missionId, ".completions")));
        string memory title = IMissions(missions).getMissionTitle(missionId);

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
                    SVG._prop("y", "240"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Harberger Tax: ", SVG._uint2str(IKaliBerger(kaliBerger).getTax(missions, missionId)))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("# of completions: ", SVG._uint2str(completions))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "280"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Deadline: ", SVG._uint2str(deadline))
            )
        );
    }

    function buildSvgMetrics(address missions, uint256 missionId) public view returns (string memory) {
        string memory title = IMissions(missions).getMetricTitle(missionId);
        Metric memory metric = IMissions(missions).getMetrics(missionId);

        uint256 mostRecent = IMissions(missions).getSingleMetricValue(missionId, metric.numberOfEntries);
        uint256 secondMostRecent;
        uint256 thirdMostRecent;
        uint256 fourthMostRecent;
        uint256 fifthMostRecent;
        if (metric.numberOfEntries > 1) {
            secondMostRecent = IMissions(missions).getSingleMetricValue(missionId, metric.numberOfEntries - 1);
        } else if (metric.numberOfEntries > 2) {
            thirdMostRecent = IMissions(missions).getSingleMetricValue(missionId, metric.numberOfEntries);
        } else if (metric.numberOfEntries > 3) {
            fourthMostRecent = IMissions(missions).getSingleMetricValue(missionId, metric.numberOfEntries);
        } else if (metric.numberOfEntries > 4) {
            fifthMostRecent = IMissions(missions).getSingleMetricValue(missionId, metric.numberOfEntries);
        } else {}

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "190"),
                    SVG._prop("font-size", "10"),
                    SVG._prop("fill", "8FADFF")
                ),
                string.concat(title)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "70"),
                    SVG._prop("y", "195"),
                    SVG._prop("font-size", "60"),
                    SVG._prop("fill", "FFBE0B")
                ),
                useEmoji
                    ? string.concat(
                        SVG._uint2str(fifthMostRecent),
                        " ",
                        SVG._uint2str(fourthMostRecent),
                        " ",
                        SVG._uint2str(thirdMostRecent),
                        " ",
                        SVG._uint2str(secondMostRecent),
                        " ",
                        SVG._uint2str(mostRecent)
                    )
                    : string.concat(
                        this.getEmoji(fifthMostRecent),
                        " ",
                        this.getEmoji(fourthMostRecent),
                        " ",
                        this.getEmoji(thirdMostRecent),
                        " ",
                        this.getEmoji(secondMostRecent),
                        " ",
                        this.getEmoji(mostRecent)
                    )
            )
        );
    }

    /// -----------------------------------------------------------------------
    // Mint Logic
    /// -----------------------------------------------------------------------

    function mint(address to, uint256 id) external onlyBerger {
        _mint(to, id);
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

    function getEmoji(uint256 value) external pure returns (string memory) {
        string memory temp;
        if (value == 0) {
            temp = unicode"😁";
        } else if (value == 1) {
            temp = unicode"👌";
        } else if (value == 2) {
            temp = unicode"😃";
        } else if (value == 3) {
            temp = unicode"🙌";
        } else if (value == 3) {
            temp = unicode"🙌";
        } else {
            temp = unicode"👍";
        }
        return temp;
    }
}
