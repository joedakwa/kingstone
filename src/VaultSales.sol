// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

// @audit no safeMath library is used

contract TheVaultSales is ReentrancyGuard {

    // Variables
    address payable public feeAccount; // the account that receives fees
    uint public feePercent; // the fee percentage on sales 25 // 2.5%
// @audit explicitly define uint as uint256
    struct Item {
        address nft;
        uint tokenId;
        uint price;
        address seller;
    }

    // constract -> tokenId -> Item
    mapping(address => mapping(uint => Item)) public Items;

    //owner
    address owner;

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
        owner = msg.sender;
    }

    // Make item to offer on the marketplace
    // @audit Has nonreentrant modifier to prevent reentrancy attacks, but not on the isApprovedForAll call
    // @audit Doesnt check if item is already listed
    function listItem(Item memory _item) external nonReentrant {
        require(_item.price > 0, "Price must be greater than zero");
        IERC721 _nft = IERC721(_item.nft);
        //require contract is approved to spend NFT
        require(_nft.isApprovedForAll(msg.sender, address(this)), "NFT not approved");     
        
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
    function purchaseItem(Item[] memory _item) external payable nonReentrant {
        uint _totalPrice;
        // @audit For loop could exceed gas limit?
        for (uint256 i = 0; i < _item.length; i++) {
            Item storage item = Items[_item[i].nft][_item[i].tokenId];
            require(item.seller != address(0), "item doesn't exist");
            _totalPrice += item.price;
        }

        require(msg.value >= _totalPrice, "Insufficient funds");
        //send Fee to Markeplace owner
        feeAccount.transfer(_totalPrice * feePercent / 1000);
// @audit For loop could exceed gas limit?
// @audit what happens if this reverts? then the fee has already been paid to the marketplace.
        for (uint256 i = 0; i < _item.length; i++) {
            Item storage item = Items[_item[i].nft][_item[i].tokenId];
            //send saleFee
            //@audit does this cause overflow or underflow?
            // @audit if using BNB, it (transfer) will not return a bool on erc20 methods. Missing return value.
            // https://twitter.com/Uniswap/status/1072286773554876416
            payable(item.seller).transfer(_item[i].price * (1000-feePercent) / 1000);
            uint id = _item[i].tokenId;
            uint price = _item[i].price;
            address seller = _item[i].seller;
            IERC721 _nft = IERC721(item.nft);
            //delete listing
            delete Items[_item[i].nft][_item[i].tokenId];
            //send token
            _nft.transferFrom(seller, msg.sender, id);
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
        }
    }
// @audit Has nonreentrant modifier to prevent reentrancy attacks, but does this work?
    function unListItem(Item memory _item) external nonReentrant {
        Item storage item = Items[_item.nft][_item.tokenId];
        require(item.seller != address(0), "item doesn't exist");
        require( item.seller == msg.sender, "Item does not belong to you");

        // delete listing
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
    function changeOwner (address _newOwner) public {
        require(msg.sender == owner, "Not Owner");
        owner = _newOwner;
        // @audit make sure _newOwner is not zero address
    }

    //change fee 25 -> 2.5%
    function changeFee (uint _newFee) public {
        require(msg.sender == owner, "Not Owner");
        feePercent = _newFee;
        //@audit do not allow fee to be set to 0 or 100%.
    }
}