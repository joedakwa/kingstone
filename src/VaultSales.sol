// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/Address.sol";

import "@openzeppelin/contracts/access/Ownable2Step.sol";

// import "hardhat/console.sol";


contract TheVaultSales is ReentrancyGuard, Ownable2Step  {

    using Address for address payable;

    error ItemDoesNotExist(address nft, uint256 id);
    error ItemAlreadyListed(address nft, uint256 id);
    error NotNftOwner(address nft, uint256 id);
    error PriceCannotBeZero(address nft, uint256 id);
    error NftNotApproved(address nft, uint256 id);
    error InsufficientFunds(uint256 sent, uint256 price);
    error FeeOutOfRange(uint256 fee);
    error ItemTooLarge(uint256 itemLength);
    error ContractIsPaused();
    error ContractCurrentState(bool paused);

    // Variables
    address payable public feeAccount; // the account that receives fees
    uint public feePercent; // the fee percentage on sales 25 // 2.5%
    bool public paused = false;
    // @audit explicitly define uint as uint256
    struct Item {
        address nft;
        uint tokenId;
        uint price;
        address seller;
        bool unlisted;
    }

    // constract -> tokenId -> Item
    mapping(address => mapping(uint => Item)) public Items;

    event Offered(
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller
    );

    event Unlist(
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller
    );

    event Bought(
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );

    constructor(uint _feePercent, address account) {
        feeAccount = payable(account);

        feePercent = _feePercent;
    }



    // Make item to offer on the marketplace
    // @audit Has nonreentrant modifier to prevent reentrancy attacks, but not on the isApprovedForAll call
    // @audit Doesnt check if item is already listed
    function listItem(Item calldata _item) external nonReentrant {
        if(paused) revert ContractIsPaused(); 

        require(_item.price > 0);
        if(_item.price == 0) revert PriceCannotBeZero(_item.nft, _item.tokenId); 
        IERC721 _nft = IERC721(_item.nft);

        //require sender is owner of NFT
        if(_nft.ownerOf(_item.tokenId) != msg.sender) revert NotNftOwner(_item.nft, _item.tokenId); 

        //require NFT has not been previosly listed
        Item storage item = Items[_item.nft][_item.tokenId];
        if(item.seller != address(0)) revert ItemAlreadyListed(_item.nft, _item.tokenId); 



        //require contract is approved to spend NFT
        if(!_nft.isApprovedForAll(msg.sender, address(this))) revert NftNotApproved(_item.nft, _item.tokenId); 

        
        // add new item to items mapping
        Items[_item.nft][_item.tokenId] = _item;
        
        // emit Offered event
        emit Offered(
            address(_nft),
            _item.tokenId,
            _item.price,
            msg.sender
        );
    }
    // @audit BNB is suscetible to being paused at Admin level.
    // @audit function is payable, but contract doesnt have a way to withdraw funds, so ETH is stuck
    // @audit-issue use of memory and storage is not clear
    function purchaseItem(Item[] memory _item) external payable nonReentrant {
        if(paused) revert ContractIsPaused(); 

        if(_item.length > 30) revert ItemTooLarge(_item.length); 

        uint _totalPrice;
        // @audit For loop could exceed gas limit?
        for (uint256 i = 0; i < _item.length;) {
            Item storage item = Items[_item[i].nft][_item[i].tokenId];
            if(item.unlisted) revert ItemDoesNotExist(_item[i].nft, _item[i].tokenId); 

            
            _totalPrice += item.price;
            unchecked {
                i++;
            }
        }

        if(msg.value < _totalPrice) revert InsufficientFunds(msg.value, _totalPrice); 

        
        uint256 _fee = feePercent;
        //send Fee to Markeplace owner
        feeAccount.sendValue(_totalPrice * _fee / 1000);
        // @audit For loop could exceed gas limit?
        // @audit what happens if this reverts? then the fee has already been paid to the marketplace.
        for (uint256 i = 0; i < _item.length;) {
            Item storage item = Items[_item[i].nft][_item[i].tokenId];
            if(item.unlisted) revert ItemDoesNotExist(_item[i].nft, _item[i].tokenId); 

            //send saleFee
            //@audit does this cause overflow or underflow?
            // @audit if using BNB, it (transfer) will not return a bool on erc20 methods. Missing return value.
            // https://twitter.com/Uniswap/status/1072286773554876416

            uint id = _item[i].tokenId;
            uint price = _item[i].price;
            address seller = _item[i].seller;
            IERC721 _nft = IERC721(item.nft);

            //send token
            _nft.safeTransferFrom(seller, msg.sender, id, bytes(""));

            //send payment to seller
            payable(item.seller).sendValue(_item[i].price * (1000-feePercent) / 1000);

            //delete listing
            delete Items[_item[i].nft][_item[i].tokenId];

            // @audit-issue if transferFrom fails, the NFT is lost, due to the mapping being deleted.
            // which means the buyer wont receive the NFT, but the seller will still receive the funds. In this
            // case use safeTransferFrom, which will revert if the transfer fails.
            // @audit no check to see if seller owns the NFT
            // emit Bought event
            emit Bought(
            address(_item[i].nft),
            id,
            price,
            seller,
            msg.sender
            );

            unchecked {
                i++;
            }
        }
    }
    // @audit Has nonreentrant modifier to prevent reentrancy attacks, but does this work?
    //@audit doesnt check if item has been sold
    function unListItem(Item memory _item) external nonReentrant {
        if(paused) revert ContractIsPaused(); 

        Item storage item = Items[_item.nft][_item.tokenId];
        if(item.unlisted) revert ItemDoesNotExist(_item.nft, _item.tokenId); 

        if(item.seller != msg.sender) revert NotNftOwner(_item.nft, _item.tokenId); 

        item.unlisted = true;


        // delete listing
        // @audit-issue does this really get deleted?
        delete Items[_item.nft][_item.tokenId];
       
        // emit Unlist event
        emit Unlist(
            address(item.nft),
            item.tokenId,
            item.price,
            msg.sender
        );
    }
    // @audit take care here. Centralisation risks
    //change Owner

    //change fee 25 -> 2.5%
    function changeFee (uint256 _newFee) public onlyOwner {
        if(_newFee == 0 || _newFee == 1000) revert FeeOutOfRange(_newFee); 
        feePercent = _newFee;
        //@audit do not allow fee to be set to 0 or 100%.
    }


    function withdrawFees() public onlyOwner  {
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available for withdrawal");
        payable(msg.sender).transfer(balance);
    }

    function pauseContract(bool _state) public onlyOwner {
        if(paused == _state) revert ContractCurrentState(paused);
        paused = _state;
    }
}