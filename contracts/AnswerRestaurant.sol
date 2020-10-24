pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract AnswerRestaurant {
    using SafeMath for uint256;
    event Enter(address indexed user, uint256 amount);
    event Leave(address indexed user, uint256 amount);

    IERC20 public Answer;

    uint256 public reductionPerBlock;
    uint256 public multiplier;
    uint256 public lastMultiplerProcessBlock;

    uint256 public accAnswerPerShare;
    uint256 public ackAnswerBalance;
    uint256 public totalShares;

    struct UserInfo {
        uint256 amount; // Answer stake amount
        uint256 share;
        uint256 rewardDebt;
    }

    mapping (address => UserInfo) public userInfo;

    constructor(IERC20 _Answer, uint256 _reductionPerBlock) public {
        Answer = _Answer;
        reductionPerBlock = _reductionPerBlock; // Use 999999390274979584 for 10% per month
        multiplier = 1e18; // Should be good for 20 years
        lastMultiplerProcessBlock = block.number;
    }

    // Clean the restaurant. Called whenever someone enters or leaves.
    function cleanup() public {
        // Update multiplier
        uint256 reductionTimes = block.number.sub(lastMultiplerProcessBlock);
        uint256 fraction = 1e18;
        uint256 acc = reductionPerBlock;
        while (reductionTimes > 0) {
            if (reductionTimes & 1 != 0) {
                fraction = fraction.mul(acc).div(1e18);
            }
            acc = acc.mul(acc).div(1e18);
            reductionTimes = reductionTimes / 2;
        }
        multiplier = multiplier.mul(fraction).div(1e18);
        lastMultiplerProcessBlock = block.number;
        // Update accAnswerPerShare / ackAnswerBalance
        if (totalShares > 0) {
            uint256 additionalAnswer = Answer.balanceOf(address(this)).sub(ackAnswerBalance);
            accAnswerPerShare = accAnswerPerShare.add(additionalAnswer.mul(1e12).div(totalShares));
            ackAnswerBalance = ackAnswerBalance.add(additionalAnswer);
        }
    }

    // Get user pending reward. May be outdated until someone calls cleanup.
    function getPendingReward(address _user) public view returns (uint256) {
        UserInfo storage user = userInfo[_user];
        return user.share.mul(accAnswerPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Enter the restaurant. Pay some Answers. Earn some shares.
    function enter(uint256 _amount) public {
        cleanup();
        safeAnswerTransfer(msg.sender, getPendingReward(msg.sender));
        Answer.transferFrom(msg.sender, address(this), _amount);
        ackAnswerBalance = ackAnswerBalance.add(_amount);
        UserInfo storage user = userInfo[msg.sender];
        uint256 moreShare = _amount.mul(multiplier).div(1e18);
        user.amount = user.amount.add(_amount);
        totalShares = totalShares.add(moreShare);
        user.share = user.share.add(moreShare);
        user.rewardDebt = user.share.mul(accAnswerPerShare).div(1e12);
        emit Enter(msg.sender, _amount);
    }

    // Leave the restaurant. Claim back your Answers.
    function leave(uint256 _amount) public {
        cleanup();
        safeAnswerTransfer(msg.sender, getPendingReward(msg.sender));
        UserInfo storage user = userInfo[msg.sender];
        uint256 lessShare = user.share.mul(_amount).div(user.amount);
        user.amount = user.amount.sub(_amount);
        totalShares = totalShares.sub(lessShare);
        user.share = user.share.sub(lessShare);
        user.rewardDebt = user.share.mul(accAnswerPerShare).div(1e12);
        safeAnswerTransfer(msg.sender, _amount);
        emit Leave(msg.sender, _amount);
    }

    // Safe Answer transfer function, just in case if rounding error causes pool to not have enough Answers.
    function safeAnswerTransfer(address _to, uint256 _amount) internal {
        uint256 AnswerBal = Answer.balanceOf(address(this));
        if (_amount > AnswerBal) {
            Answer.transfer(_to, AnswerBal);
            ackAnswerBalance = ackAnswerBalance.sub(AnswerBal);
        } else {
            Answer.transfer(_to, _amount);
            ackAnswerBalance = ackAnswerBalance.sub(_amount);
        }
    }
}