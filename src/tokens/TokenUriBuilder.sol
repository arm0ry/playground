// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "src/utils/SVG.sol";
import {JSON} from "src/utils/JSON.sol";
import {ITokenCurve} from "src/interface/ITokenCurve.sol";
import {IBulletin, List, Item} from "src/interface/IBulletin.sol";
import {ILog, Activity, Touchpoint} from "src/interface/ILog.sol";
import {ITokenMinter, TokenTitle, TokenSource, TokenBuilder} from "src/interface/ITokenMinter.sol";
import {LibMap} from "lib/solady/src/utils/LibMap.sol";
import {LibBitmap} from "lib/solady/src/utils/LibBitmap.sol";
import {LibBytemap} from "lib/solbase/src/utils/LibBytemap.sol";

/// @title
/// @notice
contract TokenUriBuilder {
    /// -----------------------------------------------------------------------
    /// Builder Storage
    /// -----------------------------------------------------------------------

    // using LibBitmap for LibBitmap.Bitmap;
    // using LibMap for LibMap.Uint8Map;
    // using LibBytemap for LibBytemap.Bytemap;

    // LibBitmap.Bitmap bitmap;
    // LibMap.Uint8Map uint8Map;
    // LibBytemap.Bytemap bytemap;

    // mapping(bytes32 => uint256) public counter;
    // uint8[7] public counters;

    /// -----------------------------------------------------------------------
    /// Builder Router
    /// -----------------------------------------------------------------------

    function build(uint256 id, TokenTitle memory title, TokenSource memory source)
        external
        view
        returns (string memory)
    {
        if (id == 1) {
            return listOverview(title, source);
        } else if (id == 2) {
            return feedbackForColdBrew(title, source);
        } else if (id == 3) {
            // return feedbackForEspresso(title, source);
            return "";
        }
    }

    /// -----------------------------------------------------------------------
    ///  Getter
    /// -----------------------------------------------------------------------

    function generateSvg(uint256 id, address bulletin, uint256 listId, address logger)
        public
        view
        returns (string memory)
    {
        if (id == 1) {
            return generateSvgForListOverview(bulletin, listId);
        } else if (id == 2) {
            return generateSvgForColdBrewFeedback(bulletin, listId, logger);
        } else if (id == 3) {
            // return generateSvgForEspressoFeedback(bulletin, listId, logger);
            return "";
        }
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #1: List Overview
    /// -----------------------------------------------------------------------

    function listOverview(TokenTitle memory title, TokenSource memory source) public view returns (string memory) {
        return
            JSON._formattedMetadata(title.name, title.desc, generateSvgForListOverview(source.bulletin, source.listId));
    }

    function generateSvgForListOverview(address bulletin, uint256 listId) public view returns (string memory) {
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

    /// -----------------------------------------------------------------------
    /// SVG Template #2: Feedback for Cold Brew
    /// -----------------------------------------------------------------------

    function feedbackForColdBrew(TokenTitle memory title, TokenSource memory source)
        public
        view
        returns (string memory)
    {
        return JSON._formattedMetadata(
            title.name, title.desc, generateSvgForColdBrewFeedback(source.bulletin, source.listId, source.logger)
        );
    }

    function generateSvgForColdBrewFeedback(address bulletin, uint256 listId, address logger)
        public
        view
        returns (string memory)
    {
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
            buildColdBrew(bulletin, listId, logger),
            // buildTicker(curve, curveId),
            "</svg>"
        );
    }

    function buildColdBrew(address bulletin, uint256 listId, address logger) internal view returns (string memory) {
        uint8[7] memory counters;

        uint256 data;
        uint256 nonce = ILog(logger).nonceByItemId(keccak256(abi.encodePacked(bulletin, listId, uint256(0))));

        for (uint256 i; i < nonce; ++i) {
            data = uint256(
                bytes32(
                    ILog(logger).touchpointDataByEncodedItemId(
                        keccak256(abi.encodePacked(bulletin, listId, uint256(0))), i
                    )
                )
            );

            // Decode data and count user response.
            for (uint256 j; j < 7; ++j) {
                if ((data / (10 ** j)) % 10 == 1) {
                    unchecked {
                        ++counters[j];
                    }
                }
            }
        }

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                "Cold Brew"
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "160"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"👍 幫 g0v 粉專按讚： ", SVG._uint2str(counters[0]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "180"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🔔 打開任一專案頻道通知： ", SVG._uint2str(counters[1]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "200"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"📝 截圖任一提案的專案共筆： ", SVG._uint2str(counters[2]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "220"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🏷️ 貼上三張符合你的技能貼紙：", SVG._uint2str(counters[3]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "240"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🧐 加入三個有趣的 Slack 頻道： ", SVG._uint2str(counters[4]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"👀 瀏覽並截圖最新『社群九分鐘』： ", SVG._uint2str(counters[5]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "280"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🎙️ 在有興趣的專案共筆上自我介紹： ", SVG._uint2str(counters[6]))
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #3: Feedback for Espresso
    /// -----------------------------------------------------------------------

    function feedbackForEspresso(TokenTitle memory title, TokenSource memory source)
        public
        view
        returns (string memory)
    {
        return JSON._formattedMetadata(
            title.name, title.desc, generateSvgForColdBrewFeedback(source.bulletin, source.listId, source.logger)
        );
    }

    function generateSvgForEspressoFeedback(address bulletin, uint256 listId, address logger)
        public
        view
        returns (string memory)
    {
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
            buildColdBrew(bulletin, listId, logger),
            // buildTicker(curve, curveId),
            "</svg>"
        );
    }

    function buildColdBrew(address bulletin, uint256 listId, address logger) internal view returns (string memory) {
        uint8[7] memory counters;

        uint256 data;
        uint256 nonce = ILog(logger).nonceByItemId(keccak256(abi.encodePacked(bulletin, listId, uint256(0))));

        for (uint256 i; i < nonce; ++i) {
            data = uint256(
                bytes32(
                    ILog(logger).touchpointDataByEncodedItemId(
                        keccak256(abi.encodePacked(bulletin, listId, uint256(0))), i
                    )
                )
            );

            // Decode data and count user response.
            for (uint256 j; j < 7; ++j) {
                if ((data / (10 ** j)) % 10 == 1) {
                    unchecked {
                        ++counters[j];
                    }
                }
            }
        }

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"黑客松新參者小紙條")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "160"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"👍 幫 g0v 粉專按讚： ", SVG._uint2str(counters[0]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "180"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🔔 打開任一專案頻道通知： ", SVG._uint2str(counters[1]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "200"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"📝 截圖任一提案的專案共筆： ", SVG._uint2str(counters[2]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "220"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🏷️ 貼上三張符合你的技能貼紙：", SVG._uint2str(counters[3]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "240"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🧐 加入三個有趣的 Slack 頻道： ", SVG._uint2str(counters[4]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"👀 瀏覽並截圖最新『社群九分鐘』： ", SVG._uint2str(counters[5]))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "280"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#00040a")
                ),
                string.concat(unicode"🎙️ 在有興趣的專案共筆上自我介紹： ", SVG._uint2str(counters[6]))
            )
        );
    }
}
