// // SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

// import {ERC721} from "solbase/tokens/ERC721/ERC721.sol";
// import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
// import {IQuests} from "./interface/IQuests.sol";
// import {IMissions, Mission} from "./interface/IMissions.sol";
// import {Base64} from "solbase/utils/Base64.sol";
// import {LibString} from "solbase/utils/LibString.sol";

// //// @title Arm0ry Travelers
// /// @notice NFTs for Arm0ry participants.
// /// credit: z0r0z.eth https://gist.github.com/z0r0z/6ca37df326302b0ec8635b8796a4fdbb
// /// credit: simondlr https://github.com/Untitled-Frontier/tlatc/blob/master/packages/hardhat/contracts/AnchorCertificates.sol

// contract Travelers is ERC721 {
//     /// -----------------------------------------------------------------------
//     /// Custom Error
//     /// -----------------------------------------------------------------------

//     error NotAuthorized();

//     /// -----------------------------------------------------------------------
//     /// Traveler Storage
//     /// -----------------------------------------------------------------------

//     address public arm0ry;

//     IQuests public quests;

//     IMissions public mission;

//     uint256 public travelerCount;

//     // 16 palettes
//     string[4][10] palette = [["#f4f9f9", "#f1d1d0", "#fbaccc", "#f875aa"], ["#fdffbc", "#ffeebb", "#ffdcb8", "#ffc1b6"]];

//     constructor(address _arm0ry) ERC721("Arm0ry Travelers", "ART") {
//         arm0ry = _arm0ry;
//     }

//     function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
//         string memory name = string(abi.encodePacked("Arm0ry Traveler #", LibString.toString(tokenId)));
//         string memory description = "Arm0ry Travelers";
//         string memory image = generateBase64Image(tokenId);

//         return string(
//             abi.encodePacked(
//                 "data:application/json;base64,",
//                 Base64.encode(
//                     bytes(
//                         abi.encodePacked(
//                             '{"name":"',
//                             name,
//                             '", "description":"',
//                             description,
//                             '", "image": "',
//                             "data:image/svg+xml;base64,",
//                             image,
//                             '"}'
//                         )
//                     )
//                 )
//             )
//         );
//     }

//     function generateBase64Image(uint256 tokenId) public view returns (string memory) {
//         return Base64.encode(bytes(generateImage(tokenId)));
//     }

//     function generateImage(uint256 tokenId) public view returns (string memory) {
//         // Retrieve seeds
//         address traveler = address(uint160(tokenId));
//         uint8 missionId = quests.questing(traveler);
//         (,,,, uint8 progress, uint8 questXp,,) = quests.getQuest(traveler, missionId);
//         (Mission memory m,) = mission.getMission(missionId);

//         // Prepare palette
//         bytes memory hash = abi.encodePacked(toBytes(traveler));
//         uint256 pIndex = toUint8(hash, 0) % 10; // 10 palettes
//         string memory paletteSection = generatePaletteSection(tokenId, pIndex);

//         return string(
//             abi.encodePacked(
//                 '<svg class="svgBody" width="300" height="300" viewBox="0 0 300 300" xmlns="http://www.w3.org/2000/svg">',
//                 paletteSection,
//                 '<text x="20" y="120" class="score" stroke="black" stroke-width="2">',
//                 LibString.toString(progress),
//                 "</text>",
//                 '<text x="112" y="120" class="tiny" stroke="grey">% Progress</text>',
//                 '<text x="180" y="120" class="score" stroke="black" stroke-width="2">',
//                 LibString.toString(questXp),
//                 "</text>",
//                 '<text x="272" y="120" class="tiny" stroke="grey">Xp</text>',
//                 '<text x="15" y="170" class="medium" stroke="grey">QUEST: </text>',
//                 '<rect x="15" y="175" width="300" height="40" style="fill:white;opacity:0.5"/>',
//                 '<text x="20" y="200" class="medium" stroke="black">',
//                 bytes(m.title).length == 0 ? " " : m.title,
//                 "</text>",
//                 unicode'  <text x="30" y="260" class="tiny" stroke="grey">Thank you for joining us at g0v 55th Hackathon! 🤙</text>',
//                 '<style>.svgBody {font-family: "Courier New" } .tiny {font-size:8px; } .small {font-size: 12px;}.medium {font-size: 18px;}.score {font-size: 50px;}</style>',
//                 "</svg>"
//             )
//         );
//     }

//     function generatePaletteSection(uint256 tokenId, uint256 pIndex) internal view returns (string memory) {
//         return string(
//             abi.encodePacked(
//                 '<rect width="300" height="300" rx="10" style="fill:',
//                 palette[pIndex][0],
//                 '" />',
//                 '<rect y="205" width="300" height="80" rx="10" style="fill:',
//                 palette[pIndex][3],
//                 '" />',
//                 '<rect y="60" width="300" height="90" style="fill:',
//                 palette[pIndex][1],
//                 '"/>',
//                 '<rect y="150" width="300" height="75" style="fill:',
//                 palette[pIndex][2],
//                 '" />',
//                 '<text x="15" y="25" class="medium">Traveler ID#</text>',
//                 '<text x="17" y="50" class="small" opacity="0.5">',
//                 substring(LibString.toString(tokenId), 0, 24),
//                 "</text>",
//                 '<g filter="url(#a)">',
//                 '<path stroke="#FFBE0B" stroke-linecap="round" stroke-width="2.1" d="M207 48.3c12.2-8.5 65-24.8 87.5-21.6" fill="none"/></g><path fill="#000" d="M220.2 38h-.8l-2.2-.4-1 4.6-2.9-.7 1.5-6.4 1.6-8.3c1.9-.4 3.9-.6 6-.8l1.9 8.5 1.5 7.4-3 .5-1.4-7.3-1.2-6.1c-.5 0-1 0-1.5.2l-1 6 3.1.1-.4 2.6h-.2Zm8-5.6v-2.2l2.6-.3.5 1.9 1.8-2.1h1.5l.6 2.9-2 .4-1.8.4-.2 8.5-2.8.2-.2-9.7Zm8.7-2.2 2.6-.3.4 1.9 2.2-2h2.4c.3 0 .6.3 1 .6.4.4.7.9.7 1.3l2.1-1.8h3l.6.3.6.6.2.5-.4 10.7-2.8.2v-9.4a4.8 4.8 0 0 0-2.2.2l-1 .3-.3 8.7-2.7.2v-9.4a5 5 0 0 0-2.3.2l-.9.3-.3 8.6-2.7.2-.2-11.9Zm28.6 3.5a19.1 19.1 0 0 1-.3 4.3 15.4 15.4 0 0 1-.8 3.6c-.1.3-.3.4-.5.5l-.8.2h-2.3c-2 0-3.2-.2-3.6-.6-.4-.5-.8-2.1-1-5a25.7 25.7 0 0 1 0-5.6l.4-.5c.1-.2.5-.4 1-.5 2.3-.5 4.8-.8 7.4-.8h.4l.3 3-.6-.1h-.5a23.9 23.9 0 0 0-5.3.5 25.1 25.1 0 0 0 .3 7h2.4c.2-1.2.4-2.8.5-4.9v-.7l3-.4Zm3.7-1.3v-2.2l2.6-.3.5 1.9 1.9-2.1h1.4l.6 2.9-1.9.4-2 .4V42l-2.9.2-.2-9.7Zm8.5-2.5 3-.6.2 10 .8.1h.9l1.5-.6V30l2.8-.3.2 13.9c0 .4-.3.8-.8 1.1l-3 2-1.8 1.2-1.6.9-1.5-2.7 6-3-.1-3.1-1.9 2h-3.1c-.3 0-.5-.1-.8-.4-.4-.3-.6-.6-.6-1l-.2-10.7Z"/>',
//                 "<defs>",
//                 '<filter id="a" width="91.743" height="26.199" x="204.898" y="24.182" color-interpolation-filters="sRGB" filterUnits="userSpaceOnUse">',
//                 '<feBlend in="SourceGraphic" in2="BackgroundImageFix" result="shape"/>',
//                 "</filter>",
//                 "</defs>"
//             )
//         );
//     }

//     function mintTravelerPass() external payable returns (uint256 tokenId) {
//         tokenId = uint256(uint160(msg.sender));

//         _mint(msg.sender, tokenId);

//         unchecked {
//             ++travelerCount;
//         }
//     }

//     /// -----------------------------------------------------------------------
//     /// Arm0ry Functions
//     /// -----------------------------------------------------------------------

//     function updateContracts(IQuests _quests, IMissions _mission) external payable {
//         if (msg.sender != arm0ry) revert NotAuthorized();
//         quests = _quests;
//         mission = _mission;
//     }

//     /// -----------------------------------------------------------------------
//     /// Internal Functions
//     /// -----------------------------------------------------------------------

//     // helper function for generation
//     // from: https://github.com/GNSPS/solidity-bytes-utils/blob/master/contracts/BytesLib.sol
//     function toUint8(bytes memory _bytes, uint256 _start) internal pure returns (uint8) {
//         require(_start + 1 >= _start, "toUint8_overflow");
//         require(_bytes.length >= _start + 1, "toUint8_outOfBounds");
//         uint8 tempUint;

//         assembly {
//             tempUint := mload(add(add(_bytes, 0x1), _start))
//         }
//         return tempUint;
//     }

//     function toBytes(address a) public pure returns (bytes memory b) {
//         assembly {
//             let m := mload(0x40)
//             a := and(a, 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF)
//             mstore(add(m, 20), xor(0x140000000000000000000000000000000000000000, a))
//             mstore(0x40, add(m, 52))
//             b := m
//         }
//     }

//     // from: https://ethereum.stackexchange.com/questions/31457/substring-in-solidity/31470
//     function substring(string memory str, uint256 startIndex, uint256 endIndex) internal pure returns (string memory) {
//         bytes memory strBytes = bytes(str);
//         bytes memory result = new bytes(endIndex - startIndex);
//         for (uint256 i = startIndex; i < endIndex; i++) {
//             result[i - startIndex] = strBytes[i];
//         }
//         return string(result);
//     }

//     function addressToHexString(address addr) internal pure returns (string memory) {
//         return LibString.toHexString(uint256(uint160(addr)), 20);
//     }
// }
