// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./PriceFeed.sol";
import "./utils/UintToFloatString.sol";

library Address {
    function sendValue(address payable recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }
}

abstract contract DataStorage is PriceFeed {
    using UintToFloatString for uint256;
    using Strings for *;

    struct NodeData {
        uint32 allUsersLeft;
        uint32 allUsersRight;
        uint40 allLeftDirect;
        uint40 allRightDirect;
        uint32 leftVariance;
        uint32 rightVariance;
        uint24 depth;
        uint8 childs;
        uint8 isLeftOrRightChild;
        uint8 entrance;
    }

    struct NodeInfo {
        address uplineAddress;
        address leftDirectAddress;
        address rightDirectAddress;
    }

    mapping(address => bool) public _userIsFlashed;
    mapping(address => uint256) _userAllEarned_USD;
    mapping(address => uint256) _userDirectEarned_USD;
    mapping(address => NodeData) public _userData;
    mapping(address => NodeInfo) public _userInfo;
    mapping(uint256 => address) public idToAddr;
    mapping(address => uint256) public addrToId;

    uint256 public lastReward24h;
    uint256 public userCount;
    uint256 public todayTotalPoint;
    uint256 public todayEnteredUSD;
    uint256 public allEnteredUSD;
    address payable contProvider;
    address payable uniOverFlow;
    uint256 max0;

    function GetAmountMatic(uint256 amountUSD) external view returns(string memory) {
        return string.concat((USD_POL_Multiplier(amountUSD) + 0.1 ether).floatString(18, 1), " (ether)");
    }

    function MainInfo() external view returns(
        uint256 userCount_,
        string memory pointValue_,
        uint256 todayPoints_,
        string memory todayEnteredUSD_,
        string memory allEnteredUSD_,
        string memory NextDistribute
    ) {
        userCount_ = userCount;
        pointValue_ = todayEveryPointValueUSD(); 
        todayPoints_ = todayTotalPoint;
        todayEnteredUSD_ = string.concat((todayEnteredUSD + 0.01 ether).floatString(18, 0), " $");
        allEnteredUSD_ = string.concat((allEnteredUSD+ 0.01 ether).floatString(18, 0), " $");
        NextDistribute = timeToNextDistribute();
    }

    function UserInfo(address userAddr) external view returns(
        uint256 todayPoints,
        string memory entrance,
        string memory todayUniLevel,
        string memory todayLeft,
        string memory todayRight,
        string memory allTimeLeft,
        string memory allTimeRight,
        uint256 usersLeft,
        uint256 usersRight,
        string memory totalBinaryEarned,
        string memory totalUniLevelEarned
    ) {
        uint256 todayHalfPoint = _todayPoints[dayCounter][userAddr];
        todayPoints = todayHalfPoint / 2;
        entrance = string.concat(_userData[userAddr].entrance.toString(), " $");
        todayUniLevel = string.concat((_todayDirectPayments[dayCounter][userAddr]).floatString(18, 2), " $");
        todayLeft = string.concat(((_userData[userAddr].leftVariance + todayHalfPoint) * 50).toString(), " $");
        todayRight = string.concat(((_userData[userAddr].rightVariance + todayHalfPoint) * 50).toString(), " $");
        allTimeLeft = string.concat(((_userData[userAddr].allLeftDirect) * 50).toString(), " $");
        allTimeRight = string.concat(((_userData[userAddr].allRightDirect) * 50).toString(), " $");
        usersLeft = _userData[userAddr].allUsersLeft;
        usersRight = _userData[userAddr].allUsersRight;
        totalBinaryEarned = string.concat(_userAllEarned_USD[userAddr].floatString(18, 2), " $");
        totalUniLevelEarned = string.concat((_userDirectEarned_USD[userAddr]).floatString(18, 2), " $");
    }

    function userAddrExists(address userAddr) public view returns(bool) {
        return _userData[userAddr].entrance != 0;
    }

    function balance() public view returns(uint256) {
        return address(this).balance;
    }

    function todayEveryPointValue() public view returns(uint256 pointValue) {
        uint256 denominator = todayTotalPoint;
        denominator = denominator > 0 ? denominator : 1;
        pointValue =  address(this).balance / denominator;
        if((pointValue * POL_USD / 1 ether) > 40 ether){
            return USD_POL_Multiplier(40);
        }
    }

    function todayEveryPointValueUSD() public view returns(string memory) {
        return string.concat((todayEveryPointValue() * POL_USD/10**18).floatString(18, 2), " $");
    }

    function userChilds(address userAddr)
        external
        view
        returns (address left, address right)
    {
        left = _userInfo[userAddr].leftDirectAddress;
        right = _userInfo[userAddr].rightDirectAddress;        
    }
    
    function userUpReferral(address userAddr) public view returns(address) {
        return _userInfo[userAddr].uplineAddress;
    }

    function userPoints(address userAddr, uint256 fromDaysAgo, uint256 toDaysAgo) external view returns (uint256[] memory points) {

        uint256 len = fromDaysAgo - toDaysAgo + 1;
        points = new uint256[](len);
        for(uint256 i ; i < len; i++) {
            points[i] = _todayPoints[dayCounter - fromDaysAgo + i][userAddr] / 2;
        }
    }


    function userUniLevelEarn(address userAddr, uint256 fromDaysAgo, uint256 toDaysAgo) external view returns (uint256[] memory amounts) {
        uint256 len = fromDaysAgo - toDaysAgo + 1;
        amounts = new uint256[](len);
        for(uint256 i ; i < len; i++) {
            amounts[i] = _todayDirectPayments[dayCounter - fromDaysAgo + i][userAddr];
        }
    }

    function BestReferral(address userAddr) public view returns(address refAddr) {
        if(_userData[userAddr].childs < 2) {
            return userAddr;
        } else {
            if(_userData[userAddr].leftVariance > _userData[userAddr].rightVariance) {
                refAddr = _userInfo[userAddr].rightDirectAddress;
            } else {
                refAddr = _userInfo[userAddr].leftDirectAddress;
            }
            while(_userData[refAddr].childs != 0) {
                if(_userData[refAddr].leftVariance >= _userData[refAddr].rightVariance) {
                    refAddr = _userInfo[refAddr].leftDirectAddress;
                } else {
                    refAddr = _userInfo[refAddr].rightDirectAddress;
                }
            }
            return refAddr;
        }
    }
    
    function userUp(uint256 userId) public view returns(uint256 upId) {
        return addrToId[_userInfo[idToAddr[userId]].uplineAddress];
    }

    function timeToNextDistribute() internal view returns(string memory) {
        uint256 nextTime = (24 hours - 5 minutes) + lastReward24h;
        if(nextTime < block.timestamp) {
            return "Time's up!";
        } else {
            uint256 remainingTime = nextTime - block.timestamp;
            return string.concat(
                " remaining : ",
                ((remainingTime % 1 days) / 1 hours).toString(),
                " hours, ",
                ((remainingTime % 1 hours) / 1 minutes).toString(),
                " minutes"
            );
        }
    }


// enumereable arrays -------------------------------------------------------------------
    mapping(uint256 => mapping(address => uint32)) _todayPoints;
    mapping(uint256 => mapping(address => uint256)) _todayDirectPayments;
    mapping(uint256 => address[]) _rewardReceivers;

    uint256 dayCounter;
    
    function _dayIncrement() internal {
        unchecked{
            dayCounter ++;
        }
    }

    function rewardReceivers(uint256 daysAgo) public view returns(address[] memory addr) {
        uint256 len = _rewardReceivers[dayCounter].length;
        addr = new address[](len);

        unchecked{ for(uint256 i; i < len; i++) {
            addr[i] = _rewardReceivers[dayCounter - daysAgo][i];
        }}
    }
}