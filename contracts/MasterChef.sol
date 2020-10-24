pragma solidity 0.6.2;


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AnswerToken.sol";


interface IMigratorChef {
    // Perform LP token migration from legacy UniswapV2 to AnswerSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to UniswapV2 LP tokens.
    // AnswerSwap must mint EXACTLY the same amount of AnswerSwap LP tokens or
    // else something bad will happen. Traditional UniswapV2 does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}

// MasterChef is the master of Answer. He can make Answer and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Answer is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Answers
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accAnswerPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accAnswerPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. Answers to distribute per block.
        uint256 lastRewardBlock;  // Last block number that Answers distribution occurs.
        uint256 accAnswerPerShare; // Accumulated Answers per share, times 1e12. See below.
    }

    // The Answer TOKEN!
    AnswerToken public Answer;
    // Dev address.
    address public devaddr;
    // Block number when bonus Answer period ends.
    uint256 public bonusEndBlock;
    // Answer tokens created per block.
    uint256 public AnswerPerBlock;
    // Bonus muliplier for early Answer makers. 
    uint256 public constant BONUS_MULTIPLIER = 10; //10
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when Answer mining starts.
    uint256 public startBlock;

    uint256 public betaTestEndBlock;
    // Block number when bonus ANSWER period ends.
    
    // Block number when mint ANSWER period ends.
    uint256 public mintEndBlock;
    uint256 public constant BONUSBETA_MULTIPLIER = 100;
    
    // Bonus muliplier for Period 1 
    uint256 public constant BONUSONE_MULTIPLIER = 10;
    // Bonus muliplier for Period 2 
    uint256 public constant BONUSTWO_MULTIPLIER = 1;

    // beta test block num,about 2 weeks
    uint256 public constant BETATEST_BLOCKNUM = 93045;
    // Bonus block num,about 4 weeks 
    uint256 public constant BONUS_BLOCKNUM = 186089;
    // mint end block num (upto aprox. 500000000)
    uint256 public constant MINTEND_BLOCKNUM = 32312870;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        AnswerToken _Answer,
        address _devaddr,
        uint256 _AnswerPerBlock,
        uint256 _startBlock
        //uint256 _bonusEndBlock
    ) public {
        Answer = _Answer;
        devaddr = _devaddr;
        AnswerPerBlock = _AnswerPerBlock;
        //bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
        
        betaTestEndBlock = startBlock.add(BETATEST_BLOCKNUM);
        bonusEndBlock = startBlock.add(BONUS_BLOCKNUM).add(BETATEST_BLOCKNUM);
        mintEndBlock = startBlock.add(MINTEND_BLOCKNUM).add(BONUS_BLOCKNUM).add(BETATEST_BLOCKNUM);
        //mintEndBlock = startBlock.add(MINTEND_BLOCKNUM).add(BETATEST_BLOCKNUM);
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accAnswerPerShare: 0
        }));
    }

    // Update the given pool's Answer allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 lpToken = pool.lpToken;
        uint256 bal = lpToken.balanceOf(address(this));
        lpToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(lpToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.lpToken = newLpToken;
    }

    // // Return reward multiplier over the given _from to _to block.
    // function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
    //     if (_to <= bonusEndBlock) {
    //         return _to.sub(_from).mul(BONUS_MULTIPLIER);
    //     } else if (_from >= bonusEndBlock) {
    //         return _to.sub(_from);
    //     } else {
    //         return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
    //             _to.sub(bonusEndBlock)
    //         );
    //     }
    // }

     // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        uint256 _toFinal = _to > mintEndBlock ? mintEndBlock : _to;
        if (_toFinal <= betaTestEndBlock) {
             //return _toFinal.sub(_from);
             return _toFinal.sub(_from).mul(BONUSBETA_MULTIPLIER);
        }else if (_from >= mintEndBlock) {
            return 0;
        } else if (_toFinal <= bonusEndBlock) {
            if (_from < betaTestEndBlock) {
                return betaTestEndBlock.sub(_from).add(_toFinal.sub(betaTestEndBlock).mul(BONUSONE_MULTIPLIER));
            } else {
                return _toFinal.sub(_from).mul(BONUSONE_MULTIPLIER);
            }
        } else {
            if (_from < betaTestEndBlock) {
                return betaTestEndBlock.sub(_from).add(bonusEndBlock.sub(betaTestEndBlock).mul(BONUSONE_MULTIPLIER)).add(
                    (_toFinal.sub(bonusEndBlock).mul(BONUSTWO_MULTIPLIER)));
            } else if (betaTestEndBlock <= _from && _from < bonusEndBlock) {
                return bonusEndBlock.sub(_from).mul(BONUSONE_MULTIPLIER).add(_toFinal.sub(bonusEndBlock).mul(BONUSTWO_MULTIPLIER));
            } else {
                return _toFinal.sub(_from).mul(BONUSTWO_MULTIPLIER);
            }
        } 
    }

    // View function to see pending Answers on frontend.
    function pendingAnswer(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accAnswerPerShare = pool.accAnswerPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 AnswerReward = multiplier.mul(AnswerPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accAnswerPerShare = accAnswerPerShare.add(AnswerReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accAnswerPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 AnswerReward = multiplier.mul(AnswerPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        Answer.mint(devaddr, AnswerReward.div(15)); ///  DEVFUND ADDR RATE   
        Answer.mint(address(this), AnswerReward);
        pool.accAnswerPerShare = pool.accAnswerPerShare.add(AnswerReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for Answer allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accAnswerPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeAnswerTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accAnswerPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accAnswerPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeAnswerTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accAnswerPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe Answer transfer function, just in case if rounding error causes pool to not have enough Answers.
    function safeAnswerTransfer(address _to, uint256 _amount) internal {
        uint256 AnswerBal = Answer.balanceOf(address(this));
        if (_amount > AnswerBal) {
            Answer.transfer(_to, AnswerBal);
        } else {
            Answer.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
