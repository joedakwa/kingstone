// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract TheVaultSales is ReentrancyGuard {

    // Variables
    address payable public feeAccount; // the account that receives fees
    uint public feePercent; // the fee percentage on sales 25 // 2.5%

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
    // 
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

    function purchaseItem(Item[] memory _item) external payable nonReentrant {
        uint _totalPrice;
        for (uint256 i = 0; i < _item.length; i++) {
            Item storage item = Items[_item[i].nft][_item[i].tokenId];
            require(item.seller != address(0), "item doesn't exist");
            _totalPrice += item.price;
        }

        require(msg.value >= _totalPrice, "Insufficient funds");
        //send Fee to Markeplace owner
        feeAccount.transfer(_totalPrice * feePercent / 1000);

        for (uint256 i = 0; i < _item.length; i++) {
            Item storage item = Items[_item[i].nft][_item[i].tokenId];
            //send saleFee
            payable(item.seller).transfer(_item[i].price * (1000-feePercent) / 1000);
            uint id = _item[i].tokenId;
            uint price = _item[i].price;
            address seller = _item[i].seller;
            IERC721 _nft = IERC721(item.nft);
            //delete listing
            delete Items[_item[i].nft][_item[i].tokenId];
            //send token
            _nft.transferFrom(seller, msg.sender, id);

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
    
    //change Owner
    function changeOwner (address _newOwner) public {
        require(msg.sender == owner, "Not Owner");
        owner = _newOwner;
    }

    //change fee 25 -> 2.5%
    function changeFee (uint _newFee) public {
        require(msg.sender == owner, "Not Owner");
        feePercent = _newFee;
    }
}