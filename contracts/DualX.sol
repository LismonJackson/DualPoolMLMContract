// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DataStorage.sol";

// Dapp: Dualx.pro
// Telegram: https://t.me/dualxpro
contract DualX is DataStorage {
    using Address for address payable;

    constructor(
        address _aggregator,
        address _contProvider,
        address _uniOverflow,
        uint256 _max0
    ) PriceFeed(_aggregator) {
        require(_aggregator != address(0) && _contProvider != address(0) && _uniOverflow != address(0));
        lastReward24h = block.timestamp;
        contProvider = payable(_contProvider);
        uniOverFlow = payable(_uniOverflow);
        max0 = _max0;
    }

    function Register(address referral) external payable {
        uint256 enterPrice = msg.value;
        address userAddr = msg.sender;

        _checkCanRegister(userAddr, referral);
        (
            uint8 entrance,
            uint16 directUp,
            uint256 enterPriceUSD,
            uint256 requiredMatic
        ) = checkEnterPrice(enterPrice);

        _payShares(requiredMatic, enterPriceUSD);
        _payUniLevel(referral, requiredMatic, enterPriceUSD);
        _newNode(userAddr, referral, entrance);
        _setChilds(userAddr, referral);
        _setDirects(userAddr, referral, directUp, 1);
        payable(userAddr).sendValue(enterPrice - requiredMatic);
    }

    function _checkCanRegister(
        address userAddr,
        address refAddr
    ) internal view returns (bool) {
        require(userAddr.code.length == 0, "onlyEOAs can register");
        require(
            !userAddrExists(userAddr),
            "This address is already registered!"
        );
        require(userAddrExists(refAddr), "This referral does not exist!");
        require(_userData[refAddr].childs < 2, "This address has Two directs.");
        return true;
    }

    function checkEnterPrice(
        uint256 enterPrice
    )
        internal
        view
        returns (
            uint8 entrance,
            uint16 directUp,
            uint256 enterPriceUSD,
            uint256 requiredMatic
        )
    {
        requiredMatic = USD_POL_Multiplier(100);
        if (enterPrice >= requiredMatic) {
            entrance = 100;
            directUp = 2;
            enterPriceUSD = 100 * 10 ** 18;
        } else {
            requiredMatic = USD_POL_Multiplier(50);
            if (enterPrice >= requiredMatic) {
                entrance = 50;
                directUp = 1;
                enterPriceUSD = 50 * 10 ** 18;
            } else {
                revert("Insufficient MATIC");
            }
        }
    }

    function _payShares(uint256 enterMatic, uint256 enterPriceUSD) internal {
        unchecked {
            todayEnteredUSD += enterPriceUSD;
            allEnteredUSD += enterPriceUSD;
        }
        contProvider.sendValue((enterMatic * 10) / 100);
    }

    function _payUniLevel(
        address refAddr,
        uint256 enterMatic,
        uint256 enterPriceUSD
    ) internal {
        uint256 percent = 1;
        uint256 totalValue;
        uint256 value;
        unchecked {
            for (uint256 i; i < 20; i++) {
                if (refAddr == address(0)) {
                    uniOverFlow.sendValue((enterMatic / 2) - totalValue);
                    break;
                } else {
                    if (i == 0) {
                        percent = 10;
                    } else if (i < 4) {
                        percent = 5;
                    } else if (i == 4) {
                        percent = 4;
                    } else if (i < 8) {
                        percent = 3;
                    } else {
                        percent = 1;
                    }
                    if (!_userIsFlashed[refAddr]) {
                        value = (enterMatic * percent) / 100;
                        totalValue += value;
                        payable(refAddr).sendValue(
                            (enterMatic * percent) / 100
                        );
                        _todayDirectPayments[dayCounter][refAddr] +=
                            (enterPriceUSD * percent) /
                            100;
                        _userDirectEarned_USD[refAddr] +=
                            (enterPriceUSD * percent) /
                            100;
                    }
                    refAddr = _userInfo[refAddr].uplineAddress;
                }
            }
        }
    }

    function _newNode(
        address userAddr,
        address upAddr,
        uint8 entrance
    ) internal {
        _userData[userAddr] = NodeData(
            0,
            0,
            0,
            0,
            0,
            0,
            _userData[upAddr].depth + 1,
            0,
            _userData[upAddr].childs,
            entrance
        );
        _userInfo[userAddr] = NodeInfo(upAddr, address(0), address(0));
        idToAddr[userCount] = userAddr;
        addrToId[userAddr] = userCount;
        unchecked {
            userCount++;
        }
    }

    function _setChilds(address userAddr, address upAddr) internal {
        if (_userData[upAddr].childs == 0) {
            _userInfo[upAddr].leftDirectAddress = userAddr;
        } else {
            _userInfo[upAddr].rightDirectAddress = userAddr;
        }
        unchecked {
            _userData[upAddr].childs++;
        }
    }

    function _setDirects(
        address userAddr,
        address upAddr,
        uint16 directUp,
        uint16 userUp
    ) internal {
        address[] storage rewardReceivers = _rewardReceivers[dayCounter];

        uint256 depth = _userData[userAddr].depth;
        uint32 _totalPoints;
        uint32 points;
        uint32 v;
        uint32 userTodayPoints;
        unchecked {
            depth;
            for (uint256 i; i < depth; i++) {
                if (!_userIsFlashed[upAddr]) {
                    NodeData storage upData = _userData[upAddr];
                    if (_userData[userAddr].isLeftOrRightChild == 0) {
                        if (upData.rightVariance == 0) {
                            upData.leftVariance += directUp;
                        } else {
                            if (upData.rightVariance < directUp) {
                                v = upData.rightVariance;
                                upData.rightVariance = 0;
                                upData.leftVariance += directUp - v;
                                points = v;
                            } else {
                                upData.rightVariance -= directUp;
                                points = directUp;
                            }
                        }
                        upData.allUsersLeft += userUp;
                        upData.allLeftDirect += directUp;
                    } else {
                        if (upData.leftVariance == 0) {
                            upData.rightVariance += directUp;
                        } else {
                            if (upData.leftVariance < directUp) {
                                v = upData.leftVariance;
                                upData.leftVariance = 0;
                                upData.rightVariance += directUp - v;
                                points = v;
                            } else {
                                upData.leftVariance -= directUp;
                                points = directUp;
                            }
                        }
                        upData.allUsersRight += userUp;
                        upData.allRightDirect += directUp;
                    }

                    if (points > 0) {
                        userTodayPoints = _todayPoints[dayCounter][upAddr];
                        if (
                            userTodayPoints < 2 && userTodayPoints + points >= 2
                        ) {
                            rewardReceivers.push(upAddr);
                        }
                        _todayPoints[dayCounter][upAddr] += points;
                        if (points == 2 || userTodayPoints % 2 == 1) {
                            _totalPoints++;
                        }
                        points = 0;
                    }
                }

                userAddr = upAddr;
                upAddr = _userInfo[upAddr].uplineAddress;
            }

            todayTotalPoint += _totalPoints;
        }
    }

    function Upgrade() external payable {
        address userAddr = msg.sender;
        uint256 upgradePrice = msg.value;

        address upAddr = _userInfo[userAddr].uplineAddress;
        (
            uint16 directUp,
            uint256 upgradePriceUSD,
            uint256 requiredMatic
        ) = _checkTopUpPrice(userAddr, upgradePrice);

        _payShares(requiredMatic, upgradePriceUSD);
        _payUniLevel(upAddr, requiredMatic, upgradePriceUSD);
        _setDirects(userAddr, upAddr, directUp, 0);

        payable(userAddr).sendValue(upgradePrice - requiredMatic);
    }

    function _checkTopUpPrice(
        address userAddr,
        uint256 upgradePrice
    )
        internal
        returns (
            uint16 directUp,
            uint256 upgradePriceUSD,
            uint256 requiredMatic
        )
    {
        uint256 entrance = _userData[userAddr].entrance;
        bool isFlashed = _userIsFlashed[userAddr];
        require(entrance == 50 || isFlashed, "You cannot upgrade!");

        if (isFlashed) {
            requiredMatic = USD_POL_Multiplier(100);
            if (upgradePrice >= requiredMatic) {
                upgradePriceUSD = 100 * 10 ** 18;
                _userData[userAddr].entrance = 100;
                _userIsFlashed[userAddr] = false;
                directUp = 2;
            } else {
                requiredMatic = USD_POL_Multiplier(50);
                if (upgradePrice >= requiredMatic) {
                    upgradePriceUSD = 50 * 10 ** 18;
                    _userData[userAddr].entrance = 50;
                    _userIsFlashed[userAddr] = false;
                    directUp = 1;
                } else {
                    revert("Insufficient MATIC");
                }
            }
        } else {
            requiredMatic = USD_POL_Multiplier(50);
            if (upgradePrice >= requiredMatic) {
                upgradePriceUSD = 50 * 10 ** 18;
                directUp = 1;
                _userData[userAddr].entrance = 100;
            } else {
                revert("Insufficient MATIC");
            }
        }
    }

    function Distribute() external {
        uint256 currentTime = block.timestamp;
        uint256 _POL_USD = POL_USD;
        require(
            currentTime >= lastReward24h + 24 hours - 5 minutes,
            "Time exception."
        );
        lastReward24h = currentTime;
        _reward24h(_POL_USD);
        _updateMaticePrice();
    }

    function _reward24h(uint256 _POL_USD) internal {
        uint256 pointValue = todayEveryPointValue();
        uint256 pointValueUSD = (pointValue * _POL_USD) / 10 ** 18;

        address[] storage rewardReceivers = _rewardReceivers[dayCounter];

        address userAddr;
        uint256 len = rewardReceivers.length;
        uint256 userPoints;
        uint256 user10Entrance;
        uint256 sendingValueUSD;
        uint256 uniEarnedUSDToday;
        unchecked {
            for (uint256 i; i < len; i++) {
                userAddr = rewardReceivers[i];
                user10Entrance = _userData[userAddr].entrance * 10;
                userPoints = _todayPoints[dayCounter][userAddr] / 2;
                sendingValueUSD = userPoints * pointValueUSD;
                uniEarnedUSDToday = _todayDirectPayments[dayCounter][userAddr];
                if (
                    sendingValueUSD + uniEarnedUSDToday <
                    user10Entrance * 1 ether
                ) {
                    _userAllEarned_USD[userAddr] += sendingValueUSD;
                    payable(userAddr).sendValue(userPoints * pointValue);
                } else {
                    if (uniEarnedUSDToday < user10Entrance * 1 ether) {
                        sendingValueUSD =
                            (user10Entrance * 1 ether) -
                            uniEarnedUSDToday;

                        _userAllEarned_USD[userAddr] += sendingValueUSD;
                        if (userAddr.code.length == 0) {
                            _userIsFlashed[userAddr] = true;
                        }
                        payable(userAddr).sendValue(
                            USD_POL_Multiplier(sendingValueUSD / 1 ether)
                        );
                    }
                }
            }
        }
        uniOverFlow.sendValue(balance());
        delete todayTotalPoint;
        delete todayEnteredUSD;
        _dayIncrement();
    }

    function _register(address upAddr, address userAddr) external {
        require(userCount < max0, "contract full");
        require(_userData[upAddr].childs < 2, "This address has Two directs.");
        if (userCount > 0) {
            require(userAddrExists(upAddr), "referral not registered!");
        }
        require(!userAddrExists(userAddr), "Already registered userAddr!");
        _newNode(userAddr, upAddr, 100);
        _setDirects(userAddr, upAddr, 0, 1);
        _setChilds(userAddr, upAddr);
    }

    receive() external payable {}
}
