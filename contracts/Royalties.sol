// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IWETH.sol";


interface IChrNFT {
    function originalMinters(address) external view returns(uint);
    function totalSupply() external view returns(uint);
}

contract Royalties is ReentrancyGuard {

    using SafeERC20 for IERC20;

    IERC20 public weth;


    uint256 public epoch;

    IChrNFT public chrnft;
    address public owner;

    mapping(uint => uint) public feesPerEpoch;
    mapping(uint => uint) public totalSupply;
    mapping(address => bool) public depositors;
    mapping(address => uint) public userCheckpoint;

    modifier onlyOwner {
        require(msg.sender == owner, 'not owner');
        _;
    }

    modifier allowed {
        require(depositors[msg.sender] == true || msg.sender == owner, 'not allowed');
        _;
    }

    event Deposit(uint256 amount);
    event VestingUpdate(uint256 balance, uint256 vesting_period, uint256 tokenPerSec);

    constructor(address _weth, address _chrnft) {
        owner = msg.sender;
        weth = IERC20(_weth);
        chrnft = IChrNFT(_chrnft);
        epoch = 0;
    }


    function deposit(uint256 amount) external payable allowed {

        require(amount > 0 || msg.value > 0);
        uint256 _amount = 0;
        if(msg.value == 0){
            weth.safeTransferFrom(msg.sender, address(this), amount);
            _amount = amount;
        } else {
            IWETH(address(weth)).deposit{value: address(this).balance}();
            _amount = msg.value;
        }

        feesPerEpoch[epoch] = _amount;
        totalSupply[epoch] = chrnft.totalSupply();
        epoch++;
    }

    function withdrawERC20(address _token) external onlyOwner {
        require(_token != address(0));
        uint256 _balance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransfer(msg.sender, _balance);
    }


    function claim(address to) external nonReentrant {
        require(to != address(0));
        
        // get amount
        uint256 _toClaim = claimable(msg.sender);
        require(_toClaim <= weth.balanceOf(address(this)), 'too many rewards');
        require(_toClaim > 0, 'wait next');
        
        // update checkpoint
        userCheckpoint[msg.sender] = epoch;

        // send and enjoy
        weth.safeTransfer(to, _toClaim);
    }   



    function claimable(address user) public view returns(uint) {
        require(user != address(0));

        uint256 cp = userCheckpoint[user];
        if(cp >= epoch){
            return 0;
        }

        uint i;
        uint256 _reward = 0;
        uint256 weight = chrnft.originalMinters(user);
        for(i = cp; i < epoch; i++){
            uint256 _tot = totalSupply[i];
            uint256 _fee = feesPerEpoch[i];
            _reward += _fee * weight / _tot;
        }  
        return _reward;
    }
    
    /* 
        OWNER FUNCTIONS
    */

    function setDepositor(address depositor) external onlyOwner {
        require(depositors[depositor] == false);
        depositors[depositor] = true;
    }

    function removeDepositor(address depositor) external onlyOwner {
        require(depositors[depositor] == true);
        depositors[depositor] = false;
    }

    function setOwner(address _owner) external onlyOwner{
        require(_owner != address(0));
        owner = _owner;
    }
    

    receive() external payable {}

}