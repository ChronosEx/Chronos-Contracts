// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title The Lost Keys Of Chronos contract
 * @dev Extends ERC721 Non-Fungible Token Standard basic implementation
 */
contract ChrNFT is ERC721Enumerable, Ownable {

    // Base URI
    string private _baseURIextended;
    uint256 public MAX_SUPPLY;
    uint256 public NFT_PRICE;
    uint256 public NFT_PRICE_WL;
    uint256 public MAX_ROUND2 = 10;
    uint256 public MAX_PER_USER = 20;
    uint256 public SALE_START_TIMESTAMP;
    uint256 public MAX_RESERVE = 200;
    uint256 public MAX_PRIVATE = 1666;
    uint256 public reservedAmount;
    uint256 public privateAmount;
    address public multiSig = 0x0000000000000000000000000000000000000000;   // To Do
    address public privateVesting;   // To Do

    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public firstMint;
    mapping(address => uint256) public secondMint;
    mapping(address => uint256) public originalMinters;

    constructor(
        uint256 _maxSupply, // 5555
        uint256 _nftPriceWL,  // 0.20 eth
        uint256 _nftPrice,  // 0.23 eth
        uint256 _startTimestamp
    ) ERC721("The Lost Keys Of Chronos", "chrNFT") {
        require(multiSig != address(0));
        MAX_SUPPLY = _maxSupply;
        NFT_PRICE = _nftPrice;
        NFT_PRICE_WL = _nftPriceWL;
        SALE_START_TIMESTAMP = _startTimestamp;
    }

    function withdraw() external onlyOwner {
        (bool withdrawMultiSig, ) = multiSig.call{value: address(this).balance}("");
        require(withdrawMultiSig, "Withdraw Failed.");
    }

    function setWhitelist( address[] memory _users ) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            isWhitelisted[_users[i]] = true;
        }
    }

    function removeWhitelist( address[] memory _users ) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            isWhitelisted[_users[i]] = true;
        }
    }

    function setNftPrice(uint256 _nftPrice) external onlyOwner {
        NFT_PRICE = _nftPrice;
    }
    function setNftPriceWL(uint256 _nftPriceWL) external onlyOwner {
        NFT_PRICE_WL = _nftPriceWL;
    }

    function setPrivateVesting (address _privateVesting) external onlyOwner {
        privateVesting = _privateVesting;
    }
    /**
     * Mint NFTs by owner to team
     */
    function reserveNFTs(address _to, uint256 _amount) external onlyOwner {
        require(_to != address(0), "Invalid address.");
        require(reservedAmount + _amount <= MAX_RESERVE, "Invalid amount.");

        for (uint256 i = 0; i < _amount; i++) {
            if (totalSupply() < MAX_SUPPLY) {
                _safeMint(_to, totalSupply());
            }
        }
        originalMinters[_to] = originalMinters[_to] + _amount;
        reservedAmount = reservedAmount + _amount;
    }

    /**
     * Mint NFTs by owner to private investors. To be held by a vesting contract.
     */
    function phase0Mint(address _for, uint256 _amount) external onlyOwner {
        address _to = privateVesting;
        require(_to != address(0), "Invalid address to vesting contract.");
        require(privateAmount + _amount <= MAX_PRIVATE, "Invalid amount.");

        for (uint256 i = 0; i < _amount; i++) {
            if (totalSupply() < MAX_SUPPLY) {
                _safeMint(_to, totalSupply());
            }
        }
        originalMinters[_for] = originalMinters[_for] + _amount;
        privateAmount = privateAmount + _amount;
    }
    /**
     * @dev Return the base URI
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    /**
     * @dev Return the base URI
     */
    function baseURI() external view returns (string memory) {
        return _baseURI();
    }

    /**
     * @dev Set the base URI
     */
    function setBaseURI(string memory baseURI_) external onlyOwner {
        _baseURIextended = baseURI_;
    }

    /**
     * Get the array of token for owner.
     */
    function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            for (uint256 index; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

        
    function currentRound() public view returns( uint256 ) {
        if ( block.timestamp < SALE_START_TIMESTAMP ) return 0;   // not started
        if ( block.timestamp < SALE_START_TIMESTAMP + 1 days ) return 1;   // phase 1 WL 1
        if ( block.timestamp < SALE_START_TIMESTAMP + 2 days ) return 2;   // phase 2 WL 10
        if ( block.timestamp < SALE_START_TIMESTAMP + 5 days ) return 3;   // phase 3 Public
        return 4;   // minting finished
    }

    function mint(uint256 amount) public payable {
        uint round = currentRound();
        uint price;
        require(round != 0, "Sale has not started yet.");
        require(round != 4, "Sale has ended.");

        if (round == 1) {
            //  First Round: Whitelist, 1 mint max, Whitelist price
            require(isWhitelisted[msg.sender], "Not whitelisted.");
            require(originalMinters[msg.sender] == 0, "Can only mint 1 in the first round");
            require(!firstMint[msg.sender], "Already minted!");

            firstMint[msg.sender] = true;
            amount = 1;
            price = NFT_PRICE_WL;
        } else if (round == 2) {
            //  Second Round: Whitelist, 10 mint max, Whitelist price
            require(isWhitelisted[msg.sender], "Not whitelisted.");
            require(secondMint[msg.sender] + amount <= MAX_ROUND2, "Can only mint 10 in the second round");

            secondMint[msg.sender] = secondMint[msg.sender] + amount;
            price = NFT_PRICE_WL;
        } else {
            //  Third Round: Public, 20 mint max, public price
            require(balanceOf(msg.sender) + amount <= MAX_PER_USER, "Can only mint 20 NFTs per wallet");

            price = NFT_PRICE;
        }

        require(price * amount == msg.value, "ETH value sent is not correct");

        originalMinters[msg.sender] = originalMinters[msg.sender] + amount;
        _mintTo(msg.sender, amount);
    }

    function _mintTo(address account, uint amount) internal {
        require(totalSupply() + amount <= MAX_SUPPLY, "Mint would exceed max supply.");

        for (uint256 i = 0; i < amount; i++) {
            if (totalSupply() < MAX_SUPPLY) {
                _safeMint(account, totalSupply());
            }
        }
    }

    function maxMint(address user) public view returns (uint max){
        uint round = currentRound();

        if ( round == 0 || round == 4 ) return 0;

        if ( round == 1 ) {
            if (isWhitelisted[user]) {
                if (firstMint[user]) return 0;
                return 1;
            }
            return 0;
        }

        if ( round == 2 ) {
            if (isWhitelisted[user]) return MAX_ROUND2 - secondMint[user];
            return 0;
        }

        return MAX_PER_USER-balanceOf(user); 

    }

    function nextRound() public view returns( uint256 ) {
        if ( block.timestamp < SALE_START_TIMESTAMP ) return SALE_START_TIMESTAMP;   // not started
        if ( block.timestamp < SALE_START_TIMESTAMP + 1 days ) return SALE_START_TIMESTAMP + 1 days;   // phase 1 WL 1
        if ( block.timestamp < SALE_START_TIMESTAMP + 2 days ) return SALE_START_TIMESTAMP + 2 days;   // phase 2 WL 10
        if ( block.timestamp < SALE_START_TIMESTAMP + 5 days ) return SALE_START_TIMESTAMP + 5 days;   // phase 3 Public
        return 0;   // minting finished
    }
}