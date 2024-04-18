// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "utils/SVG.sol";
import {JSON} from "utils/JSON.sol";
import {SupportToken} from "tokens/SupportToken.sol";
import {IImpactCurve} from "interface/IImpactCurve.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
contract MissionToken is SupportToken {
    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public immutable quest;
    address public immutable mission;
    address public immutable curve;
    uint256 public totalSupply;
    mapping(uint256 => bytes32) public inputs;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    constructor(string memory _name, string memory _symbol, address _quest, address _mission, address _curve) {
        _init(_name, _symbol);

        quest = _quest;
        mission = _mission;
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
    /// SVG Inputs
    /// -----------------------------------------------------------------------

    function updateInputs(uint256 tokenId, uint128 missionId, uint128 curveId)
        external
        payable
        onlyOwnerOrCurve(tokenId)
    {
        inputs[tokenId] = this.encodeSvgInputs(missionId, curveId);
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function tokenURI(uint256 id) public view override returns (string memory) {
        return _buildURI(id);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 id) internal view returns (string memory) {
        return JSON._formattedMetadata("Default Participant Token", "", generateSvg(id));
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
                string.concat("Supporter #", SVG._uint2str(id))
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
            buildSvgData(id),
            "</svg>"
        );
    }

    function buildSvgData(uint256 id) public view returns (string memory) {
        (uint256 missionId, uint256 curveId) = this.decodeCurveData(inputs[id]);

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                "" // IMission(mission).getMissionTitle(missionId)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                "" // string.concat("# of participants: ", SVG._uint2str(IMission(mission).getMissionStarts(missionId)))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "280"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    // "# of 100% completions: ", SVG._uint2str(IMission(mission).getMissionCompletions(missionId))
                )
            ),
            buildTasksCompletions(missionId),
            buildTicker(curveId)
        );
    }

    function buildTasksCompletions(uint256 missionId) public view returns (string memory) {
        // if (missionId != 0) {
        //     uint256[] memory taskIds = IMission(mission).getMissionTaskIds(missionId);
        //     uint256 length = (taskIds.length > 5) ? 5 : taskIds.length;
        //     string memory text;

        //     for (uint256 i; i < length; ++i) {
        //         text = string.concat(
        //             text,
        //             SVG._text(
        //                 string.concat(
        //                     SVG._prop("x", "20"),
        //                     SVG._prop("y", SVG._uint2str(140 + 20 * i)),
        //                     SVG._prop("font-size", "12"),
        //                     SVG._prop("fill", "#808080")
        //                 ),
        //                 string.concat(
        //                     IMission(mission).getTaskTitle(taskIds[i]),
        //                     ": "
        //                     SVG._uint2str(IMission(mission).getTotalTaskCompletionsByMission(missionId, taskIds[i]))
        //                 )
        //             )
        //         );
        //     }
        //     return text;
        // } else {
        //     return SVG.NULL;
        // }
    }

    function buildTicker(uint256 curveId) public view returns (string memory) {
        uint256 priceToMint =
            (curveId == 0 || curve == address(0)) ? 0 : IImpactCurve(curve).getCurvePrice(true, curveId, 0);
        uint256 priceToBurn =
            (curveId == 0 || curve == address(0)) ? 0 : IImpactCurve(curve).getCurvePrice(false, curveId, 0);

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "230"),
                    SVG._prop("y", "25"),
                    SVG._prop("font-size", "9"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🪙  ", convertToCurrencyForm(priceToMint), unicode" Ξ")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "230"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "9"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🔥  ", convertToCurrencyForm(priceToBurn), unicode" Ξ")
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// Helper Logic
    /// -----------------------------------------------------------------------

    function encodeSvgInputs(uint128 missionId, uint128 curveId) external pure virtual returns (bytes32) {
        return bytes32(abi.encodePacked(missionId, curveId));
    }

    function decodeCurveData(bytes32 key) external pure virtual returns (uint256, uint256) {
        // Declare variables to return later.
        uint128 curveId;
        uint128 missionId;

        // Parse data via assembly.
        assembly {
            curveId := key
            missionId := shr(128, key)
        }

        return (uint256(missionId), uint256(curveId));
    }

    function convertToCurrencyForm(uint256 amount) internal view virtual returns (string memory) {
        string memory decimals;
        for (uint256 i; i < 4; ++i) {
            uint256 decimalPoint = 1 ether / (10 ** i);
            if (amount % decimalPoint > 0) {
                decimals = string.concat(decimals, SVG._uint2str(amount % decimalPoint / (decimalPoint / 10)));
            } else {
                decimals = string.concat(decimals, SVG._uint2str(0));
            }
        }

        return string.concat(SVG._uint2str(amount / 1 ether), ".", decimals);
    }
}
