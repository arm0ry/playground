// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {Base64} from "../../lib/solbase/src/utils/Base64.sol";
import {LibString} from "../../lib/solbase/src/utils/LibString.sol";
import {ERC1155} from "../../lib/solbase/src/tokens/ERC1155/ERC1155.sol";

import {Missions} from "../Missions.sol";
import {IMissions, Mission, Task, Metric} from "../interface/IMissions.sol";
import {IStorage} from "../interface/IStorage.sol";
import {Storage} from "../Storage.sol";
import {IQuest, QuestDetail} from "../interface/IQuest.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Major inspiration from Kali, Async.art
contract ImpactNft is ERC1155 {
    /// -----------------------------------------------------------------------
    /// Custom Error
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error NotForSale();
    error AmountMismatch();
    error TransferFailed();
    error InvalidMission();
    error InvalidQuest();

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    bytes32 immutable QUEST_ADDRESS_KEY = keccak256(abi.encodePacked("quest"));
    bytes32 immutable ROYALTIES_KEY = keccak256(abi.encodePacked("royalties.default"));
    bytes32 immutable TOKEN_ID_KEY = keccak256(abi.encodePacked("id"));

    /// -----------------------------------------------------------------------
    /// Traveler Storage
    /// -----------------------------------------------------------------------

    constructor() {}

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view override returns (string memory) {
        (address missions, uint256 missionId) = this.decodeTokenId(id);

        return _buildURI(missions, missionId);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(address missions, uint256 missionId) private view returns (string memory) {
        Mission memory m = IMissions(missions).getMission(missionId);

        return JSON._formattedMetadata("Missions", m.title, generateImage(missions, missionId, m));
    }

    function generateImage(address missions, uint256 missionId, Mission memory m) public view returns (string memory) {
        uint256 mDeadline = IMissions(missions).getMissionDeadline(missionId);

        uint256 mCompletions =
            IStorage(missions).getUint(keccak256(abi.encodePacked(missions, missionId, ".completions")));

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#191919">',
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "maroon"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "50"),
                    SVG._prop("width", SVG._uint2str(160)),
                    SVG._prop("height", SVG._uint2str(10))
                ),
                SVG.NULL
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"), SVG._prop("y", "90"), SVG._prop("font-size", "12"), SVG._prop("fill", "white")
                ),
                string.concat("Complete by: ", SVG._uint2str(mDeadline))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"), SVG._prop("y", "90"), SVG._prop("font-size", "12"), SVG._prop("fill", "white")
                ),
                string.concat("# of steps to complete: ", SVG._uint2str(m.taskIds.length))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"), SVG._prop("y", "90"), SVG._prop("font-size", "12"), SVG._prop("fill", "white")
                ),
                string.concat("# of completions : ", SVG._uint2str(mCompletions))
            ),
            consolidateMetrics(missions, m.taskIds),
            "</svg>"
        );
    }

    function consolidateMetrics(address missions, uint256[] memory taskIds) public view returns (string memory) {
        Metric[] memory metrics = IMissions(missions).getMetrics(taskIds);

        if (metrics.length > 0) {
            return string.concat(
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", "90"),
                        SVG._prop("font-size", "12"),
                        SVG._prop("fill", "white")
                    ),
                    string.concat(metrics[0].title, ": ", SVG._uint2str(metrics[0].value))
                ),
                SVG._text(
                    string.concat(
                        SVG._prop("x", "20"),
                        SVG._prop("y", "90"),
                        SVG._prop("font-size", "12"),
                        SVG._prop("fill", "white")
                    ),
                    string.concat(metrics[1].title, ": ", SVG._uint2str(metrics[1].value))
                )
            );
        } else {
            return "";
        }
    }

    /// -----------------------------------------------------------------------
    // Mint Logic
    /// -----------------------------------------------------------------------

    /// @dev Mint NFT.
    function mint(address missions, uint256 missionId) external payable {
        // Mint impact NFT
        if (IStorage(missions).getDao() == address(0)) revert InvalidMission();

        Mission memory mission = IMissions(missions).getMission(missionId);

        // Confirm Mission is for purchase.
        if (!mission.forPurchase) revert NotForSale();

        // Confirm fee is provided, if required.
        if (mission.fee != msg.value) revert AmountMismatch();

        // Prepare to mint
        uint256 id = this.getTokenId(missions, missionId);
        _mint(msg.sender, id, 1, "0x");

        // Calculate and distribute creator's royalties.
        uint256 royalties = IStorage(missions).getUint(ROYALTIES_KEY);
        royalties = msg.value * royalties / 100;
        (bool success,) = mission.creator.call{value: royalties}("");
        if (!success) revert TransferFailed();

        // Calculate and distribute remaining proceeds to DAO.
        address dao = IStorage(missions).getDao();
        (success,) = dao.call{value: mission.fee - royalties}("");
        if (!success) revert TransferFailed();
    }

    /// @dev Burn NFT
    function burn(address missions, uint256 missionId) external payable {
        // Burn impact NFT
        uint256 id = this.getTokenId(missions, missionId);
        _burn(msg.sender, id, 1);
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

    receive() external payable virtual {}
}
