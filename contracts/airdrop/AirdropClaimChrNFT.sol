// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "../interfaces/IVotingEscrow.sol";
import "../interfaces/IChrNFT.sol";

contract AirdropClaimChrNFT is ReentrancyGuard {

    using SafeERC20 for IERC20;

    bool public init;

    uint256 public VE_SHARE;
    uint256 constant public PRECISION = 1000;

    uint256 public tokenPerSec; 
    uint256 public LOCK_PERIOD;
    uint256 public VESTING_PERIOD;
    uint256 public totalAirdrop;
    uint256 public START_VESTING;

    
    address public owner;
    address public ve;
    address public chrNFT;
    IERC20 public token;
    
    mapping(address => bool) public depositors;
    mapping(address => uint) public claimedVeCHR;
    mapping(address => uint) public claimedCHR;

    modifier onlyOwner {
        require(msg.sender == owner, 'not owner');
        _;
    }
    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);

    event ClaimVeCHR(address who, uint amount, uint tokenIdInto, uint wen);
    event ClaimCHR(address who, uint amount, uint wen);

    constructor(address _token, address _ve, address _chrNFT, uint _startVesting) {
        owner = msg.sender;
        token = IERC20(_token);
        chrNFT = _chrNFT;
        ve = _ve;
        VESTING_PERIOD = 30 * 2 * 86400;
        START_VESTING = _startVesting; //WHEN epoch 0 starts ?
        LOCK_PERIOD = 2 * 364 * 86400;
        VE_SHARE = 500;

    }


    function deposit(uint256 amount) external {
        require(depositors[msg.sender] == true || msg.sender == owner);
        token.safeTransferFrom(msg.sender, address(this), amount);
        totalAirdrop += amount;
        
        emit Deposit(amount);
    }

    function withdraw(uint256 amount, address _token, address _to) external {
        require(depositors[msg.sender] == true || msg.sender == owner);
        IERC20(_token).safeTransfer(_to, amount);
        totalAirdrop -= amount;

        emit Withdraw(amount);
    }

    struct UserInfo{
        uint256 totalMinted;
        uint256 veCHRTotal;
        uint256 veCHRClaimed;
        uint256 veCHRLeft;
        uint256 veCHRClaimable;
        uint256 CHRTotal;
        uint256 CHRClaimed;
        uint256 CHRLeft;
        uint256 CHRClaimable;
        address to;
        uint startVesting;
        uint finishVesting;
    }

    
    function claimable(address _who) public view returns(UserInfo memory userInfo) {
        require(_who != address(0));
        userInfo.to = _who;

        uint _ogMints = IChrNFT(chrNFT).originalMinters(_who);
        userInfo.totalMinted =_ogMints;

        uint _totalSupply = IChrNFT(chrNFT).totalSupply();
        uint _amountPerNFT = totalAirdrop/_totalSupply;
        uint _amount = _ogMints * _amountPerNFT;


        uint _veShare = (VE_SHARE * _amount) / PRECISION;
        userInfo.veCHRTotal = _veShare;
        userInfo.veCHRClaimed = claimedVeCHR[_who];
        userInfo.veCHRLeft = _veShare - userInfo.veCHRClaimed;
        userInfo.veCHRClaimable = userInfo.veCHRLeft;
        
        uint _totalCHR = _amount - _veShare;
        uint _totalCHRLeft = _totalCHR - claimedCHR[_who];

        userInfo.CHRTotal = _totalCHR;
        userInfo.CHRClaimed = claimedCHR[_who];
        userInfo.CHRLeft = _totalCHRLeft;

        if( block.timestamp > START_VESTING ) {
            uint timeElapsedSinceStart = block.timestamp - START_VESTING;
            uint claimablePercent = (timeElapsedSinceStart*PRECISION)/VESTING_PERIOD;
            
            userInfo.CHRClaimable = _totalCHR*claimablePercent/PRECISION - claimedCHR[_who];
        } else {
            userInfo.CHRClaimable = 0;
        }

        userInfo.startVesting = START_VESTING;
        userInfo.finishVesting = START_VESTING + VESTING_PERIOD;
    }
    
    /// @notice claim the given amount and send to _to. Checks are done by merkle tree contract. (eg.: 40% veCHR 60% $CHR)
    function claim() external nonReentrant returns(bool claimed){

        UserInfo memory _userInfo = claimable(msg.sender);

        uint _amountOut = _userInfo.CHRClaimable + _userInfo.veCHRClaimable;
        require(token.balanceOf(address(this)) >= _amountOut, 'not enough token');

        claimed = false;
        uint _amount;
        if ( _userInfo.veCHRClaimable > 0 ) {
            _amount = _userInfo.veCHRClaimable;
            token.approve(ve, 0);
            token.approve(ve, _amount);
            uint256 _tokenId = IVotingEscrow(ve).create_lock_for(_amount, LOCK_PERIOD, msg.sender);
            require(_tokenId != 0);
            require(IVotingEscrow(ve).ownerOf(_tokenId) == msg.sender, 'wrong ve mint'); 

            claimedVeCHR[msg.sender] = claimedVeCHR[msg.sender] + _amount;
            claimed = true;
            emit ClaimVeCHR(msg.sender, _amount, _tokenId, block.timestamp);

        }

        if ( _userInfo.CHRClaimable > 0 ) {
            claimed = true;
            _amount = _userInfo.CHRClaimable;

            token.safeTransfer(msg.sender, _amount);
            claimedCHR[msg.sender] = claimedCHR[msg.sender] +_amount;

            emit ClaimCHR(msg.sender, _amount, block.timestamp);


        }
        return claimed;
    }


    /* 
        OWNER FUNCTIONS
    */

    function setDepositor(address depositor) external onlyOwner {
        require(depositors[depositor] == false);
        depositors[depositor] = true;
    }

    function setOwner(address _owner) external onlyOwner{
        require(_owner != address(0));
        owner = _owner;
    }

    /// @notice set the % amount claimable early. The remaining is vested linearly
    function setVeShare(uint _share) external onlyOwner{
        require(_share <= PRECISION);
        VE_SHARE = _share;
    }

    
}