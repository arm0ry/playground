// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.4;

import {SVG} from "src/utils/SVG.sol";
import {JSON} from "src/utils/JSON.sol";
import {ITokenCurve} from "src/interface/ITokenCurve.sol";
import {IBulletin, List, Item} from "src/interface/IBulletin.sol";
import {ILog, LogType, Activity, Touchpoint} from "src/interface/ILog.sol";
import {ITokenMinter, TokenTitle, TokenSource, TokenBuilder} from "src/interface/ITokenMinter.sol";

/// @title
/// @notice
contract TokenUriBuilder {
    /// -----------------------------------------------------------------------
    /// Builder Router
    /// -----------------------------------------------------------------------

    function build(uint256 builderId, TokenTitle memory title, TokenSource memory source)
        external
        view
        returns (string memory)
    {
        if (builderId == 1) {
            // List owner token.
            return feedbackForBeverages(title, source);
        } else if (builderId == 2) {
            // List owner token.
            return recordCoffeeConsumption(title, source);
        } else if (builderId == 3) {
            // List owner token.
            return feedbackForDelivery(title, source);
        } else if (builderId == 4) {
            // List user token.
            return deliveryRecord(title, source);
        } else {
            return "";
        }
    }

    /// -----------------------------------------------------------------------
    ///  Getter
    /// -----------------------------------------------------------------------

    function generateSvg(uint256 builderId, address user, address bulletin, uint256 listId, address logger)
        public
        view
        returns (string memory)
    {
        if (builderId == 1) {
            // List owner token.
            return generateSvgForBeverages(bulletin, listId, logger);
        } else if (builderId == 2) {
            // List owner token.
            return generateSvgForCoffeeConsumption(bulletin, listId, logger);
        } else if (builderId == 3) {
            // List owner token.
            return generateSvgForDeliveryService(bulletin, listId, logger);
        } else if (builderId == 4) {
            // List user token.
            return generateSvgForDeliveryRecord(user, bulletin, listId, logger);
        } else {
            return "";
        }
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #1: Population
    /// -----------------------------------------------------------------------

    function feedbackForBeverages(TokenTitle memory title, TokenSource memory source)
        public
        view
        returns (string memory)
    {
        return JSON._formattedMetadata(
            title.name, title.desc, generateSvgForBeverages(source.bulletin, source.listId, source.logger)
        );
    }

    function generateSvgForBeverages(address bulletin, uint256 listId, address logger)
        public
        view
        returns (string memory)
    {
        List memory list;
        (bulletin != address(0)) ? list = IBulletin(bulletin).getList(listId) : list;

        (uint256 flavor, uint256 body, uint256 aroma) = getPerformanceData(bulletin, listId, logger);

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                list.title
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#FFBE0B"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "50"),
                    SVG._prop("width", "160"),
                    SVG._prop("height", "5")
                ),
                SVG.NULL
            ),
            loadCoffeeConsumption(bulletin, listId),
            buildPerformanceBars(flavor, body, aroma),
            SVG._text(
                string.concat(
                    SVG._prop("x", "200"),
                    SVG._prop("y", "285"),
                    SVG._prop("font-size", "9"),
                    SVG._prop("fill", "#c4c7c4")
                ),
                string.concat("by ", shorten(list.owner))
            ),
            "</svg>"
        );
    }

    // TODO: Change to something that a coffe shop might want to know about its customers
    // TODO: 2 groups: coffee vs pitcher customers
    function getPerformanceData(address bulletin, uint256 listId, address logger)
        public
        view
        returns (uint256 flavor, uint256 body, uint256 aroma)
    {
        Touchpoint memory tp;
        uint256 _flavor;
        uint256 _body;
        uint256 _aroma;

        if (logger != address(0)) {
            uint256 nonce = ILog(logger).getNonceByItemId(bulletin, listId, uint256(0));

            if (nonce > 0) {
                for (uint256 i = 1; i <= nonce; ++i) {
                    tp = ILog(logger).getTouchpointByItemIdByNonce(bulletin, listId, uint256(0), i);

                    // Decode data and count user response.
                    if (tp.logType == LogType.TOKEN) {
                        (_flavor, _body, _aroma) = abi.decode(tp.data, (uint256, uint256, uint256));

                        flavor += _flavor;
                        body += _body;
                        aroma += _aroma;
                    }
                }

                flavor = flavor / nonce * 15;
                body = body / nonce * 15;
                aroma = aroma / nonce * 15;
            }
        }
    }

    function loadCoffeeConsumption(address bulletin, uint256 listId) public view returns (string memory) {
        uint256 runs;
        (bulletin != address(0)) ? runs = IBulletin(bulletin).runsByList(listId) : runs;

        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "70"),
                    SVG._prop("y", "115"),
                    SVG._prop("font-size", "40"),
                    SVG._prop("fill", "#00040a")
                ),
                SVG._uint2str(runs)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "155"),
                    SVG._prop("y", "115"),
                    SVG._prop("font-size", "15"),
                    SVG._prop("fill", "#899499")
                ),
                "# of cups"
            )
        );
    }

    function buildPerformanceBars(uint256 flavor, uint256 body, uint256 aroma) public pure returns (string memory) {
        return string.concat(buildFlavorBars(flavor), buildBodyBars(body), buildAromaBars(aroma));
    }

    function buildFlavorBars(uint256 flavor) public pure returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "30"),
                    SVG._prop("y", "160"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#7f7053")
                ),
                "Flavor"
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#ffecb6"),
                    SVG._prop("x", "80"),
                    SVG._prop("y", "145"),
                    SVG._prop("width", "150"),
                    SVG._prop("height", "20"),
                    SVG._prop("rx", "2")
                ),
                SVG.NULL
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#da2121"),
                    SVG._prop("x", "80"),
                    SVG._prop("y", "145"),
                    SVG._prop("width", SVG._uint2str(flavor)),
                    SVG._prop("height", "20"),
                    SVG._prop("rx", "2")
                ),
                SVG.NULL
            )
        );
    }

    function buildBodyBars(uint256 body) internal pure returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "30"),
                    SVG._prop("y", "200"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#7f7053")
                ),
                "Body"
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#ffecb6"),
                    SVG._prop("x", "80"),
                    SVG._prop("y", "185"),
                    SVG._prop("width", "150"),
                    SVG._prop("height", "20"),
                    SVG._prop("rx", "2")
                ),
                SVG.NULL
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#da2121"),
                    SVG._prop("x", "80"),
                    SVG._prop("y", "185"),
                    SVG._prop("width", SVG._uint2str(body)),
                    SVG._prop("height", "20"),
                    SVG._prop("rx", "2")
                ),
                SVG.NULL
            )
        );
    }

    function buildAromaBars(uint256 aroma) internal pure returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "30"),
                    SVG._prop("y", "240"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#7f7053")
                ),
                "Aroma"
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#ffecb6"),
                    SVG._prop("x", "80"),
                    SVG._prop("y", "225"),
                    SVG._prop("width", "150"),
                    SVG._prop("height", "20"),
                    SVG._prop("rx", "2")
                ),
                SVG.NULL
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#da2121"),
                    SVG._prop("x", "80"),
                    SVG._prop("y", "225"),
                    SVG._prop("width", SVG._uint2str(aroma)),
                    SVG._prop("height", "20"),
                    SVG._prop("rx", "2")
                ),
                SVG.NULL
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #2: Record Coffee Consumption
    /// -----------------------------------------------------------------------

    function recordCoffeeConsumption(TokenTitle memory title, TokenSource memory source)
        public
        view
        returns (string memory)
    {
        return JSON._formattedMetadata(
            title.name, title.desc, generateSvgForCoffeeConsumption(source.bulletin, source.listId, source.logger)
        );
    }

    function generateSvgForCoffeeConsumption(address bulletin, uint256 listId, address logger)
        public
        view
        returns (string memory)
    {
        List memory list;
        (bulletin != address(0)) ? list = IBulletin(bulletin).getList(listId) : list;

        (uint256 coffee_gram, uint256 water_liter, uint256 compost_gram) = getCoffeeUsageData(bulletin, listId, logger);

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                list.title
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#FFBE0B"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "50"),
                    SVG._prop("width", "160"),
                    SVG._prop("height", "5")
                ),
                SVG.NULL
            ),
            loadCoffeeConsumption(bulletin, listId), // TODO: Need to update consumption calculation
            buildCoffeeUsageSvg(coffee_gram, water_liter, compost_gram),
            SVG._text(
                string.concat(
                    SVG._prop("x", "200"),
                    SVG._prop("y", "285"),
                    SVG._prop("font-size", "9"),
                    SVG._prop("fill", "#c4c7c4")
                ),
                string.concat("by ", shorten(list.owner))
            ),
            "</svg>"
        );
    }

    function getCoffeeUsageData(address bulletin, uint256 listId, address logger)
        public
        view
        returns (uint256 coffee_gram, uint256 water_liter, uint256 compost_gram)
    {
        Touchpoint memory tp;
        uint256 _coffee_gram;
        uint256 _water_liter;
        uint256 _compost_gram;

        if (logger != address(0)) {
            uint256 nonce = ILog(logger).getNonceByItemId(bulletin, listId, uint256(0));

            if (nonce > 0) {
                for (uint256 i = 1; i <= nonce; ++i) {
                    tp = ILog(logger).getTouchpointByItemIdByNonce(bulletin, listId, uint256(0), i);

                    // Decode data and count user response.
                    if (tp.logType == LogType.TOKEN) {
                        (_coffee_gram, _water_liter, _compost_gram) = abi.decode(tp.data, (uint256, uint256, uint256));
                        coffee_gram += _coffee_gram;
                        water_liter += _water_liter;
                        compost_gram += _compost_gram;
                    }
                }
            }
        }
    }

    function buildCoffeeUsageSvg(uint256 coffee_gram, uint256 water_liter, uint256 compost_gram)
        public
        pure
        returns (string memory)
    {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "165"),
                    SVG._prop("font-size", "14"),
                    SVG._prop("fill", "#808080")
                ),
                string.concat("Coffee beans: ", SVG._uint2str(coffee_gram), " g")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "195"),
                    SVG._prop("font-size", "14"),
                    SVG._prop("fill", "#808080")
                ),
                string.concat("Filtered water: ", SVG._uint2str(water_liter), " lt")
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "225"),
                    SVG._prop("font-size", "14"),
                    SVG._prop("fill", "#808080")
                ),
                string.concat("Compost: ", SVG._uint2str(compost_gram), " g")
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// SVG Template #3: Feedback for Delivery
    /// -----------------------------------------------------------------------

    function feedbackForDelivery(TokenTitle memory title, TokenSource memory source)
        public
        view
        returns (string memory)
    {
        return JSON._formattedMetadata(
            title.name, title.desc, generateSvgForDeliveryService(source.bulletin, source.listId, source.logger)
        );
    }

    function generateSvgForDeliveryService(address bulletin, uint256 listId, address logger)
        public
        view
        returns (string memory)
    {
        List memory list = IBulletin(bulletin).getList(listId);
        (uint256 flavor, uint256 body, uint256 aroma) = getPerformanceData(bulletin, listId, logger);

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                list.title
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#FFBE0B"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "50"),
                    SVG._prop("width", "160"),
                    SVG._prop("height", "5")
                ),
                SVG.NULL
            ),
            loadPitcherConsumption(bulletin, listId, logger),
            buildPerformanceBars(flavor, body, aroma),
            "</svg>"
        );
    }

    function loadPitcherConsumption(address bulletin, uint256 listId, address logger)
        public
        view
        returns (string memory)
    {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "70"),
                    SVG._prop("y", "115"),
                    SVG._prop("font-size", "40"),
                    SVG._prop("fill", "#00040a")
                ),
                SVG._uint2str(loadNumOfRecylcedPitchers(bulletin, listId, logger))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "155"),
                    SVG._prop("y", "115"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#899499")
                ),
                "Pitchers Recylced"
            )
        );
    }

    function loadNumOfRecylcedPitchers(address bulletin, uint256 listId, address logger)
        public
        view
        returns (uint256 numOfRecylced)
    {
        Touchpoint memory tp;
        bool recycled;

        // TODO: Hardcoding itemId for demo purposes.
        uint256 itemId = 6;

        if (logger != address(0)) {
            uint256 nonce = ILog(logger).getNonceByItemId(bulletin, listId, itemId);

            if (nonce > 0) {
                for (uint256 i = 1; i <= nonce; ++i) {
                    // Decode data and count user response.
                    tp = ILog(logger).getTouchpointByItemIdByNonce(bulletin, listId, itemId, i);
                    if (tp.logType == LogType.TOKEN) {
                        delete recycled;
                        (recycled) = abi.decode(tp.data, (bool));

                        (recycled) ? ++numOfRecylced : numOfRecylced;
                    }
                }
            }
        }
    }

    // function buildTasksCompletions(address bulletin, List memory list) public view returns (string memory) {
    //     if (list.owner != address(0)) {
    //         uint256 length = (list.itemIds.length > 5) ? 5 : list.itemIds.length;
    //         string memory text;
    //         Item memory item;

    //         for (uint256 i; i < length; ++i) {
    //             item = IBulletin(bulletin).getItem(list.itemIds[i]);
    //             text = string.concat(
    //                 text,
    //                 SVG._text(
    //                     string.concat(
    //                         SVG._prop("x", "20"),
    //                         SVG._prop("y", SVG._uint2str(140 + 20 * i)),
    //                         SVG._prop("font-size", "12"),
    //                         SVG._prop("fill", "#808080")
    //                     ),
    //                     string.concat(item.title, ": ", SVG._uint2str(IBulletin(bulletin).runsByItem(list.itemIds[i])))
    //                 )
    //             );
    //         }
    //         return text;
    //     } else {
    //         return SVG.NULL;
    //     }
    // }

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
    /// SVG Template #4: Build Delivery Records
    /// -----------------------------------------------------------------------

    function deliveryRecord(TokenTitle memory title, TokenSource memory source) public view returns (string memory) {
        return JSON._formattedMetadata(
            title.name,
            title.desc,
            generateSvgForDeliveryRecord(source.user, source.bulletin, source.listId, source.logger)
        );
    }

    function generateSvgForDeliveryRecord(address user, address bulletin, uint256 listId, address logger)
        public
        view
        returns (string memory)
    {
        List memory list = IBulletin(bulletin).getList(listId);
        uint256 logId = (logger != address(0)) ? ILog(logger).getLogId(user, bulletin, listId) : 0;

        Touchpoint[] memory tps;
        tps = ILog(logger).getTouchpointsByLog(logId);
        uint256 length = tps.length;

        uint256 fridge;
        address recipient;
        bool recycled;

        for (uint256 i; i < length; ++i) {
            if (tps[i].itemId == 0) {
                // Decode data and load user response.
                (fridge, recipient, recycled) = abi.decode(tps[i].data, (uint256, address, bool));
            }
        }

        return string.concat(
            '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" style="background:#FFFBF5">',
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "40"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                shorten(user)
            ),
            SVG._rect(
                string.concat(
                    SVG._prop("fill", "#FFBE0B"),
                    SVG._prop("x", "20"),
                    SVG._prop("y", "50"),
                    SVG._prop("width", "160"),
                    SVG._prop("height", "5")
                ),
                SVG.NULL
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "100"),
                    SVG._prop("font-size", "20"),
                    SVG._prop("fill", "#00040a")
                ),
                list.title
            ),
            loadDeliveryTasks(bulletin, list.owner, list.itemIds),
            loadDeliveryRecord(fridge, recipient, recycled),
            "</svg>"
        );
    }

    function loadDeliveryTasks(address bulletin, address owner, uint256[] memory itemIds)
        public
        view
        returns (string memory)
    {
        if (owner != address(0)) {
            uint256 length = (itemIds.length > 3) ? 3 : itemIds.length;
            string memory text;
            Item memory item;

            for (uint256 i; i < length; ++i) {
                item = IBulletin(bulletin).getItem(itemIds[i]);
                text = string.concat(
                    text,
                    SVG._text(
                        string.concat(
                            SVG._prop("x", "20"),
                            SVG._prop("y", SVG._uint2str(140 + 50 * i)),
                            SVG._prop("font-size", "10"),
                            SVG._prop("fill", "#808080")
                        ),
                        string.concat(item.title, ": ")
                    )
                );
            }
            return text;
        } else {
            return SVG.NULL;
        }
    }

    function loadDeliveryRecord(uint256 fridge, address recipient, bool recycled) public pure returns (string memory) {
        return string.concat(
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "160"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#000000")
                ),
                string.concat("Fridge #", SVG._uint2str(fridge))
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "210"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#000000")
                ),
                shorten(recipient)
            ),
            SVG._text(
                string.concat(
                    SVG._prop("x", "20"),
                    SVG._prop("y", "260"),
                    SVG._prop("font-size", "12"),
                    SVG._prop("fill", "#000000")
                ),
                recycled ? "Yes" : "Not yet"
            )
        );
    }

    /// -----------------------------------------------------------------------
    /// Helper
    /// -----------------------------------------------------------------------

    // credit: https://ethereum.stackexchange.com/questions/46321/store-literal-bytes4-as-string
    function shorten(address user) internal pure returns (string memory) {
        bytes4 _address = bytes4(abi.encodePacked(user));

        bytes memory result = new bytes(10);
        result[0] = bytes1("0");
        result[1] = bytes1("x");
        for (uint256 i = 0; i < 4; ++i) {
            result[2 * i + 2] = toHexDigit(uint8(_address[i]) / 16);
            result[2 * i + 3] = toHexDigit(uint8(_address[i]) % 16);
        }
        return string(result);
    }

    function toHexDigit(uint8 d) internal pure returns (bytes1) {
        if (0 <= d && d <= 9) {
            return bytes1(uint8(bytes1("0")) + d);
        } else if (10 <= uint8(d) && uint8(d) <= 15) {
            return bytes1(uint8(bytes1("a")) + d - 10);
        }
        revert();
    }
}
