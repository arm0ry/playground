// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {Missions} from "../Missions.sol";
import {IMissions, Mission, Task, Metric} from "../interface/IMissions.sol";
import {IStorage} from "../interface/IStorage.sol";
import {Storage} from "../Storage.sol";
import {IQuest, QuestDetail} from "../interface/IQuest.sol";

import {ImpactToken} from "../tokens/ImpactToken.sol";
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
    error TransferFailed();
    error InvalidMission();
    error InvalidPrice();
    error InvalidExit();
    error InvalidRoyalties();
    error NotPatron();
    error FactoryNotSet();
    error InvalidMint();

    /// -----------------------------------------------------------------------
    /// Emoji Storage
    /// -----------------------------------------------------------------------

    bool useEmoji;

    /// -----------------------------------------------------------------------
    /// Harberger Tax Storage
    /// -----------------------------------------------------------------------

    /// -----------------------------------------------------------------------
    /// Immutable Storage
    /// -----------------------------------------------------------------------

    bytes32 immutable ROYALTIES_KEY = keccak256(abi.encodePacked("royalties.default"));
    bytes32 immutable KALIDAO_FACTORY_KEY = keccak256(abi.encodePacked("kalidao.factory"));
    bytes32 immutable IMPACT_TOKEN_KEY = keccak256(abi.encodePacked("impactToken"));

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

    modifier isFactorySet() {
        if (this.getKaliDaoFactory() == address(0)) revert FactoryNotSet();
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
    function enablePlayground(address missions, uint256 missionId, uint256 price) external payable {
        if (price == 0) revert InvalidPrice();
        this.setPrice(missions, missionId, price);
    }

    function balanceDao(address target, uint256 value, address newOwner) external payable {
        // Get address to DAO to manage revenue from Harberger Tax
        address sustainableDAO = this.getAddress(keccak256(abi.encode(target, value, ".dao")));
        // TODO: Need to define KaliDAO params
        if (sustainableDAO == address(0)) {
            // Summon DAO if not already summoned
            // TODO: Add newOwner here
            sustainableDAO = KaliDAOfactory(this.getKaliDaoFactory()).deployKaliDAO();
        }

        // Retrieve total amount collected to date.
        uint256 totalCollected = this.getTotalCollected(target, value);

        // Ensure ratio is same as that of member DAO token amount to total DAO token amount
        uint256 patronCount = this.getPatronCount(target, value);
        for (uint256 i = 0; i < patronCount;) {
            // Retrieve patron contribution.
            address patron = this.getPatron(target, value, patronId);
            uint256 contribution = this.getPatronContribution(target, value, patron);

            // Retrieve KaliDAO data.
            uint256 _contribution = KaliDAO(sustainableDAO).balanceOf(msg.sender);

            if (contribution > _contribution) {
                amount = contribution - _contribution;
                IKaliTokenManager(sustainableDAO).mintShares(creator, amount);
                IKaliTokenManager(sustainableDAO).mintShares(msg.sender, amount);
            } else if (contribution < _contribution) {
                amount = _contribution - contribution;
                IKaliTokenManager(sustainableDAO).burnShares(creator, amount);
                IKaliTokenManager(sustainableDAO).burnShares(msg.sender, amount);
            } else {
                continue;
            }

            unchecked {
                ++i;
            }
        }

        uint256 amount;
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
            if (!success) addUnclaimed(creator, payout);

            return price - payout;
        }
    }

    /// @notice Buy ERC721 NFT.
    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function buy(address token, uint256 tokenId, uint256 _newPrice, uint256 _currentPrice)
        external
        payable
        collectPatronage(token, tokenId)
        isFactorySet
    {
        uint256 price = this.getPrice(token, tokenId);
        if (price != _currentPrice || _newPrice == 0 || msg.value != _currentPrice) revert InvalidMint();

        // Add purchase price to patron contribution.
        addPatronContribution(target, value, msg.sender, price);

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

        transferArtworkTo(token, tokenId, currentOwner, msg.sender, _newPrice);

        // Balance DAO according to updated contribution.
        this.balanceDao(token, tokenId, address(0), price);
    }

    // todo: fix below
    /// @notice Buy Playground NFT.
    function buy(address missions, uint256 missionId, uint256 _newPrice, uint256 _currentPrice)
        external
        payable
        collectPatronage(missions, missionId)
        isFactorySet
    {
        // Check if Playground contracts
        address dao = IStorage(missions).getDao();
        if (dao != address(0)) revert NotAuthorized();

        Mission memory mission = IMissions(missions).getMission(missionId);

        address currentOwner = IERC721(missions).ownerOf(ImpactToken(missions).encode(missions, missionId));
        uint256 _deposit = this.getDeposit(missions, missionId);
        uint256 totalToPayBack = price + _deposit;
        if (totalToPayBack > 0) {
            // this won't execute if steward owns it. price = 0. deposit = 0.
            // pay previous owner their price + deposit back.
            // address payable payableCurrentOwner = address(uint160(currentOwner));
            (bool success,) = currentOwner.call{value: totalToPayBack}("");
            if (!success) this.addUnclaimed(currentOwner, totalToPayBack);
        }

        // new purchase
        _deposit = msg.value - price;
        this.addDeposit(missions, missionId, _deposit);

        transferArtworkTo(tokenId, currentOwner, msg.sender, _newPrice);

        this.balanceDao(missions, missionId, mission.creator, price);
    }

    /// -----------------------------------------------------------------------
    /// Patron Only Logic
    /// -----------------------------------------------------------------------

    function exit(address target, uint256 value, uint256 amount)
        public
        collectPatronage(target, value)
        onlyPatron(target, value)
    {
        uint256 _deposit = this.getDeposit(target, value);
        if (_deposit >= amount) revert InvalidExit();

        (bool success,) = msg.sender.call{value: _deposit - amount}("");
        if (!success) revert TransferFailed();

        _forecloseIfNecessary(target, value, _deposit);
    }

    /// -----------------------------------------------------------------------
    /// Helper Functions
    /// -----------------------------------------------------------------------

    function setKaliDaoFactory(address factory) external payable onlyOperator {
        this.setAddress(KALIDAO_FACTORY_KEY, factory);
    }

    function getKaliDaoFactory() external view returns (address) {
        return this.getAddress(KALIDAO_FACTORY_KEY);
    }

    function setImpactToken(address token) external payable onlyOperator {
        this.setAddress(IMPACT_TOKEN_KEY, token);
    }

    function getImpactToken() external view returns (address) {
        return this.getAddress(IMPACT_TOKEN_KEY);
    }

    function setTax(address target, uint256 value, uint256 _tax) external payable onlyPlayground(target) {
        this.setUint(keccak256(abi.encode(target, value, ".tax")), _tax);
    }

    function getTax(address target, uint256 value) external view returns (uint256 _tax) {
        _tax = this.getUint(keccak256(abi.encode(target, value, ".tax")));
        return (_tax == 0) ? _tax = 50 : _tax; // default tax rate is hardcoded at 50%
    }

    function setPrice(address target, uint256 value, uint256 price)
        external
        payable
        onlyPatron(target, value)
        collectPatronage(target, value)
    {
        if (price == 0) revert InvalidPrice();
        this.setUint(keccak256(abi.encode(target, value, ".price")), price);
    }

    function getPrice(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".price")));
    }

    function setRoyalties(address token, uint256 royalties) external payable onlyPlayground(token) {
        this.setUint(ROYALTIES_KEY, royalties);
    }

    function getRoyalties() external view returns (uint256) {
        return this.getUint(ROYALTIES_KEY);
    }

    function addDeposit(address target, uint256 value, uint256 _deposit) external payable onlyPatron(target, value) {
        this.addUint(keccak256(abi.encode(target, value, ".deposit")), _deposit);
    }

    function getDeposit(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".deposit")));
    }

    function setTimeCollected(address target, uint256 value, uint256 timestamp) internal {
        this.setUint(keccak256(abi.encode(target, value, ".timeCollected")), timestamp);
    }

    function getTimeCollected(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".timeCollected")));
    }

    function setTimeAcquired(address target, uint256 value, uint256 timestamp) internal {
        this.setUint(keccak256(abi.encode(target, value, ".timeAcquired")), timestamp);
    }

    function getTimeAcquired(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".timeAcquired")));
    }

    function addUnclaimed(address user, uint256 amount) internal {
        this.addUint(keccak256(abi.encode(user, ".unclaimed")), amount);
    }

    function deleteUnclaimed(address user) internal {
        this.deleteUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    function getUnclaimed(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    function addTimeHeld(address user, uint256 time) external {
        this.addUint(keccak256(abi.encode(user, ".timeHeld")), time);
    }

    function getTimeHeld(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".timeHeld")));
    }

    function addTotalCollected(address target, uint256 value, uint256 collected) internal {
        this.addUint(keccak256(abi.encode(target, value, ".totalCollected")), collected);
    }

    function getTotalCollected(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".totalCollected")));
    }

    function setOwner(address target, uint256 value, address owner) internal {
        this.setAddress(keccak256(abi.encode(target, value, ".owner")), owner);
    }

    function getOwner(address target, uint256 value) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(target, value, ".owner")));
    }

    function incrementPatronId(address target, uint256 value) internal {
        this.addUint(keccak256(abi.encode(target, value, ".patronCount")), 1);
    }

    function getPatronCount(address target, uint256 value) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(target, value, ".patronCount")));
    }

    function getPatronId(address target, uint256 value, address patron) external view returns (uint256) {
        uint256 count = this.getPatronCount(target, value);

        for (uint256 i = 0; i < count;) {
            if (patron == this.getPatron(i)) return i;

            unchecked {
                ++i;
            }
        }

        return 0;
    }

    function setPatron(address target, uint256 value, address patron) internal {
        incrementPatronId(target, value);
        this.setAddress(keccak256(abi.encode(target, value, this.getPatronCount())), owner);
    }

    function getPatron(address target, uint256 value, uint256 patronId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(target, value, patronId)));
    }

    function addPatronContribution(address target, uint256 value, address patron, uint256 amount) internal {
        return this.addUint(keccak256(abi.encode(target, value, patron), amount));
    }

    function getPatronContribution(address target, uint256 value, address patron) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, patron)));
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function patronageToCollect(address target, uint256 value) public view returns (uint256 amount) {
        return this.getPrice(target, value) * ((block.timestamp - this.getTimeCollected(target, value)) / 365 days)
            * (this.getTax(target, value) / 100);
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
        uint256 pps = this.getPrice(target, value) / 365 days * (this.getTax(target, value) / 100);
        (, uint256 daw) = isForeclosed(target, value);
        if (daw > 0) {
            return block.timestamp + daw / pps;
        } else if (pps > 0) {
            // it is still active, but in foreclosure state
            // it is block.timestamp or was in the pas
            // not active and actively foreclosed (price is zero)
            uint256 timeCollected = this.getTimeCollected(target, value);
            return timeCollected
                + (block.timestamp - timeCollected) * this.getDeposit(target, value) / patronageToCollect(target, value);
        } else {
            // not active and actively foreclosed (price is zero)
            return this.getTimeCollected(target, value); // it has been foreclosed or in foreclosure.
        }
    }

    /// -----------------------------------------------------------------------
    /// Internal Functions
    /// -----------------------------------------------------------------------

    function _forecloseIfNecessary(address target, uint256 value, uint256 _deposit) internal {
        if (_deposit == 0) {
            IERC721(target).safeTransferFrom(IERC721(target).ownerOf(value), address(this), value);
        }
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function _collectPatronage(address target, uint256 value) internal {
        uint256 price = this.getPrice(target, value);
        uint256 toCollect = patronageToCollect(target, value);
        uint256 deposit = this.getDeposit(target, value);

        uint256 timeCollected = this.getTimeCollected(target, value);

        if (price != 0) {
            // price > 0 == active owned state
            if (toCollect >= deposit) {
                // foreclosure happened in the past
                // up to when was it actually paid for?
                // TLC + (time_elapsed)*deposit/toCollect
                setTimeCollected(target, value, (block.timestamp - timeCollected) * deposit / toCollect);
                toCollect = deposit; // take what's left.
            } else {
                setTimeCollected(target, value, block.timestamp);
            } // normal collection

            deposit -= toCollect;

            // Add to total amount collected.
            addTotalCollected(target, value, toCollect);

            // Add to amount collected by patron.
            addPatronContribution(target, value, msg.sender, toCollect);

            _forecloseIfNecessary(target, value, deposit);
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
            ImpactToken(token).mint(newOwner, uint256(bytes32(abi.encodePacked(target, uint96(value)))));
        }

        // Otherwise transfer ownership.
        IERC721(target).safeTransferFrom(currentOwner, newOwner, value);

        this.setPrice(target, value, price);
        setTimeAcquired(target, value, block.timestamp);
        setOwner(target, value, newOwner);
        setPatron(target, value, newOwner);
    }

    receive() external payable virtual {}
}
