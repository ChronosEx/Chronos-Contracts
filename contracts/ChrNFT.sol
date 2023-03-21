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
    uint256 public SALE_START_TIMESTAMP;
    uint256 public MAX_RESERVE = 1945;  // 30% of Max supply for private investors (0.3 eth each), 5% to team/treasury
    uint256 public reservedAmount;
    address public multiSig = 0x345E50e9B192fB77eA2c789d9b486FD425441FdD;


    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isOgUser;
    mapping(address => uint256) public firstMint;
    mapping(address => uint256) public secondMint;
    mapping(address => uint256) public thirdMint;

    mapping(address => uint256) public originalMinters;

    constructor(
        uint256 _maxSupply, // 5555
        uint256 _nftPriceWL,  // 0.325 eth
        uint256 _nftPrice,  // 0.35 eth
        uint256 _startTimestamp
    ) ERC721("The Lost Keys Of Chronos", "chrNFT") {
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

    function setOgUser( address[] memory _users ) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            isOgUser[_users[i]] = true;
        }
    }

    function removeWhitelist( address[] memory _users ) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            isWhitelisted[_users[i]] = false;
        }
    }

    function removeOgUser( address[] memory _users ) public onlyOwner {
        for (uint256 i = 0; i < _users.length; i++) {
            isOgUser[_users[i]] = false;
        }
    }

    /**
     * Mint NFTs by owner to private investors.(They paid 0.3/ NFT eth before the launch)
     */
    function reserveNFTs(address[] memory _to, uint256[] memory _amount) external onlyOwner {
        require( _to.length != 0 , "Invalid length.");
        require( _to.length == _amount.length , "Different length.");

        for (uint i=0; i < _to.length; i++) {
        
            require(_to[i] != address(0), "Invalid address.");
            require(_amount[i] != 0, "Invalid amount.");
            require(reservedAmount + _amount[i] <= MAX_RESERVE, "Invalid amount.");

            for (uint256 u = 0; u < _amount[i]; u++) {
                if (totalSupply() < MAX_SUPPLY) {
                    reservedAmount = reservedAmount + 1;
                    _mint(_to[i], reservedAmount);
                    
                }
            }
            originalMinters[_to[i]] = originalMinters[_to[i]] + _amount[i];
        }
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
        if ( block.timestamp <= SALE_START_TIMESTAMP ) return 0;   // not started
        if ( block.timestamp <= SALE_START_TIMESTAMP + 2 hours ) return 1;   // phase 1: WL 1, OG 5
        if ( block.timestamp <= SALE_START_TIMESTAMP + 4 hours ) return 2;   // phase 2: WL 2, OG 10
        if ( block.timestamp <= SALE_START_TIMESTAMP + 2 days + 4 hours ) return 3;   // phase 3 Public, max 20
        return 4;   // minting finished
    }

    function mint(uint256 amount) public payable {
        uint round = currentRound();
        uint price;
        require(round != 0, "Sale has not started yet.");
        require(round != 4, "Sale has ended.");

        uint256 maxAmount = maxMint(msg.sender);

        require(amount != 0, "You have to mint at least 1 NFT.");
        require(amount <= maxAmount, "You can't mint that much NFTs in this round.");

        if (round == 1) {
            firstMint[msg.sender] = firstMint[msg.sender] + amount;
            price = NFT_PRICE_WL;
        } else if (round == 2) {
            secondMint[msg.sender] = secondMint[msg.sender] + amount;
            price = NFT_PRICE_WL;
        } else {
            thirdMint[msg.sender] = thirdMint[msg.sender] + amount;
            price = NFT_PRICE;
        }

        require(price * amount == msg.value, "ETH value sent is not correct");

        originalMinters[msg.sender] = originalMinters[msg.sender] + amount;
        _mintTo(msg.sender, amount);
    }

    function _mintTo(address account, uint amount) internal {
        require(totalSupply()+ MAX_RESERVE + amount <= MAX_SUPPLY, "Mint would exceed max supply.");

        for (uint256 i = 0; i < amount; i++) {
            if ( totalSupply()+MAX_RESERVE+1 <= MAX_SUPPLY) {
                _safeMint(account, totalSupply()+MAX_RESERVE+1 );
            }
        }
    }

    function maxMint(address user) public view returns (uint max){
        uint round = currentRound();

        if ( round == 0 || round == 4 ) return 0;               // no mint if minting phase hasn't started/ has finished.

        if ( round == 1 ) {
            if (isOgUser[user]) return 5-firstMint[user];       // Og Users can mint 5 chrNFTs maximum on the first round.

            if (isWhitelisted[user]) return 1-firstMint[user];  // Whitelist Users can mint 1 chrNFT maximum on the first round.

            return 0;
        }

        if ( round == 2 ) {
            if (isOgUser[user]) return 10-secondMint[user];     // Og Users can mint 10 chrNFTs maximum on the second round.

            if (isWhitelisted[user]) return 2 - secondMint[user];   // Whitelist Users can mint 2 chrNFTs maximum on the second round.

            return 0;
        }

        return 20-thirdMint[user];  // everyone can mint 20 chrNFTs maximum on the third round.

    }

    /*
        Allow Trade of NFTs after Minting ends.
        We make this to avoid people enter a loop of minting and dumping to get the promised minting airdrop.
        People could mint for 0.35 and sell immediately for 0.33, and they would still get the airdrops.
    */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require( (currentRound() == 4) || (totalSupply() == MAX_SUPPLY), "Trading not allowed during Minting phase. ");
        super._transfer(from,to,tokenId);
    }

    function _approve(address to, uint256 tokenId) internal override {
        require( (currentRound() == 4) || (totalSupply() == MAX_SUPPLY), "Trading not allowed during Minting phase. ");
        super._approve(to,tokenId);
    }

    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal override {
        require( (currentRound() == 4) || (totalSupply() == MAX_SUPPLY), "Trading not allowed during Minting phase. ");
        super._setApprovalForAll(owner,operator,approved);
    }

}