// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";
import {Base64} from "../../lib/solbase/src/utils/Base64.sol";
import {LibString} from "../../lib/solbase/src/utils/LibString.sol";

import {Missions} from "../Missions.sol";
import {IMissions, Mission, Task, Metric} from "../interface/IMissions.sol";
import {IStorage} from "../interface/IStorage.sol";
import {Storage} from "../Storage.sol";
import {IQuest, QuestDetail} from "../interface/IQuest.sol";
import {pERC1155} from "../utils/pERC1155.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Major inspiration from Kali, Async.art
contract SupportToken is pERC1155 {
    /// -----------------------------------------------------------------------
    /// Custom Error
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error AmountMismatch();
    error TransferFailed();
    error InvalidQuest();

    /// -----------------------------------------------------------------------
    /// Storage
    /// -----------------------------------------------------------------------

    address public dao;

    address public quest;

    /// -----------------------------------------------------------------------
    /// Constructor & Modifier
    /// -----------------------------------------------------------------------

    constructor(address _dao) {
        dao = _dao;
    }

    modifier onlyDao() {
        if (dao != msg.sender) revert NotAuthorized();
        _;
    }

    /// -----------------------------------------------------------------------
    /// Metadata Storage & Logic
    /// -----------------------------------------------------------------------

    function uri(uint256 id) public view override returns (string memory) {
        return _buildURI(bytes32(id));
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(bytes32 questKey) private view returns (string memory) {
        return JSON._formattedMetadata("Quest Progress", "Description", generateImage(questKey));
    }

    function generateImage(bytes32 questKey) public view returns (string memory) {
        QuestDetail memory qd = IQuest(quest).getQuestDetail(questKey);

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
                string.concat("Progress: ", SVG._uint2str(qd.progress), "%")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"), SVG._prop("y", "90"), SVG._prop("font-size", "12"), SVG._prop("fill", "white")
                ),
                string.concat("# of steps completed: ", SVG._uint2str(qd.completed))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"), SVG._prop("y", "90"), SVG._prop("font-size", "12"), SVG._prop("fill", "white")
                ),
                string.concat("Deadline : ", SVG._uint2str(qd.deadline))
            ),
            "</svg>"
        );
    }

    /// -----------------------------------------------------------------------
    // Mint Logic
    /// -----------------------------------------------------------------------

    /// @dev Mint NFT.
    /// credit: simondlr (https://github.com/simondlr/neolastics/blob/master/packages/hardhat/contracts/Curve.sol)
    function mint(bytes32 questKey) external payable {
        // Mint support tokens
        // Confirm quest is active
        QuestDetail memory qd = IQuest(quest).getQuestDetail(questKey);
        if (!qd.active) revert InvalidQuest();

        uint256 mintPrice = getCurrentPriceToMint(uint256(questKey));
        if (msg.value < mintPrice) revert AmountMismatch();

        _mint(msg.sender, uint256(questKey), 1, "0x");
    }

    /// @dev Burn NFT
    /// credit: simondlr (https://github.com/simondlr/neolastics/blob/master/packages/hardhat/contracts/Curve.sol)
    function burn(bytes32 questKey) external payable {
        // Burn support tokens
        uint256 burnPrice = getCurrentPriceToBurn(uint256(questKey));
        _burn(msg.sender, uint256(questKey), 1);

        (bool success,) = msg.sender.call{value: burnPrice}("");
        if (!success) revert TransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function setQuestAddress(address _quest) external payable onlyDao {
        quest = _quest;
    }

    // credit: simondlr (https://github.com/simondlr/neolastics/blob/master/packages/hardhat/contracts/Curve.sol)
    function getCurrentPriceToMint(uint256 id) public view virtual returns (uint256) {
        uint256 initMintPrice = 0.001 ether; // at 0

        uint256 mintPrice = initMintPrice + totalSupply[id] * initMintPrice;
        return mintPrice;
    }

    // credit: simondlr (https://github.com/simondlr/neolastics/blob/master/packages/hardhat/contracts/Curve.sol)
    function getCurrentPriceToBurn(uint256 id) public view virtual returns (uint256) {
        uint256 initBurnPrice = 0.000995 ether; // at 1

        uint256 burnPrice = totalSupply[id] * initBurnPrice;
        return burnPrice;
    }

    receive() external payable virtual {}
}
