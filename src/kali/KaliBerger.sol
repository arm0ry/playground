// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {LibString} from "../../lib/solbase/src/utils/LibString.sol";

import {Missions} from "../Missions.sol";
import {IMissions, Mission, Task, Metric} from "../interface/IMissions.sol";
import {IStorage} from "../interface/IStorage.sol";
import {Storage} from "../Storage.sol";
import {IQuest, QuestDetail} from "../interface/IQuest.sol";

import {IImpactToken} from "../interface/IImpactToken.sol";
import {KaliDAOfactory, KaliDAO} from "../kali/KaliDAOfactory.sol";
import {IKaliTokenManager} from "../interface/IKaliTokenManager.sol";

import {IERC721} from "../../lib/forge-std/src/interfaces/IERC721.sol";
import {IERC20} from "../../lib/forge-std/src/interfaces/IERC20.sol";

/// @notice When DAOs use Harberger Tax to form treasury subDAOs, good things happen!
contract KaliBerger is Storage {
    /// -----------------------------------------------------------------------
    /// Custom Error
    /// -----------------------------------------------------------------------

    error NotAuthorized();
    error TransferFailed();
    error InvalidPrice();
    error InvalidExit();
    error NotPatron();
    error FactoryNotSet();
    error InvalidMint();

    /// -----------------------------------------------------------------------
    /// Constructor
    /// -----------------------------------------------------------------------

    function init(address dao, address factory, address impactToken) external payable {
        if (factory != address(0) && impactToken != address(0)) {
            init(dao, address(0));
            setKaliDaoFactory(factory);
            setImpactToken(impactToken);
        }
    }

    /// -----------------------------------------------------------------------
    /// Modifiers
    /// -----------------------------------------------------------------------

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
    /// KaliBerger Functions - Confirm Use of Harberger Tax
    /// -----------------------------------------------------------------------

    /// @notice Escrow ERC721 NFT before making available for purchase.
    function escrow(address token, uint256 tokenId, uint256 price) external payable onlyOperator {
        if (price == 0) revert InvalidPrice();
        if (IERC721(token).ownerOf(tokenId) != msg.sender) revert NotAuthorized();
        IERC721(token).safeTransferFrom(msg.sender, address(this), tokenId);
        this.setPrice(token, tokenId, price);
    }

    /// @notice Enable Playground NFT for sale.
    function enable(address missions, uint256 missionId, uint256 price) external payable playground(missions) {
        address creator = IMissions(missions).getMissionCreator(missionId);
        address dao = IStorage(missions).getDao();
        if (msg.sender != creator && msg.sender != dao) revert NotAuthorized();

        if (price == 0) revert InvalidPrice();
        this.setPrice(missions, missionId, price);
    }

    /// -----------------------------------------------------------------------
    /// KaliBerger Functions - DAO memberships
    /// -----------------------------------------------------------------------

    /// @notice Public function to rebalance an Impact DAO.
    function balanceDao(address target, uint256 value) external payable {
        // Get address to DAO to manage revenue from Harberger Tax
        address payable dao = payable(this.getImpactDao(target, value));
        if (dao == address(0)) revert NotAuthorized();

        _balance(target, value, dao, address(0));
    }

    /// @notice Summon an Impact DAO
    function summonDao(address target, uint256 value, address creator, address patron) private returns (address) {
        address[] memory extensions;
        bytes[] memory extensionsData;

        address[] memory voters;
        voters[0] = creator;
        voters[1] = patron;

        uint256[] memory tokens;
        tokens[1] = this.getPatronContribution(target, value, patron);
        tokens[0] = tokens[1];

        uint32[16] memory govSettings;
        govSettings = [uint32(300), 0, 60, 20, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];

        uint256 count = this.getBergerCount();
        address payable dao = payable(
            KaliDAOfactory(this.getKaliDaoFactory()).deployKaliDAO(
                string.concat("BergerTime #", LibString.toString(count)),
                string.concat("BT #", LibString.toString(count)),
                " ",
                true,
                extensions,
                extensionsData,
                voters,
                tokens,
                govSettings
            )
        );

        setImpactDao(target, value, dao);
        return dao;
    }

    /// @notice Update DAO balance when ImpactToken is purchased.
    function updateBalances(address target, uint256 value, address patron) internal {
        // Get DAO address to manage revenue from Harberger Tax
        address dao = this.getImpactDao(target, value);

        // Retrieve creator.
        address creator = this.getCreator(target, value);
        if (creator == address(0)) creator = IMissions(target).getMissionCreator(value);

        if (dao == address(0)) {
            // Summon DAO with 50/50 ownership between creator and patron(s).
            summonDao(target, value, creator, patron);
        } else {
            // Update DAO balance.
            _balance(target, value, dao, creator);
        }
    }

    /// @notice Rebalance Impact DAO.
    function _balance(address target, uint256 value, address dao, address creator) private {
        for (uint256 i = 0; i < this.getPatronCount(target, value);) {
            // Retrieve patron and patron contribution.
            address _patron = this.getPatron(target, value, i);
            uint256 contribution = this.getPatronContribution(target, value, _patron);

            // Retrieve KaliDAO balance data.
            uint256 _contribution = IERC20(dao).balanceOf(msg.sender);

            // Retrieve creator.
            if (creator == address(0)) {
                if (this.getCreator(target, value) == address(0)) {
                    creator = IMissions(target).getMissionCreator(value);
                }
            }

            if (contribution != _contribution) {
                // Determine to mint or burn.
                if (contribution > _contribution) {
                    IKaliTokenManager(dao).mintTokens(creator, contribution - _contribution);
                    IKaliTokenManager(dao).mintTokens(_patron, contribution - _contribution);
                } else if (contribution < _contribution) {
                    IKaliTokenManager(dao).burnTokens(creator, _contribution - contribution);
                    IKaliTokenManager(dao).burnTokens(_patron, _contribution - contribution);
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /// -----------------------------------------------------------------------
    /// Patron Logic
    /// -----------------------------------------------------------------------

    /// @notice Buy ERC721 NFT.
    function buyErc(address token, uint256 tokenId, uint256 newPrice, uint256 currentPrice)
        external
        payable
        collectPatronage(token, tokenId)
        isFactorySet
    {
        // Pay currentPrice + deposit to current owner.
        address owner = IERC721(token).ownerOf(tokenId);
        if (owner != address(0)) processPayment(token, tokenId, owner, newPrice, currentPrice);

        // Transfer NFT and update price and other data.
        transferImpactToken(token, tokenId, owner, msg.sender, newPrice);

        // Balance DAO according to updated contribution.
        updateBalances(token, tokenId, msg.sender);
    }

    /// @notice Buy Playground NFT.
    function buyPlayground(address missions, uint256 missionId, uint256 newPrice, uint256 currentPrice)
        external
        payable
        collectPatronage(missions, missionId)
        isFactorySet
        playground(missions)
    {
        // Pay currentPrice + deposit to current owner.
        address owner = IERC721(missions).ownerOf(IImpactToken(missions).getTokenId(missions, missionId));
        if (owner != address(0)) processPayment(missions, missionId, owner, newPrice, currentPrice);

        // Transfer NFT and update price and other data.
        transferImpactToken(missions, missionId, owner, msg.sender, newPrice);

        // Balance DAO according to updated contribution.
        updateBalances(missions, missionId, msg.sender);
    }

    /// @notice Set new price for purchase.
    function setPrice(address target, uint256 value, uint256 price)
        external
        payable
        onlyPatron(target, value)
        collectPatronage(target, value)
    {
        if (price == 0) revert InvalidPrice();
        this.setUint(keccak256(abi.encode(target, value, ".price")), price);
    }

    /// @notice To make deposit.
    function addDeposit(address target, uint256 value, uint256 _deposit) external payable onlyPatron(target, value) {
        this.addUint(keccak256(abi.encode(target, value, ".deposit")), _deposit);
    }

    /// @notice Withdraw from deposit.
    function exit(address target, uint256 value, uint256 amount)
        public
        collectPatronage(target, value)
        onlyPatron(target, value)
    {
        uint256 deposit = this.getDeposit(target, value);
        if (deposit >= amount) revert InvalidExit();

        (bool success,) = msg.sender.call{value: deposit - amount}("");
        if (!success) revert TransferFailed();

        _forecloseIfNecessary(target, value, deposit);
    }

    /// -----------------------------------------------------------------------
    /// KaliBerger Functions - Setter Logic
    /// -----------------------------------------------------------------------

    /// @param factory The address of dao factory.
    function setKaliDaoFactory(address factory) public onlyOperator {
        this.setAddress(keccak256(abi.encodePacked("dao.factory")), factory);
    }

    function setImpactDao(address target, uint256 value, address dao) public onlyOperator {
        this.setAddress(keccak256(abi.encode(target, value, ".dao")), dao);
    }

    function setImpactToken(address token) public onlyOperator {
        this.setAddress(keccak256(abi.encodePacked("impactToken")), token);
    }

    function setTax(address target, uint256 value, uint256 _tax) external payable onlyOperator {
        this.setUint(keccak256(abi.encode(target, value, ".tax")), _tax);
    }

    function setCreator(address target, uint256 value, address creator) external payable onlyOperator {
        this.setAddress(keccak256(abi.encode(target, value, ".creator")), creator);
    }

    function setTimeCollected(address target, uint256 value, uint256 timestamp) internal {
        this.setUint(keccak256(abi.encode(target, value, ".timeCollected")), timestamp);
    }

    function setTimeAcquired(address target, uint256 value, uint256 timestamp) internal {
        this.setUint(keccak256(abi.encode(target, value, ".timeAcquired")), timestamp);
    }

    function setOwner(address target, uint256 value, address owner) internal {
        this.setAddress(keccak256(abi.encode(target, value, ".owner")), owner);
    }

    function setPatron(address target, uint256 value, address patron) internal {
        incrementPatronId(target, value);
        this.setAddress(keccak256(abi.encode(target, value, this.getPatronCount(target, value))), patron);
    }

    /// -----------------------------------------------------------------------
    /// KaliBerger Functions - Getter Logic
    /// -----------------------------------------------------------------------

    function getKaliDaoFactory() external view returns (address) {
        return this.getAddress(keccak256(abi.encodePacked("dao.factory")));
    }

    function getBergerCount() external view returns (uint256) {
        return this.getUint(keccak256(abi.encodePacked("bergerTimes.count")));
    }

    function getImpactDao(address target, uint256 value) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(target, value, ".dao")));
    }

    function getImpactToken() external view returns (address) {
        return this.getAddress(keccak256(abi.encodePacked("impactToken")));
    }

    function getTax(address target, uint256 value) external view returns (uint256 _tax) {
        _tax = this.getUint(keccak256(abi.encode(target, value, ".tax")));
        return (_tax == 0) ? _tax = 50 : _tax; // default tax rate is hardcoded at 50%
    }

    function getPrice(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".price")));
    }

    function getCreator(address target, uint256 value) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(target, value, ".creator")));
    }

    function getDeposit(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".deposit")));
    }

    function getTimeCollected(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".timeCollected")));
    }

    function getTimeAcquired(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".timeAcquired")));
    }

    function getUnclaimed(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    function getTimeHeld(address user) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(user, ".timeHeld")));
    }

    function getTotalCollected(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".totalCollected")));
    }

    function getOwner(address target, uint256 value) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(target, value, ".owner")));
    }

    function getPatronCount(address target, uint256 value) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, ".patronCount")));
    }

    function getPatronId(address target, uint256 value, address patron) external view returns (uint256) {
        uint256 count = this.getPatronCount(target, value);

        for (uint256 i = 0; i < count;) {
            if (patron == this.getPatron(target, value, i)) return i;
            unchecked {
                ++i;
            }
        }

        return 0;
    }

    function getPatron(address target, uint256 value, uint256 patronId) external view returns (address) {
        return this.getAddress(keccak256(abi.encode(target, value, patronId)));
    }

    function getPatronContribution(address target, uint256 value, address patron) external view returns (uint256) {
        return this.getUint(keccak256(abi.encode(target, value, patron)));
    }

    /// -----------------------------------------------------------------------
    /// KaliBerger Functions - Add Logic
    /// -----------------------------------------------------------------------

    function addBergerCount() external payable onlyOperator {
        this.addUint(keccak256(abi.encodePacked("bergerTimes.count")), 1);
    }

    function addUnclaimed(address user, uint256 amount) internal {
        this.addUint(keccak256(abi.encode(user, ".unclaimed")), amount);
    }

    function addTimeHeld(address user, uint256 time) external {
        this.addUint(keccak256(abi.encode(user, ".timeHeld")), time);
    }

    function addTotalCollected(address target, uint256 value, uint256 collected) internal {
        this.addUint(keccak256(abi.encode(target, value, ".totalCollected")), collected);
    }

    function incrementPatronId(address target, uint256 value) internal {
        this.addUint(keccak256(abi.encode(target, value, ".patronCount")), 1);
    }

    function addPatronContribution(address target, uint256 value, address patron, uint256 amount) internal {
        this.addUint(keccak256(abi.encode(target, value, patron)), amount);
    }

    /// -----------------------------------------------------------------------
    /// KaliBerger Storage - Delete Logic
    /// -----------------------------------------------------------------------

    function deleteDeposit(address target, uint256 value) internal {
        return this.deleteUint(keccak256(abi.encode(target, value, ".deposit")));
    }

    function deleteUnclaimed(address user) internal {
        this.deleteUint(keccak256(abi.encode(user, ".unclaimed")));
    }

    /// -----------------------------------------------------------------------
    /// KaliBerger Functions - Collection Logic
    /// -----------------------------------------------------------------------

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function patronageToCollect(address target, uint256 value) external view returns (uint256 amount) {
        return this.getPrice(target, value) * ((block.timestamp - this.getTimeCollected(target, value)) / 365 days)
            * (this.getTax(target, value) / 100);
    }

    /// -----------------------------------------------------------------------
    /// KaliBerger Functions - Foreclosure Logic
    /// -----------------------------------------------------------------------

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function isForeclosed(address target, uint256 value) external view returns (bool, uint256) {
        // returns whether it is in foreclosed state or not
        // depending on whether deposit covers patronage due
        // useful helper function when price should be zero, but contract doesn't reflect it yet.
        uint256 toCollect = this.patronageToCollect(target, value);
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
        (, uint256 daw) = this.isForeclosed(target, value);
        if (daw > 0) {
            return block.timestamp + daw / pps;
        } else if (pps > 0) {
            // it is still active, but in foreclosure state
            // it is block.timestamp or was in the pas
            // not active and actively foreclosed (price is zero)
            uint256 timeCollected = this.getTimeCollected(target, value);
            return timeCollected
                + (block.timestamp - timeCollected) * this.getDeposit(target, value)
                    / this.patronageToCollect(target, value);
        } else {
            // not active and actively foreclosed (price is zero)
            return this.getTimeCollected(target, value); // it has been foreclosed or in foreclosure.
        }
    }

    function _forecloseIfNecessary(address target, uint256 value, uint256 _deposit) internal {
        if (_deposit == 0) {
            IERC721(target).safeTransferFrom(IERC721(target).ownerOf(value), address(this), value);
        }
    }

    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function _collectPatronage(address target, uint256 value) internal {
        uint256 price = this.getPrice(target, value);
        uint256 toCollect = this.patronageToCollect(target, value);
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

    /// -----------------------------------------------------------------------
    /// KaliBerger Functions - NFT Transfer & Payments Logic
    /// -----------------------------------------------------------------------

    /// @notice Internal function to transfer ImpactToken.
    // credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function transferImpactToken(address target, uint256 value, address currentOwner, address newOwner, uint256 price)
        internal
    {
        // note: it would also tabulate time held in stewardship by smart contract
        this.addTimeHeld(currentOwner, this.getTimeCollected(target, value) - this.getTimeAcquired(target, value));

        // Mint Playground NFT / ImpactToken.
        if (currentOwner == address(0)) {
            address token = this.getImpactToken();
            IImpactToken(token).mint(newOwner, uint256(bytes32(abi.encodePacked(target, uint96(value)))));
        }

        // Otherwise transfer ownership.
        IERC721(target).safeTransferFrom(currentOwner, newOwner, value);

        this.setPrice(target, value, price);
        setTimeAcquired(target, value, block.timestamp);
        setOwner(target, value, newOwner);
        setPatron(target, value, newOwner);
    }

    /// @notice Internal function to process purchase payment.
    /// credit: simondlr  https://github.com/simondlr/thisartworkisalwaysonsale/blob/master/packages/hardhat/contracts/v1/ArtStewardV2.sol
    function processPayment(address target, uint256 value, address currentOwner, uint256 newPrice, uint256 currentPrice)
        internal
    {
        // Confirm price.
        uint256 price = this.getPrice(target, value);
        if (price != currentPrice || newPrice == 0 || msg.value != currentPrice) revert InvalidMint();

        // Add purchase price to patron contribution.
        addPatronContribution(target, value, msg.sender, price);

        // Retrieve deposit, if any.
        uint256 deposit = this.getDeposit(target, value);

        if (price + deposit > 0) {
            // this won't execute if KaliBerger owns it. price = 0. deposit = 0.
            // pay previous owner their price + deposit back.
            (bool success,) = currentOwner.call{value: price + deposit}("");
            if (!success) addUnclaimed(currentOwner, price + deposit);
            deleteDeposit(target, value);
        }

        // Make deposit, if any.
        this.addDeposit(target, value, msg.value - price);
    }

    receive() external payable virtual {}
}
