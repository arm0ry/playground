// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Missions} from "../Missions.sol";
import {IMissions, Mission, Task, Metric} from "../interface/IMissions.sol";
import {IStorage} from "../interface/IStorage.sol";
import {Storage} from "../Storage.sol";
import {IQuest, QuestDetail} from "../interface/IQuest.sol";

import {KaliDAOfactory, KaliDAO} from "../kali/KaliDAOfactory.sol";
import {IKaliTokenManager} from "../interface/IKaliTokenManager.sol";

import {IERC721} from "../../lib/forge-std/src/interfaces/IERC721.sol";

/// @title Impact NFTs
/// @notice SVG NFTs displaying impact results and metrics.
/// Major inspiration from Kali, Async.art
contract KaliBerger is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Error
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error NotForSale();
    error AmountMismatch();
    error TransferFailed();
    error InvalidMission();
    error InvalidQuest();
    error InvalidMint();
    error InvalidPrice();
    error InvalidRoyalties();
    error NotPatron();

    /// -----------------------------------------------------------------------
    /// Emoji Storage
    /// -----------------------------------------------------------------------

    bool useEmoji;

    /// -----------------------------------------------------------------------
    /// Harberger Tax Storage
    /// -----------------------------------------------------------------------

    mapping(uint256 => mapping(address => uint256)) public totalCollectedByPatron; // total patronage collected by patron
    mapping(uint256 => uint256) public totalCollected; // total patronage collected.

    mapping(address => bool) public patrons;

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    bytes32 immutable ROYALTIES_KEY = keccak256(abi.encodePacked("royalties.default"));

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    constructor() {}

    modifier onlyPatron(address target, uint256 value) {
        if (msg.sender != this.getOwner(target, value)) revert NotPatron();
        _;
    }

    modifier collectPatronage(address target, uint256 value) {
        _collectPatronage(target, value);
        _;
    }

    /// -----------------------------------------------------------------------
    // Mint Logic
    /// -----------------------------------------------------------------------

    /// @notice Escrow ERC721 NFT before making available for purchase.
    function escrow(address token, uint256 tokenId, uint256 price) external payable {
        if (price == 0) revert InvalidPrice();
        if (IERC721(token).ownerOf(tokenId) != msg.sender) revert NotAuthorized();
        IERC721(token).safeTransferFrom(msg.sender, address(this), tokenId);
        this.setPrice(token, tokenId, price);
    }

    /// @notice Enable Playground NFT for sale.
    function enable(address missions, uint256 missionId, uint256 price) external payable {
        if (price == 0) revert InvalidPrice();
        IERC721(missions).safeTransferFrom(msg.sender, address(this), missionId);
        this.setPrice(missions, missionId, price);
    }

    // TODO: Need to trigger rebalanncing for all members
    function balanceDao(address target, uint256 value, address creator, uint256 price) external payable {
        // Get address to DAO to manage revenue from Harberger Tax
        address sustainableDAO = this.getAddress(keccak256(abi.encode(target, value, ".dao")));
        if (sustainableDAO == address(0)) {
            // Summon DAO if not already summoned
            sustainableDAO = KaliDAOfactory(factory).deployKaliDAO();
        }

        uint256 ratio = totalCollectedByPatron[tokenId][msg.sender] * 100 / totalCollected[tokenId];

        // Ensure ratio is same as that of member DAO token amount to total DAO token amount
        uint256 totalSupply = KaliDAO(sustainableDAO).totalSupply();
        uint256 buyerBalance = KaliDAO(sustainableDAO).balanceOf(msg.sender);
        uint256 _ratio = buyBalance * 100 / totalSupply;

        uint256 amount;
        if (ratio >= _ratio) {
            amount = (ratio - _ratio) * totalSupply;
            IKaliTokenManager(sustainableDAO).mintShares(creator, amount);
            IKaliTokenManager(sustainableDAO).mintShares(msg.sender, amount);
        } else {
            amount = (_ratio - ratio) * totalSupply;
            IKaliTokenManager(sustainableDAO).burnShares(creator, amount);
            IKaliTokenManager(sustainableDAO).burnShares(msg.sender, amount);
        }
    }

    function handleRoyalties(address token, uint256 tokenId, uint256 price) internal returns (uint256) {
        address creator = this.getAddress(keccak256(abi.encode(token, tokenId, ".creator")));
        if (creator == address(0)) {
            return price;
        } else {
            uint256 royalties = this.getRoyalties();
            uint256 payout;

            unchecked {
                payout = price * royalties / 100;
            }

            (bool success,) = creator.call{value: payout}("");
            if (!success) totalUnclaimed[creator] += payout;

            return price - payout;
        }
    }

    /// @notice Buy ERC721 NFT.
    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function buy(address token, uint256 tokenId, uint256 _newPrice, uint256 _currentPrice)
        external
        payable
        collectPatronage(token, tokenId)
    {
        uint256 price = this.getPrice(token, tokenId);
        if (price != _currentPrice || _newPrice == 0 || msg.value != _currentPrice) revert InvalidMint();

        address currentOwner = IERC721(token).ownerOf(tokenId);
        uint256 _deposit = this.getDeposit(token, tokenId);

        // Pay royalties, if any
        price = handleRoyalties(token, tokenId, price);

        uint256 totalToPayBack = price + _deposit;
        if (totalToPayBack > 0) {
            // this won't execute if steward owns it. price = 0. deposit = 0.
            // pay previous owner their price + deposit back.
            (bool success,) = currentOwner.call{value: totalToPayBack}("");
            if (!success) this.addUint(keccak256(abi.encode(currentOwner, ".unclaimed")), totalToPayBack);
        }

        // Update time of collection
        // Update deposit, if any.
        _deposit = msg.value - price;
        this.addDeposit(token, tokenId, _deposit);

        transferArtworkTo(tokenId, currentOwner, msg.sender, _newPrice);

        // Balance DAO according to updated contribution.
        this.balanceDao(token, tokenId, address(0), price);
    }

    /// @notice Buy Playground NFT.
    function buy(address target, uint256 value, uint256 _newPrice, uint256 _currentPrice)
        external
        payable
        collectPatronage(target, value)
    {
        // Check if Playground contracts
        address dao = IStorage(target).getDao();
        if (dao != address(0)) revert InvalidMission();

        Mission memory mission = IMissions(target).getMission(value);
        // Confirm Mission is for purchase.

        if (!mission.forPurchase) revert NotForSale();

        uint256 price = this.getPrice(target, value);
        if (price != _currentPrice || _newPrice == 0 || msg.value != _currentPrice) revert InvalidMint();

        // todo: fix below
        address currentOwner = IERC721(target).ownerOf(tokenId);
        uint256 _deposit = deposits[tokenId];
        uint256 totalToPayBack = price + _deposit;
        if (totalToPayBack > 0) {
            // this won't execute if steward owns it. price = 0. deposit = 0.
            // pay previous owner their price + deposit back.
            // address payable payableCurrentOwner = address(uint160(currentOwner));
            (bool success,) = currentOwner.call{value: totalToPayBack}("");
            if (!success) totalUnclaimed[currentOwner] += totalToPayBack;
        }

        // new purchas
        _deposit = msg.value - price;
        this.addDeposit(token, tokenId, _deposit);
        transferArtworkTo(tokenId, currentOwner, msg.sender, _newPrice);

        this.balanceDao(target, value, mission.creator, price);
    }

    /* Only Patron Actions */
    function deposit(address target, uint256 value) external payable collectPatronage onlyPatron {
        this.addDeposit(target, value, msg.value);
    }

    function changePrice(uint256 price) public collectPatronage onlyPatron {
        if (price == 0) revert InvalidPrice();
        this.setPrice(target, value, price);
    }

    function withdrawDeposit(uint256 _wei) public collectPatronage onlyPatron {
        _withdrawDeposit(_wei);
    }

    function exit() public collectPatronage onlyPatron {
        _withdrawDeposit(deposit);
    }

    /* Actions that don't affect state of the artwork */
    /* Artist Actions */
    function withdrawArtistFunds() public {
        require(msg.sender == artist, "Not artist");
        uint256 toSend = artistFund;
        artistFund = 0;
        artist.transfer(toSend);
    }

    /* Withdrawing Stuck Deposits */
    /* To reduce complexity, pull funds are entirely separate from current deposit */
    function withdrawPullFunds() public {
        require(pullFunds[msg.sender] > 0, "No pull funds available.");
        uint256 toSend = pullFunds[msg.sender];
        pullFunds[msg.sender] = 0;
        msg.sender.transfer(toSend);
    }

    /* internal */
    function _withdrawDeposit(uint256 _wei) internal {
        // note: can withdraw whole deposit, which puts it in immediate to be foreclosed state.
        require(deposit >= _wei, "Withdrawing too much");

        deposit = deposit.sub(_wei);
        msg.sender.transfer(_wei); // msg.sender == patron

        _forecloseIfNecessary();
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    // function encode(address missions, uint256 missionId) external pure returns (uint256) {
    //     return uint256(bytes32(abi.encodePacked(missions, uint96(missionId))));
    // }

    // function decode(uint256 tokenId) external pure returns (address missions, uint256 missionId) {
    //     uint96 _id;
    //     bytes32 key = bytes32(tokenId);
    //     assembly {
    //         _id := key
    //         missions := shr(96, key)
    //     }
    //     return (missions, uint256(_id));
    // }

    function setTax(address target, uint256 value, uint256 _tax) external payable onlyPlayground(target, value) {
        this.setUint(keccak256(abi.encode(target, value)), _tax);
    }

    function getTax(address target, uint256 value) external view returns (uint256 _tax) {
        _tax = this.getUint(keccak256(abi.encode(target, value)));
        return (_tax == 0) ? _tax = 50 : _tax; // default tax rate is hardcoded at 50%
    }

    function setPrice(address target, uint256 value, uint256 price) external payable onlyPlayground(target, value) {
        this.setUint(keccak256(abi.encode(target, value, ".price")), price);
    }

    function getPrice(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".price")));
    }

    function setRoyalties(address token, uint256 tokenId, address creator, uint256 royalties)
        external
        payable
        onlyPlayground(token, tokenId)
    {
        if (creator != address(0) && royalties != 0) revert InvalidRoyalties();
        this.setAddress(keccak256(abi.encode(token, tokenId, ".creator")), creator);
        this.setUint(keccak256(abi.encode(token, tokenId, ".royalties")), royalties);
    }

    function getRoyalties(address target, uint256 value) external view returns (uint256) {
        return this.getUint(ROYALTIES_KEY);
    }

    function addDeposit(address target, uint256 value, uint256 _deposit) external payable onlyPatron(target, value) {
        return this.addUint(keccak256(abi.encode(target, value, ".deposit")), _deposit);
    }

    function getDeposit(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".deposit")));
    }

    function setTimeAcquired(address target, uint256 value, uint256 timestamp) internal {
        this.setUint(keccak256(abi.encode(target, value, ".timeAcquired")), timestamp);
    }

    function getTimeAcquired(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".timeAcquired")));
    }

    function setUnclaimed(address user, uint256 amount) internal {
        this.setUint(keccak256(abi.encode(user, ".unclaimed")), amount);
    }

    function getUnclaimed(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    function addTimeHeld(address user, uint256 time) internal {
        this.addUint(keccak256(abi.encode(user, ".timeHeld")), time);
    }

    function getTimeHeld(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".timeHeld")));
    }

    function setOwner(address target, uint256 value, address owner) internal {
        this.setAddress(keccak256(abi.encode(target, value, ".owner")), owner);
    }

    function getOwner(address target, uint256 value) external view returns (uint256) {
        return this.getAddress(keccak256(abi.encode(target, value, ".owner")));
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol

    function patronageToCollect(address target, uint256 value) public view returns (uint256 amount) {
        return this.getPrice(target, value) * ((block.timestamp - this.getTimeLastCollected(target, value)) / 365 days)
            * (this.getTax(value) / 100);
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function isForeclosed(address target, uint256 value) public view returns (bool, uint256) {
        // returns whether it is in foreclosed state or not
        // depending on whether deposit covers patronage due
        // useful helper function when price should be zero, but contract doesn't reflect it yet.
        uint256 toCollect = patronageToCollect(target, value);
        uint256 _deposit = this.getDeposit(target, value);
        if (toCollect >= _deposit) {
            return (true, 0);
        } else {
            return (false, _deposit - toCollect);
        }
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function foreclosureTime(address target, uint256 value) external view returns (uint256) {
        uint256 pps = getPrice(target, value) / 365 days * (this.getTax(tokenId) / 100);
        (, uint256 daw) = isForeclosed(target, value);
        if (daw > 0) {
            return block.timestamp + daw / pps;
        } else if (pps > 0) {
            // it is still active, but in foreclosure state
            // it is block.timestamp or was in the pas
            // not active and actively foreclosed (price is zero)
        }
    }

    function getEmoji(uint256 value) external pure returns (string calldata str) {
        if (value == 0) {
            str = unicode"😁";
        } else if (value == 1) {
            str = unicode"👌";
        } else if (value == 2) {
            str = unicode"😃";
        } else if (value == 3) {
            str = unicode"🙌";
        } else if (value == 3) {
            str = unicode"🙌";
        } else {
            str = unicode"👍";
        }
        return str;
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function _foreclose(address target, uint256 value) internal {
        transferFrom(ownerOf(tokenId), address(this), tokenId);
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function _collectPatronage(address target, uint256 value) internal {
        uint256 toCollect = patronageToCollect(target, value);
        uint256 _deposit = this.getDeposit(target, value);
        if (price != 0) {
            // price > 0 == active owned state

            if (toCollect >= _deposit) {
                // foreclosure happened in the past
                // up to when was it actually paid for?
                // TLC + (time_elapsed)*deposit/toCollect
                timeCollected = timeCollected + (block.timestamp - timeCollected) * _deposit / toCollect;
                toCollect = _deposit; // take what's left.
            } else {
                timeCollected = block.timestamp;
            } // normal collection

            _deposit -= toCollect;
            totalCollected[tokenId] += toCollect;

            if (_deposit == 0) _foreclose(tokenId);
        }
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function transferArtworkTo(address target, uint256 value, address currentOwner, address newOwner, uint256 price)
        internal
    {
        // note: it would also tabulate time held in stewardship by smart contract

        this.addTimeHeld(currentOwner, this.getTimeCollected(target, value) - this.getTimeAcquired(target, value));

        // Mint Playground NFT / ImpactToken.
        if (currentOwner == address(0)) {
            address token = this.getImpactToken();
            ImpactToken(token)._mint(newOwner, uint256(bytes32(abi.encodePacked(target, uint96(value)))));
        }

        // Otherwise transfer ownership.
        IERC721(target).safeTransferFrom(currentOwner, newOwner, value);

        this.setPrice(target, value, price);
        setTimeAcquired(target, value, block.timestamp);
        this.setOwner(target, value, newOwner);

        // TODO: Handle patrons (aka past owners)
    }

    receive() external payable virtual {}
}
