// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;


import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import './interfaces/IPair.sol';
import './interfaces/IBribe.sol';
import './interfaces/IMaLPNFT.sol';
import "./libraries/Math.sol";

interface IRewarder {
    function onReward(
        uint256 pid,
        address user,
        address recipient,
        uint256 amount,
        uint256 newLpAmount
    ) external;
}


contract MaGauge is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct PositionInfo {
        uint amount;
        uint rewardDebt;
        uint rewardCredit;
        uint entry; // position owner's relative entry into the pool.
        uint poolId; // ensures that a single Relic is only used for one pool.
        uint level;
    }  

    bool public isForPair;


    IERC20 public rewardToken;
    IERC20 public _VE;
    IERC20 public TOKEN;

    address public DISTRIBUTION;
    address public gaugeRewarder;
    address public internal_bribe;
    address public external_bribe;
    address public maNFTs;

    uint256 public DURATION;
    uint256 public periodFinish;
    uint256 public rewardRate;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint public maGaugeId;

    uint public fees0;
    uint public fees1;

    mapping(uint => uint256) public userRewardPerTokenPaid;
    mapping(uint => uint256) public rewards;

    uint256 public _totalSupply;
    mapping(uint => uint256) public _balances;
    mapping(uint => uint256) public _depositEpoch;
    mapping(uint => uint256) public _start;
    uint nextEpoch;

    event RewardAdded(uint256 reward);
    event Deposit(address indexed user, uint tokenId, uint256 amount);
    event Withdraw(address indexed user, uint tokenId, uint256 amount);
    event Harvest(address indexed user, uint tokenId, uint256 reward);
    event ClaimFees(address indexed from, uint claimed0, uint claimed1);



    uint lastTimeAdjustedEpoch;
    uint WEEK;
    uint[16] balancesByEpoch;
    uint PRECISION = 1000;


    function updateReward(uint _tokenId) public adjustWeights {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (_tokenId != 0) {
            rewards[_tokenId] = earned(_tokenId);
            userRewardPerTokenPaid[_tokenId] = rewardPerTokenStored;
        }
    }


    modifier adjustWeights() {

        if( block.timestamp >= nextEpoch) {
            
            uint nextValue;
            uint _nextValue;
            for(uint i = 0; i < balancesByEpoch.length-1; i++) {
                _nextValue = balancesByEpoch[i];
                balancesByEpoch[i] = nextValue;
                nextValue = _nextValue;
            }
            balancesByEpoch[balancesByEpoch.length-1] = balancesByEpoch[balancesByEpoch.length-1] + nextValue;

            nextEpoch = nextEpoch + WEEK;
        }
        _;
    }

    modifier onlyDistribution() {
        require(msg.sender == DISTRIBUTION, "Caller is not RewardsDistribution contract");
        _;
    }



    constructor(address _rewardToken,address _ve,address _token,address _distribution, address _internal_bribe, address _external_bribe, bool _isForPair, address _maNFTs, uint _maGaugeId) {
        rewardToken = IERC20(_rewardToken);     // main reward
        _VE = IERC20(_ve);                      // vested
        TOKEN = IERC20(_token);                 // underlying (LP)
        DISTRIBUTION = _distribution;           // distro address (voter)
        DURATION = 7 * 86400;  
        WEEK = 7 * 86400;                   // week
        
        nextEpoch = ((block.timestamp/WEEK)+1) * WEEK;
        maGaugeId = _maGaugeId;
        maNFTs = _maNFTs;

        internal_bribe = _internal_bribe;       // lp fees goes here
        external_bribe = _external_bribe;       // bribe fees goes here

        isForPair = _isForPair;                       // pair boolean, if false no claim_fees

    }

    ///@notice set distribution address (should be GaugeProxyL2)
    function setDistribution(address _distribution) external onlyOwner {
        require(_distribution != address(0), "zero addr");
        require(_distribution != DISTRIBUTION, "same addr");
        DISTRIBUTION = _distribution;
    }

    ///@notice set gauge rewarder address
    function setGaugeRewarder(address _gaugeRewarder) external onlyOwner {
        require(_gaugeRewarder != address(0), "zero addr");
        require(_gaugeRewarder != gaugeRewarder, "same addr");
        gaugeRewarder = _gaugeRewarder;
    }


    ///@notice total supply held
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    ///@notice total weight of matured liquidity provided
    function totalWeight() public view returns (uint256 _totalWeight) {
        uint[] memory weightsAmount = IMaLPNFT(maNFTs).getWeightByEpoch();
        uint _weightAmount;

        for(uint i = 0; i < balancesByEpoch.length; i++) {
            if (i <= weightsAmount.length) {
                _weightAmount = weightsAmount[i];
            }
            _totalWeight = _totalWeight + (balancesByEpoch[i]*_weightAmount/PRECISION);
        }
    }

    ///@notice balance of a position
    function balanceOfToken(uint tokenId) external view returns (uint256) {
        return _balances[tokenId];
    }

    ///@notice weight of a position
    function weightOfToken(uint _tokenId) public view returns (uint256) {
        uint _balance = _balances[_tokenId];
        uint _matLevel = maturityLevelOfTokenMaxBoost( _tokenId );
        uint[] memory weightsAmount = IMaLPNFT(maNFTs).getWeightByEpoch();
        uint _weight = _balance*weightsAmount[_matLevel];
        return _weight;
    }

    function maturityLevelOfTokenMaxBoost(uint _tokenId) public view returns (uint _matLevel) {
        _matLevel = (block.timestamp/WEEK) - _depositEpoch[_tokenId];
        uint _maxLevel = IMaLPNFT(maNFTs).totalMaLevels()-1;
        if (_maxLevel < _matLevel) {
            return _maxLevel;
        }
    }

    function maturityLevelOfTokenMaxArray(uint _tokenId) public view returns (uint _matLevel) {
        _matLevel = (block.timestamp/WEEK) - _depositEpoch[_tokenId];
        uint _maxMat = balancesByEpoch.length-1;
        if (_maxMat < _matLevel) {
            return _maxMat;
        }
    }

    ///@notice last time reward
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    ///@notice  reward for a single token
    function rewardPerToken() public view returns (uint256) {
        if (totalWeight() == 0) {
            return rewardPerTokenStored;
        } else {
            return rewardPerTokenStored.add(lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(totalWeight()));
        }
    }

    ///@notice see earned rewards for user
    function earned(uint _tokenId) public view returns (uint256) {
        return weightOfToken(_tokenId).mul(rewardPerToken().sub(userRewardPerTokenPaid[_tokenId])).div(1e18).add(rewards[_tokenId]);
    }

    ///@notice get total reward for the duration
    function rewardForDuration() external view returns (uint256) {
        return rewardRate.mul(DURATION);
    }


    ///@notice deposit all TOKEN of msg.sender
    function depositAll() external returns(uint _tokenId) {
        _tokenId = _deposit(TOKEN.balanceOf(msg.sender), msg.sender);
    }

    ///@notice deposit amount TOKEN
    function deposit(uint256 amount) external returns(uint _tokenId) {
        _tokenId = _deposit(amount, msg.sender);
    }

    ///@notice deposit internal
    function _deposit(uint256 amount, address account) internal nonReentrant returns(uint _tokenId) {
        require(amount > 0, "deposit(Gauge): cannot stake 0");

        _tokenId = IMaLPNFT(maNFTs).mint(account);
        updateReward(_tokenId);

        _balances[_tokenId] = _balances[_tokenId].add(amount);
        _depositEpoch[_tokenId] = (block.timestamp/WEEK);

        balancesByEpoch[0] = balancesByEpoch[0] + amount;
        
        _totalSupply = _totalSupply.add(amount);

        TOKEN.safeTransferFrom(account, address(this), amount);

        emit Deposit(account, _tokenId, amount);
    }

    ///@notice withdraw all token
    /*function withdrawAll() external {
        _withdraw(_balances[msg.sender]);
    }*/

    ///@notice withdraw a certain amount of TOKEN
    function withdraw(uint256 _tokenId) external {
        _withdraw(_tokenId);
    }

    ///@notice withdraw internal
    function _withdraw(uint256 _tokenId) internal nonReentrant {
        require(IMaLPNFT(maNFTs).isApprovedOrOwner(msg.sender,_tokenId));
        require(IMaLPNFT(maNFTs).fromThisGauge(_tokenId));

        updateReward(_tokenId);
        uint amount = _balances[_tokenId];
        require(_tokenId > 0, "token Must Exist");
        require(amount > 0, "token Must Exist");
        require(_totalSupply.sub(amount) >= 0, "supply < 0");


        _totalSupply = _totalSupply.sub(amount);
        uint level = maturityLevelOfTokenMaxArray(_tokenId);
        balancesByEpoch[level] = balancesByEpoch[level] - amount;
        
        _balances[_tokenId] = _balances[_tokenId].sub(amount);

        IMaLPNFT(maNFTs).burn(_tokenId);

        TOKEN.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, _tokenId, amount);
    }


    ///@notice withdraw TOKEN and harvest rewardToken
    function withdrawAndHarvest(uint _tokenId) external {
        getReward(_tokenId);
        _withdraw(_balances[_tokenId]);
    }

 
    ///@notice User harvest function
    function getReward(uint _tokenId) public nonReentrant {
        require(IMaLPNFT(maNFTs).isApprovedOrOwner(msg.sender,_tokenId));
        require(IMaLPNFT(maNFTs).fromThisGauge(_tokenId));
        updateReward(_tokenId);
        uint256 reward = rewards[_tokenId];
        if (reward > 0) {
            rewards[_tokenId] = 0;
            rewardToken.safeTransfer(msg.sender, reward);
            emit Harvest(msg.sender, _tokenId, reward);
        }


    }

    function _periodFinish() external view returns (uint256) {
        return periodFinish;
    }

    /// @dev Receive rewards from distribution
    function notifyRewardAmount(address token, uint reward) external nonReentrant onlyDistribution {
        updateReward(0);
        require(token == address(rewardToken));
        rewardToken.safeTransferFrom(DISTRIBUTION, address(this), reward);

        if (block.timestamp >= periodFinish) {
            rewardRate = reward.div(DURATION);
        } else {
            uint256 remaining = periodFinish.sub(block.timestamp);
            uint256 leftover = remaining.mul(rewardRate);
            rewardRate = reward.add(leftover).div(DURATION);
        }

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = rewardToken.balanceOf(address(this));
        require(rewardRate <= balance.div(DURATION), "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(DURATION);
        emit RewardAdded(reward);
    }

    function claimFees() external nonReentrant returns (uint claimed0, uint claimed1) {
        return _claimFees();
    }

    function _claimFees() internal returns (uint claimed0, uint claimed1) {
        if (!isForPair) {
            return (0, 0);
        }
        address _token = address(TOKEN);

        (claimed0, claimed1) = IPair(_token).claimFees();

        if (claimed0 > 0 || claimed1 > 0) {
            uint _fees0 = fees0 + claimed0;
            uint _fees1 = fees1 + claimed1;
            (address _token0, address _token1) = IPair(_token).tokens();

            if (_fees0  > 0) {
                fees0 = 0;
                IERC20(_token0).approve(internal_bribe, _fees0);
                IBribe(internal_bribe).notifyRewardAmount(_token0, _fees0);
            } else {
                fees0 = _fees0;
            }


            if (_fees1  > 0) {
                fees1 = 0;
                IERC20(_token1).approve(internal_bribe, _fees1);
                IBribe(internal_bribe).notifyRewardAmount(_token1, _fees1);
            } else {
                fees1 = _fees1;
            }


            emit ClaimFees(msg.sender, claimed0, claimed1);
        }
    }



}
