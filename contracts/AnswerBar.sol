pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


contract AnswerBar is ERC20("AnswerBar", "xAnswer"){
    using SafeMath for uint256;
    IERC20 public Answer;

    constructor(IERC20 _Answer) public {
        Answer = _Answer;
    }

// 유저 스시 잔고 표시 , 총 유통량 표시
    // Enter the bar. Pay some Answers. Earn some shares.
    function enter(uint256 _amount) public {
        uint256 totalAnswer = Answer.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalAnswer == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalAnswer);
            _mint(msg.sender, what);
        }
        Answer.transferFrom(msg.sender, address(this), _amount);
    }

// 스시 반환 
    // Leave the bar. Claim back your Answers.
    function leave(uint256 _share) public {
        uint256 totalShares = totalSupply();
        uint256 what = _share.mul(Answer.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        Answer.transfer(msg.sender, what);
    }
}
