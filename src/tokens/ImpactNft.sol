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
    error InvalidBuy();

    /// -----------------------------------------------------------------------
    /// Emoji Storage
    /// -----------------------------------------------------------------------

    mapping(uint256 => bool) useEmojis;
    mapping(uint256 => string) public emojis;

    /// -----------------------------------------------------------------------
    /// Harberger Tax Storage
    /// -----------------------------------------------------------------------

    mapping(uint256 => uint256) public taxes;
    mapping(uint256 => uint256) public prices;
    mapping(uint256 => uint256) public deposits; // funds for paying patronage.
    mapping(uint256 => uint256) public totalCollected; // total patronage collected.

    mapping(address => bool) public patrons;
    mapping(uint256 => uint256) public timeCollected; // timestamp when last collection occurred.
    mapping(uint256 => uint256) public timeAcquired;

    mapping(address => uint256) public totalUnclaimed; // unclaimed patronage.
    mapping(address => uint256) public timeHeld; // time held by particular patron

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    // bytes32 immutable QUEST_ADDRESS_KEY = keccak256(abi.encodePacked("quest"));

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() ERC721("PatronImpact", "PI") {
        _installBaseEmojis();
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
        return JSON._formattedMetadata("Patron Impage", "", generateSvg(missions, missionId, tokenId));
    }

    function generateSvg(address missions, uint256 missionId, uint256 tokenId) public view returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#191919">',
            buildSvgLogo(),
            buildSvgData(missions, missionId, tokenId),
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

    function buildSvgData(address missions, uint256 missionId, uint256 tokenId) public view returns (string memory) {
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
                string.concat("Harberger Tax: ", SVG._uint2str(this.tax(tokenId)))
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
        Metric memory metric = IMissions(missions).getMetrics(missionId);

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "190"),
                    SVG._prop("font-size", "10"),
                    SVG._prop("fill", "8FADFF")
                ),
                string.concat(metric.title)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "70"),
                    SVG._prop("y", "195"),
                    SVG._prop("font-size", "60"),
                    SVG._prop("fill", "FFBE0B")
                ),
                string.concat(useEmojis[missionId] ? emojis[metric.value] : SVG._uint2str(metric.value))
            )
        );
    }

    /// -----------------------------------------------------------------------
    // Mint Logic
    /// -----------------------------------------------------------------------

    /// @dev Mint NFT.
    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function buy(address missions, uint256 missionId, uint256 _newPrice, uint256 _currentPrice) external payable {
        address dao = IStorage(missions).getDao();
        if (dao == address(0)) revert InvalidMission();

        Mission memory mission = IMissions(missions).getMission(missionId);

        // Confirm Mission is for purchase.
        if (!mission.forPurchase) revert NotForSale();

        uint256 tokenId = this.getTokenId(missions, missionId);
        uint256 price = prices[tokenId];

        if (price != 0) {
            // price > 0 == active owned state
            _collectPatronage(tokenId);
        }
        if (price != _currentPrice || _newPrice == 0 || msg.value != _currentPrice) revert InvalidBuy();

        address currentOwner = ownerOf(tokenId);
        uint256 deposit = deposits[tokenId];
        uint256 totalToPayBack = price + deposit;
        if (totalToPayBack > 0) {
            // this won't execute if steward owns it. price = 0. deposit = 0.
            // pay previous owner their price + deposit back.
            // address payable payableCurrentOwner = address(uint160(currentOwner));
            (bool success,) = currentOwner.call{value: totalToPayBack}("");

            // if the send fails, keep the funds separate for the owner
            if (!success) totalUnclaimed[currentOwner] += totalToPayBack;
        }

        // new purchase
        timeCollected[tokenId] = block.timestamp;

        deposit = msg.value - price;
        transferArtworkTo(tokenId, currentOwner, msg.sender, _newPrice);
    }

    /// @dev Burn NFT
    function burn(address missions, uint256 missionId) external payable {
        // Burn impact NFT
        uint256 id = this.getTokenId(missions, missionId);
        _burn(id);
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function foreclosureTime(uint256 tokenId) public view returns (uint256) {
        uint256 pps = prices[tokenId] / 365 days * (this.tax(tokenId) / 100);
        (, uint256 daw) = isForeclosed(tokenId);
        if (daw > 0) {
            return block.timestamp + daw / pps;
        } else if (pps > 0) {
            // it is still active, but in foreclosure state
            // it is block.timestamp or was in the past
            uint256 collection = patronageOwed(tokenId);
            return timeCollected[tokenId] + (block.timestamp - timeCollected[tokenId]) * deposits[tokenId] / collection;
        } else {
            // not active and actively foreclosed (price is zero)
            return timeCollected[tokenId]; // it has been foreclosed or in foreclosure.
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

    function tax(uint256 tokenId) external view returns (uint256) {
        uint256 _tax = taxes[tokenId];
        (taxes[tokenId] == 0) ? _tax = 50 : _tax; // default tax rate is 50%
        return _tax;
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function patronageOwed(uint256 tokenId) public view returns (uint256 patronageDue) {
        return prices[tokenId] * ((block.timestamp - timeCollected[tokenId]) / 365 days) * (this.tax(tokenId) / 100);
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function isForeclosed(uint256 tokenId) public view returns (bool, uint256) {
        // returns whether it is in foreclosed state or not
        // depending on whether deposit covers patronage due
        // useful helper function when price should be zero, but contract doesn't reflect it yet.
        uint256 collection = patronageOwed(tokenId);
        uint256 deposit = deposits[tokenId];
        if (collection >= deposit) {
            return (true, 0);
        } else {
            return (false, deposit - collection);
        }
    }

    function _installBaseEmojis() internal {
        emojis[1] = unicode"👍";
        emojis[2] = unicode"👎";
        emojis[3] = unicode"😜";
        emojis[4] = unicode"🥰";
        emojis[5] = unicode"🥳";
        emojis[6] = unicode"💪";
        emojis[7] = unicode"🙌";
    }

    function emoji(address missions, uint256 missionId, bool _useEmoji) external payable {
        address dao = IStorage(missions).getDao();
        if (dao == address(0)) revert InvalidMission();

        useEmojis[missionId] = _useEmoji;
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function _foreclose(uint256 tokenId) internal {
        transferFrom(ownerOf(tokenId), address(this), tokenId);
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function _collectPatronage(uint256 tokenId) internal {
        uint256 collection = patronageOwed(tokenId);
        uint256 deposit = deposits[tokenId];
        uint256 _timeCollected = timeCollected[tokenId];

        if (collection >= deposit) {
            // foreclosure happened in the past
            // up to when was it actually paid for?
            // TLC + (time_elapsed)*deposit/collection
            _timeCollected = _timeCollected + (block.timestamp - _timeCollected) * deposit / collection;
            collection = deposit; // take what's left.
        } else {
            _timeCollected = block.timestamp;
        } // normal collection

        deposit -= collection;
        totalCollected[tokenId] += collection;

        if (deposit == 0) _foreclose(tokenId);
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function transferArtworkTo(uint256 tokenId, address _currentOwner, address _newOwner, uint256 _newPrice) internal {
        // note: it would also tabulate time held in stewardship by smart contract
        timeHeld[_currentOwner] = timeHeld[_currentOwner] + timeCollected[tokenId] - timeAcquired[tokenId];

        if (_currentOwner == address(0)) {
            // Mint
            _mint(_newOwner, tokenId);
        }

        // Otherwise transfer ownership
        transferFrom(_currentOwner, _newOwner, tokenId);

        prices[tokenId] = _newPrice;
        timeAcquired[tokenId] = block.timestamp;
        patrons[_newOwner] = true;
    }

    receive() external payable virtual {}
}
