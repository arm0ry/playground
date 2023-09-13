// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "../utils/SVG.sol";
import {JSON} from "../utils/JSON.sol";

import {Missions} from "../Missions.sol";
import {IMissions, Mission, Task, Metric} from "../interface/IMissions.sol";
import {IStorage} from "../interface/IStorage.sol";
import {Storage} from "../Storage.sol";
import {IQuest, QuestDetail} from "../interface/IQuest.sol";
import {pERC1155} from "../utils/pERC1155.sol";

import {IERC721Metadata} from "../../lib/forge-std/src/interfaces/IERC721.sol";

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
        return _buildURI(id);
    }

    // credit: z0r0z.eth (https://github.com/kalidao/kali-contracts/blob/60ba3992fb8d6be6c09eeb74e8ff3086a8fdac13/contracts/access/KaliAccessManager.sol)
    function _buildURI(uint256 id) private view returns (string memory) {
        return JSON._formattedMetadata("Quest", "Description", generateSvg(id));
    }

    function generateSvg(uint256 id) public view returns (string memory) {
        (bytes32 questKey, QuestDetail memory qd) = IQuest(quest).getQuestDetail(bytes32(id), 0x0);

        uint256 cd = IStorage(quest).getUint(keccak256(abi.encodePacked("quest.cd")));

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            buildSvgLogo(),
            buildSvgData(cd, questKey, qd.toReview, qd.deadline),
            buildSvgProgress(qd.progress),
            buildSvgProfile(),
            "</svg>"
        );
    }

    function buildSvgProgress(uint256 progress) public pure returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "145"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Progress: ", SVG._uint2str(progress), "%")
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#ffecb6"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "165"),
                    SVG._prop("width", SVG._uint2str(250)),
                    SVG._prop("height", SVG._uint2str(20)),
                    SVG._prop("opacity", SVG._uint2str(25))
                ),
                SVG.NULL
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#C60000"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "165"),
                    SVG._prop("width", SVG._uint2str(uint256(250) * uint256(progress) / uint256(100))),
                    SVG._prop("height", SVG._uint2str(20))
                ),
                SVG.NULL
            )
        );
    }

    function buildSvgData(uint256 cd, bytes32 questKey, bool toReview, uint40 deadline)
        public
        view
        returns (string memory)
    {
        (address missions, uint256 missionId,) = IQuest(quest).decodeKey(questKey);

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Mission #", SVG._uint2str(missionId))
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
                IMissions(missions).getMissionTitle(missionId)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "220"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(
                    "# of steps to complete: ", SVG._uint2str(IMissions(missions).getMissionTaskCount(missionId))
                )
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "240"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Cooldown: ", SVG._uint2str(cd))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "280"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Review required: ", toReview ? unicode"🧑‍🏫" : unicode"🙅")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("Deadline: ", SVG._uint2str(deadline))
            )
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

    function buildSvgProfile() public pure returns (string memory) {
        return string.concat(
            SVG._image(
                "https://arm0ry.g0v.tw/assets/dancing.cbe2e558.png",
                string.concat(SVG._prop("x", "220"), SVG._prop("y", "230"), SVG._prop("width", "50"))
            )
        );
    }

    /// -----------------------------------------------------------------------
    // Mint Logic
    /// -----------------------------------------------------------------------

    /// @dev Mint NFT.
    /// credit: simondlr (https://github.com/simondlr/neolastics/blob/master/packages/hardhat/contracts/Curve.sol)
    function mint(uint256 id) external payable {
        // Confirm quest is active
        (, QuestDetail memory qd) = IQuest(quest).getQuestDetail(bytes32(id), 0x0);
        if (!qd.active) revert InvalidQuest();

        // Get current mint price
        uint256 mintPrice = getCurrentPriceToMint(id);
        if (msg.value < mintPrice) revert AmountMismatch();

        _mint(msg.sender, id, 1, "0x");
    }

    /// @dev Burn NFT
    /// credit: simondlr (https://github.com/simondlr/neolastics/blob/master/packages/hardhat/contracts/Curve.sol)
    function burn(uint256 id) external payable {
        // Burn support tokens
        uint256 burnPrice = getCurrentPriceToBurn(id);
        _burn(msg.sender, id, 1);

        (bool success,) = msg.sender.call{value: burnPrice}("");
        if (!success) revert TransferFailed();
    }

    /// -----------------------------------------------------------------------
    /// DAO Functions
    /// -----------------------------------------------------------------------

    function setDao(address _quest) external payable onlyDao {
        quest = _quest;
    }

    function setQuest(address _quest) external payable onlyDao {
        quest = _quest;
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

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
