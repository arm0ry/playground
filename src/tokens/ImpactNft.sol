// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {Base64} from "../../lib/solbase/src/utils/Base64.sol";
import {LibString} from "../../lib/solbase/src/utils/LibString.sol";
import {ERC721} from "../../lib/solbase/src/tokens/ERC721/ERC721.sol";

import {Missions} from "../Missions.sol";
import {IMissions, Mission, Task, Metric} from "../interface/IMissions.sol";
import {IStorage} from "../interface/IStorage.sol";
import {Storage} from "../Storage.sol";
import {IQuest, QuestDetail} from "../interface/IQuest.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Major inspiration from Kali, Async.art
contract ImpactNft is ERC721 {
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
    /// Harberger Tax Storage
    /// -----------------------------------------------------------------------

    mapping(uint256 => uint256) public prices;
    mapping(uint256 => uint256) public timeAcquired;
    mapping(uint256 => uint256) public timeCollected; // timestamp when last collection occurred
    mapping(uint256 => uint256) public deposits; // funds for paying patronage
    mapping(uint256 => uint256) public totalCollected; // timestamp when last collection occurred

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    bytes32 immutable QUEST_ADDRESS_KEY = keccak256(abi.encodePacked("quest"));
    // bytes32 immutable CREATOR_FEE_KEY = keccak256(abi.encodePacked("fee.default"));
    bytes32 immutable TOKEN_ID_KEY = keccak256(abi.encodePacked("id"));

    modifier collectPatronage() {
        _collectPatronage();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Constructor
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

    /// TODO: Add Harberger Tax
    /// @dev Mint NFT.
    function buy(address missions, uint256 missionId, uint256 _newPrice, uint256 _currentPrice) external payable {
        address dao = IStorage(missions).getDao();
        if (dao == address(0)) revert InvalidMission();

        Mission memory mission = IMissions(missions).getMission(missionId);

        // Confirm Mission is for purchase.
        if (!mission.forPurchase) revert NotForSale();

        // Mint ImpactNFT
        uint256 id = this.getTokenId(missions, missionId);
        _mint(msg.sender, id, 1, "0x");

        // If dao and creator are the same, distribute proceeds in full
        // if (dao == mission.creator) {
        //     // Calculate and distribute proceeds to creator.
        //     (bool success,) = mission.creator.call{value: mission.ask}("");
        //     if (!success) revert TransferFailed();
        // } else {
        //     // Otherwise, calculate and distribute creator's fee.
        //     uint256 fee = IStorage(missions).getUint(CREATOR_FEE_KEY);
        //     fee = msg.value * fee / 100;
        //     (bool success,) = mission.creator.call{value: fee}("");
        //     if (!success) revert TransferFailed();

        //     // Then, calculate and distribute remaining proceeds to DAO.
        //     (success,) = dao.call{value: mission.ask - fee}("");
        //     if (!success) revert TransferFailed();
        // }
    }

    /// @dev Burn NFT
    function burn(address missions, uint256 missionId) external payable {
        // Burn impact NFT
        uint256 id = this.getTokenId(missions, missionId);
        _burn(msg.sender, id, 1);
    }

    function foreclosed(uint256 tokenId) public view returns (bool) {
        // returns whether it is in foreclosed state or not
        // depending on whether deposit covers patronage due
        // useful helper function when price should be zero, but contract doesn't reflect it yet.
        uint256 collection = patronageOwed(tokenId);
        if (collection >= deposits[tokenId]) {
            return true;
        } else {
            return false;
        }
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

    // TODO: DO 50% HT Rate
    function patronageOwed(uint256 tokenId) public view returns (uint256 patronageDue) {
        //return price.mul(block.timestamp.sub(timeLastCollected)).mul(patronageNumerator).div(patronageDenominator).div(365 days);
        return prices[tokenId].mul(block.timestamp.sub(timeCollected[tokenId])).div(365 days);
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function _forecloseIfNecessary(uint256 tokenId) internal {
        if (deposits[tokenId] == 0) {
            // TODO: Get current owner
            // address currentOwner = art.ownerOf(42);
            address currentOwner;
            transferFrom(currentOwner, address(this), tokenId);
        }
    }

    // https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function _collectPatronage(uint256 tokenId) internal {
        if (prices[tokenId] != 0) {
            // price > 0 == active owned state
            uint256 collection = patronageOwed();

            if (collection >= deposits[tokenId]) {
                // foreclosure happened in the past
                // up to when was it actually paid for?
                // TLC + (time_elapsed)*deposit/collection
                timeCollected[tokenId] = timeCollected[tokenId].add(
                    (block.timestamp.sub(timeCollected[tokenId])).mul(deposits[tokenId]).div(collection)
                );
                collection = deposits[tokenId]; // take what's left.
            } else {
                timeCollected[tokenId] = block.timestamp;
            } // normal collection

            deposits[tokenId] = deposits[tokenId].sub(collection);
            totalCollected[tokenId] = totalCollected[tokenId].add(collection);

            _forecloseIfNecessary(tokenId);
        }
    }

    receive() external payable virtual {}
}
