// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/utils/Strings.sol';

library UintToFloatString {
    using Strings for uint256;

    function floatString(
        uint256 number,
        uint8 inDecimals,
        uint8 outDecimals
    ) internal pure returns (string memory) {
        string memory h = (number / 10**inDecimals).toString();

        if (outDecimals > 0) {
            uint256 remainder = number % 10**inDecimals;
            if(remainder > 0) {
                h = string.concat(h, '.');
                while (outDecimals > 0) {
                    remainder *= 10;
                    h = string.concat(h, (remainder / 10**inDecimals).toString());
                    remainder %= 10**inDecimals;
                    outDecimals--;
                }
            }
        }
        return h;
    }
}