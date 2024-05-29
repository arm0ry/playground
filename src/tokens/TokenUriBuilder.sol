// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "src/utils/SVG.sol";
import {JSON} from "src/utils/JSON.sol";
import {ITokenCurve} from "src/interface/ITokenCurve.sol";
import {IBulletin, List, Item} from "src/interface/IBulletin.sol";
import {ITokenMinter, TokenTitle, TokenSource, TokenBuilder} from "src/interface/ITokenMinter.sol";

/// @title
/// @notice
contract TokenUriBuilder {
    /// -----------------------------------------------------------------------
    /// Builder Router
    /// -----------------------------------------------------------------------

    function build(uint256 id, TokenTitle memory title, TokenSource memory source)
        external
        view
        returns (string memory)
    {
        return (id == 1) ? listOverview(title, source) : "";
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #1: List Overview
    /// -----------------------------------------------------------------------

    function listOverview(TokenTitle memory title, TokenSource memory source) internal view returns (string memory) {
        return JSON._formattedMetadata(title.name, title.desc, generateSvg(source.bulletin, source.listId));
    }

    function generateSvg(address bulletin, uint256 listId) public view returns (string memory) {
        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                "Supporter"
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
            buildTasks(bulletin, listId),
            // buildTicker(curve, curveId),
            "</svg>"
        );
    }

    function buildTasks(address bulletin, uint256 listId) public view returns (string memory) {
        List memory list = IBulletin(bulletin).getList(listId);

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                list.title
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat("# of completions: ", SVG._uint2str(IBulletin(bulletin).runsByList(listId)))
            ),
            buildTasksCompletions(bulletin, list)
        );
    }

    function buildTasksCompletions(address bulletin, List memory list) public view returns (string memory) {
        if (list.owner != address(0)) {
            uint256 length = (list.itemIds.length > 5) ? 5 : list.itemIds.length;
            string memory text;
            Item memory item;

            for (uint256 i; i < length; ++i) {
                item = IBulletin(bulletin).getItem(list.itemIds[i]);
                text = string.concat(
                    text,
                    SVG._text(
                        string.concat(
                            SVG._prop("x", "20"),
                            SVG._prop("y", SVG._uint2str(140 + 20 * i)),
                            SVG._prop("font-size", "12"),
                            SVG._prop("fill", "#808080")
                        ),
                        string.concat(item.title, ": ", SVG._uint2str(IBulletin(bulletin).runsByItem(list.itemIds[i])))
                    )
                );
            }
            return text;
        } else {
            return SVG.NULL;
        }
    }

    // function buildTicker(address curve, uint256 curveId) public view returns (string memory) {
    //     uint256 priceToMint =
    //         (curveId == 0 || curve == address(0)) ? 0 : ITokenCurve(curve).getCurvePrice(true, curveId, 0);
    //     uint256 priceToBurn =
    //         (curveId == 0 || curve == address(0)) ? 0 : ITokenCurve(curve).getCurvePrice(false, curveId, 0);

    //     return string.concat(
    //         SVG._text(
    //             string.concat(
    //                 SVG._prop("x", "230"),
    //                 SVG._prop("y", "25"),
    //                 SVG._prop("font-size", "9"),
    //                 SVG._prop("fill", "#00040a")
    //             ),
    //             string.concat(unicode"🪙  ", convertToCurrencyForm(priceToMint), unicode" Ξ")
    //         ),
    //         SVG._text(
    //             string.concat(
    //                 SVG._prop("x", "230"),
    //                 SVG._prop("y", "40"),
    //                 SVG._prop("font-size", "9"),
    //                 SVG._prop("fill", "#00040a")
    //             ),
    //             string.concat(unicode"🔥  ", convertToCurrencyForm(priceToBurn), unicode" Ξ")
    //         )
    //     );
    // }

    // function convertToCurrencyForm(uint256 amount) internal pure returns (string memory) {
    //     string memory decimals;
    //     for (uint256 i; i < 4; ++i) {
    //         uint256 decimalPoint = 1 ether / (10 ** i);
    //         if (amount % decimalPoint > 0) {
    //             decimals = string.concat(decimals, SVG._uint2str(amount % decimalPoint / (decimalPoint / 10)));
    //         } else {
    //             decimals = string.concat(decimals, SVG._uint2str(0));
    //         }
    //     }

    //     return string.concat(SVG._uint2str(amount / 1 ether), ".", decimals);
    // }
}
