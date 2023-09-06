// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

// TODO: SVG NFT
import {ERC1155} from "../lib/solbase/src/tokens/ERC1155/ERC1155.sol";
import {SVG} from "./utils/SVG.sol";
import {JSON} from "./utils/JSON.sol";
import {Base64} from "../lib/solbase/src/utils/Base64.sol";
import {LibString} from "../lib/solbase/src/utils/LibString.sol";

import {Missions} from "./Missions.sol";
import {IMissions, Mission, Task, Metric} from "./interface/IMissions.sol";
import {IStorage} from "./interface/IStorage.sol";
import {Storage} from "./Storage.sol";
// import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
// import {IQuests} from "./interface/IQuests.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Major inspiration from Kali, Async.art
contract Minter is ERC1155 {
    /// -----------------------------------------------------------------------
    /// Custom Error
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error NotForSale();
    error AmountMismatch();
    error TransferFailed();

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

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
        (address missions, uint256 missionId) = decodeTokenId(id);
        return _buildURI(missions, missionId);
    }

    // credit: z0r0z.eth https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol
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
            this.consolidateMetrics(missions, m.taskIds),
            "</svg>"
        );
    }

    function consolidateMetrics(address missions, uint256[] calldata taskIds) public view returns (string memory) {
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
        }
    }

    /// -----------------------------------------------------------------------
    // Mint Logic
    /// -----------------------------------------------------------------------

    /// @dev Purchase an Impact NFT.
    function purchase(address missions, uint256 missionId) external payable {
        Mission memory mission = IMissions(missions).getMission(missionId);

        // Confirm Mission is for purchase.
        if (!mission.forPurchase) revert NotForSale();

        // Confirm fee is provided, if required.
        if (mission.fee != msg.value) revert AmountMismatch();

        // Calculate and transfer creator's royalties.
        uint256 royalties = IStorage(missions).getUint(ROYALTIES_KEY);
        royalties = msg.value * royalties / 100;
        (bool success,) = mission.creator.call{value: royalties}("");
        if (!success) revert TransferFailed();

        // Calculate and transfer remaining proceeds to DAO.
        address dao = IStorage(missions).getDao();
        (success,) = dao.call{value: mission.fee - royalties}("");
        if (!success) revert TransferFailed();

        // Prepare to mint
        uint256 id = getTokenId(missions, missionId);
        _mint(msg.sender, id, 1, "0x");
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function getTokenId(address missions, uint256 missionId) public pure returns (uint256) {
        return uint256(uint160(missions)) * 100 + missionId;
    }

    function decodeTokenId(uint256 tokenId) public pure returns (address missions, uint256 missionId) {
        missionId = tokenId % 100;
        missions = address(uint160((tokenId - missionId) / 100));
        return (missions, missionId);
    }

    receive() external payable virtual {}
}
