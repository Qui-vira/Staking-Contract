//SPDX-License-Identifier: MIT

//Live Link: https://staking-ophir.vercel.app/

/*Project Resources

Contracts Verified at:
Stake Contract 
Staking Token (BoredPepe): 0xdb20ac6A5b4d8A22880Da56eDD213f06b232C334
Reward Token (Happy Pepe): 0x28c528c6A3E22359F80E8C5fd6FF13bDca30810B
*/ 

////////////////////PROJECT OVERVIEW/////////////

//Utilizing Libraries Why?

//Brainstorming on what libraries we should use: 

//** Math/Address/SafeERC20/IERC20/Reentrancy

//How do we come up with the fact that these libary are needed why cant we just create it our self

//Import these libraries into our code (2 method)

//Create and deploy a stake token(BoredPePe) and reward token(Happy PePe)

//Build Our Staking contract

//StakingLibrary Tour

//Build our main contract

//Lastly verify our contracts

//2 ways to import libaries

//Common way: Import our libaries
//



import "./Math.sol";
import "./Address.sol";
import "./SafeERC20.sol";
//developers dont follow the standard strictly why?
import "./IERC20.sol";
//Interface for ERC20
import "./ReentrancyGuard.sol";
import "./PoolManager.sol";

//Reentrancy attack is an act where by an attacker exploit a withdrawal function


//Cultdao: 0xf0f9D895aCa5c8678f706FB8216fa22957685A13

pragma solidity >=0.7.0<0.9.0;

contract StakeBoredom is ReentrancyGuard {

    using SafeERC20 for IERC20;
    using PoolManager for PoolManager.PoolState;

    //STEP 1: Declare necessary variables
    PoolManager.PoolState private _stake;

    uint256 private _totalStake; //Tottal amount of BoredPepe Staked
    mapping (address => uint256) private _userRewardPerTokenPaid;
    mapping  (address => uint256) private  _rewards;
    mapping (address => uint256) private _balances;

 
    //STEP 2: Inherit the ERC20 Interface

    IERC20 public immutable stakingToken; // CONSTANTS or immutable
    IERC20 public immutable rewardToken;


    //STEP 3: Build our Constructor
    constructor (address _distributor, IERC20 stakingToken_, IERC20 rewardToken_, uint64 _duration) {
        stakingToken = stakingToken_;
        rewardToken = rewardToken_;
        _stake.distributor = uint160(_distributor);
        _stake.rewardsDuration = _duration * 1 days;


}

    //STEP 4: Create some modifiers//
    // 1. onlyDistributor

    modifier onlyDistributor() {
        require(msg.sender == address(_stake.distributor), "Not Distributor");

        _;
    }
    
    //2. update rewards

    modifier  updateRewards(address account) {
        _stake.updateReward(_totalStake);

        if(account !=address(0)) {
           // _rewards[account] = earned(account);
            _userRewardPerTokenPaid[account] = _stake.rewardPerTokenStored;
        }
        _;

    }

    //STEP 5: Create some functions to read the contract

    function totalAmountStaked() external view returns (uint256) {
        return _totalStake;
    }

    function balanceOf(address account) external view returns (uint256)  {
        return _balances[account];

     }

        function getOwner() external view returns (address)
    {
        return address(_stake.distributor);
    }

    function lastTimeRewardApplicable() external view returns (uint256)
    {
        return _stake.lastTimeRewardApplicable();
    }

    function rewardPerToken() external view returns (uint256)
    {
        return _stake.rewardPerToken(_totalStake);
    }

    function getRewardForDuration() external view returns (uint256)
    {
        return _stake.getRewardForDuration();
    }

    function earned(address account) public view returns (uint256)
    {
        return _balances[account] * (
            _stake.rewardPerToken(_totalStake) - _userRewardPerTokenPaid[account]
        ) / 1e18 + _rewards[account];
    }


    //STEP 6: Build our writable functions


    /**
    Stake
    Claim -getReward
    Withdraw - exit
    */

    function stake(uint amount) external payable nonReentrant updateRewards(msg.sender){
        require (amount > 0, "Stake must be greater than zero");

        stakingToken.safeTransferFrom(msg.sender, address(this), amount);
        _totalStake += amount;
        _balances[msg.sender] += amount;

        // Emit an Event
        emit Staked(msg.sender, amount);
    }

    function getReward() public payable nonReentrant updateRewards(msg.sender){
        uint256 reward = _rewards[msg.sender];
        
        if (reward > 0) {
            _rewards[msg.sender] = 0;
            rewardToken.safeTransfer(msg.sender, reward);

            emit RewardPaid(msg.sender, reward);
        }
            }

        function exit() external payable nonReentrant {
            _stake.updateReward(_totalStake);

            uint256 balance = _balances[msg.sender];
            uint256 reward = earned(msg.sender);

            _userRewardPerTokenPaid[msg.sender] = _stake.rewardPerTokenStored;
            _balances[msg.sender] -= balance;
            _rewards[msg.sender] = 0;
            _totalStake -= balance;

            _stake.updateReward(_totalStake);

            if (stakingToken == rewardToken) {
                stakingToken.safeTransfer(msg.sender, balance + reward);

            }

            else {
                stakingToken.safeTransfer(msg.sender, balance);
                rewardToken.safeTransfer(msg.sender, reward);
            }

            emit Withdrawn(msg.sender, balance);
            emit RewardPaid(msg.sender, reward);
        }
    //STEP 7: Add protected functions for reward distributor

     function setDistributor(address newDistributor) external payable onlyDistributor
    {
        require(newDistributor != address(0), "Cannot set to zero addr");
        _stake.distributor = uint160(newDistributor);
    }
 
    function depositRewardTokens(uint256 amount) external payable onlyDistributor
    {
        require(amount > 0, "Must be greater than zero");

        rewardToken.safeTransferFrom(msg.sender, address(this), amount);

        notifyRewardAmount(amount);
    }

    function notifyRewardAmount(uint256 reward) public payable updateRewards(address(0)) onlyDistributor
    {
        uint256 duration = _stake.rewardsDuration;

        if (block.timestamp >= _stake.periodFinish) {
            _stake.rewardRate = reward / duration;
        } else {
            uint256 remaining = _stake.periodFinish - block.timestamp;
            uint256 leftover = remaining * _stake.rewardRate;
            _stake.rewardRate = (reward + leftover) / duration;
        }

        uint256 balance = rewardToken.balanceOf(address(this));

        if (rewardToken == stakingToken) {
            balance -= _totalStake;
        }

        require(_stake.rewardRate <= balance / duration, "Reward too high");

        _stake.lastUpdateTime = uint64(block.timestamp);
        _stake.periodFinish = uint64(block.timestamp + duration);

        emit RewardAdded(reward);
    }


    // STEP 8: Emit some events

    /* ========== EVENTS ========== */

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event DistributorUpdated(address indexed newDistributor);
}



