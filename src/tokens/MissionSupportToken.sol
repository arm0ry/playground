// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ERC1155} from "solbase/tokens/ERC1155/ERC1155.sol";

import {Mission} from "../Mission.sol";
import {IMission} from "../interface/IMission.sol";
import {IQuest} from "../interface/IQuest.sol";
import {IQuest} from "../interface/IQuest.sol";
import {IKaliCurve, CurveType} from "kali-markets/interface/IKaliCurve.sol";
import {IStorage} from "kali-markets/interface/IStorage.sol";
import {IKaliTokenManager} from "kali-markets/interface/IKaliTokenManager.sol";

/// @title Support SVG NFTs for Mission.
/// @notice SVG NFTs displaying impact generated from quests.
contract MissionSupportToken is ERC1155 {
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

    address public dao;
    address public curve;
    mapping(address => uint256) public unclaimed;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    constructor(address _curve) {
        curve = _curve;
    }
´
    modifier onlyActive(address missions, uint256 missionId) {
        if (block.timestamp > IMission(missions).getMissionDeadline(missionId)) revert NotActive();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view override returns (string memory) {
        return _buildURI(id);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 id) private view returns (string memory) {
        return JSON._formattedMetadata("Quest", "Description", generateSvg(id));
    }

    function generateSvg(uint256 id) public view returns (string memory) {
        (address missions, uint256 missionId, uint256 curveId) = this.decodeTokenId(id);
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            buildSvgData(missions, missionId, curveId),
            buildTreeRing(missions, missionId),
            "</svg>"
        );
    }

    function buildSvgData(address missions, uint256 missionId, uint256 curveId) public view returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Supporter")
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
                string.concat("Mint Price: ", SVG._uint2str(IKaliCurve(curve).getMintPrice(curveId)))
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
        string[] memory strArray;

        for (uint256 i = 0; i < taskIds.length;) {
            uint256 completions = IMission(missions).getTaskCompletions(taskIds[i]);

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
    /// DAO Logic
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// User Logic
    /// -----------------------------------------------------------------------

    /// @notice Claim unsuccessful transfers.
    function claim() external payable {
        uint256 amount = unclaimed[msg.sender];
        if (amount == 0) revert InvalidAmount();

        delete unclaimed[msg.sender];

        (bool success,) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// Patron Logic
    /// -----------------------------------------------------------------------

    ///
    function redeem(address user, address missions, uint256 missionId, uint256 curveId)
        external
        payable
        onlyActive(missions, missionId)
    {
        // Confirm user is a patron.
        if (IKaliTokenManager(IKaliCurve(curve).getImpactDao(curveId)).balanceOf(user) == 0) revert NotAuthorized();

        // Mint support tokens.
        _mint(msg.sender, this.getTokenId(missions, missionId, curveId), 1, "");
    }

    function support(address missions, uint256 missionId, uint256 curveId, uint256 amount)
        external
        payable
        onlyActive(missions, missionId)
    {
        // Calculate price to pay.
        uint256 price = IKaliCurve(curve).getMintBurnDifference(curveId) * amount;

        // Confirm msg.value is valid.
        if (price != msg.value) revert InvalidAmount();

        // Mint support tokens.
        _mint(msg.sender, this.getTokenId(missions, missionId, curveId), amount, "");

        // Confirm impactDAO exists.
        address impactDao = IKaliCurve(curve).getImpactDao(curveId);
        if (impactDao == address(0)) revert NotActive();

        // Transfer funds to impactDAO.
        (bool success,) = impactDao.call{value: price}("");
        if (!success) unclaimed[impactDao] = price;
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function getTokenId(address missions, uint256 missionId, uint256 curveId) external pure returns (uint256) {
        return uint256(bytes32(abi.encodePacked(missions, uint48(missionId), uint48(curveId))));
    }

    function decodeTokenId(uint256 tokenId) external pure returns (address, uint256, uint256) {
        // Convert tokenId from type uint256 to bytes32.
        bytes32 key = bytes32(tokenId);

        // Declare variables to return later.
        uint48 curveId;
        uint48 missionId;
        address missions;

        // Parse data via assembly.
        assembly {
            curveId := key
            missionId := shr(48, key)
            missions := shr(96, key)
        }

        return (missions, uint256(missionId), uint256(curveId));
    }
}
