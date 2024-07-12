// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorInterface.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

abstract contract PriceFeed {
    using Strings for uint256;
    AggregatorInterface AGGREGATOR_POL_USD;

    uint256 POL_USD;
    uint256 USD_POL;

    uint256 lastUpdatePrice;
    address aggControl;

    constructor(
        address aggregatorAddr
    ) {
        AGGREGATOR_POL_USD = AggregatorInterface(aggregatorAddr);
        _updateMaticePrice();
        aggControl = msg.sender;
    }

    function USD_POL_Multiplier(uint256 num) internal view returns(uint256) {
        return num * USD_POL;
    }

    function get_POL_USD() private view returns(uint256) {
        return uint256(AGGREGATOR_POL_USD.latestAnswer());
    }

    function _updateMaticePrice() internal {
        uint256 POL_USD_8 = get_POL_USD();
        POL_USD = POL_USD_8 * 10 ** 10;
        USD_POL = 10 ** 26 / POL_USD_8;
        lastUpdatePrice = block.timestamp;
    }

    function updateMaticPrice() public {
        require(
            block.timestamp > lastUpdatePrice + 4 hours,
            "time exception"
        );
        _updateMaticePrice();
    }

    function updateMaticAggregator(address aggregatorAddr) public {
        require(
            msg.sender == aggControl
        );
        AGGREGATOR_POL_USD = AggregatorInterface(aggregatorAddr);
    }
}