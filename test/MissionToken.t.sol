// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "forge-std/console2.sol";

import {KaliDAOfactory, KaliDAO} from "kali-markets/kalidao/KaliDAOfactory.sol";
import {KaliCurve} from "kali-markets/KaliCurve.sol";
import {IKaliCurve, CurveType} from "kali-markets/interface/IKaliCurve.sol";

import {Mission} from "src/Mission.sol";
import {IMission} from "src/interface/IMission.sol";
import {Quest} from "src/Quest.sol";
import {IQuest} from "src/interface/IQuest.sol";
import {Storage} from "kali-markets/Storage.sol";
import {IStorage} from "kali-markets/interface/IStorage.sol";
import {MissionToken} from "src/tokens/MissionToken.sol";

contract MissionTokenTest is Test {
    Quest quest;
    Mission mission;
    Storage stor;
    MissionToken missionToken;

    IQuest iQuest;
    IStorage iStorage;

    /// @dev Users.
    address public immutable alice = makeAddr("alice");
    address public immutable bob = makeAddr("bob");
    address public immutable charlie = makeAddr("charlie");
    address public immutable dummy = makeAddr("dummy");
    address payable public immutable user = payable(makeAddr("user"));

    /// @dev Helpers.
    string internal constant testString = "TEST";

    /// -----------------------------------------------------------------------
    /// Kali Setup Tests
    /// -----------------------------------------------------------------------

    /// @notice Set up the testing suite.

    function setUp() public payable {
        missionToken = new MissionToken(testString, testString, user, user, user);
    }

    function testMint() public payable {
        // uint256 amount = 2;
        // uint256 price = IKaliCurve(address(kaliCurve)).getMintBurnDifference(1) * amount;

        // vm.deal(bob, 10 ether);
        // vm.prank(bob);
        // missionToken.support{value: price}(alice, 1, 1, amount);

        // emit log_uint(missionToken.balanceOf(bob, 1));
    }

    function testReceiveETH() public payable {
        (bool sent,) = address(missionToken).call{value: 5 ether}("");
        assert(!sent);
    }
}
