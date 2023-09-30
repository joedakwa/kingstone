// pragma solidity ^0.8.4;


// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "forge-std/Test.sol";
// import "../src/VaultSales.sol";

// contract VaultSalesTest is Test {
//     TheVaultSales public vaultSales;
//     address payable public feeAccount;
//     uint public feePercent;
//     bool public paused;
//     address public sellerAddress; // Declare it as a state variable

//     MyERC721 public nft;

//     // Define the Item struct here
//     struct Item {
//         address nft;
//         uint tokenId;
//         uint price;
//         address seller;
//         bool unlisted;
//         bool defaultPayment;
//     }

//     Item public item;  // Declare a public variable of type Item


// function setUp() public {
//     nft = new MyERC721();
//     uint256 tokenId = 1; // Specify the desired token ID
//     nft.mint(sellerAddress, tokenId);
//     vaultSales = new TheVaultSales(25, payable(0x000));
//     feeAccount = payable(0x000);    
//     feePercent = 25;
//     paused = false;
//     address sellerAddress = address(0x123456789); // Replace with a real address

//     sellerAddress = msg.sender;


//         // Initialize the item with mock data
//         item = Item({
//             nft: address(this),
//             tokenId: 1,
//             price: 100,
//             seller: sellerAddress,
//             unlisted: false,
//             defaultPayment: true
//         });

// }

// function testListItem() public {
//     sellerAddress = address(0x123456789); // Replace with a real address
    

//     // Create a new Item struct in memory using the VaultSales contract
//     TheVaultSales.Item memory newItem = TheVaultSales.Item({
//         nft: address(this),
//         tokenId: 1,
//         price: 100,
//         seller: sellerAddress,
//         unlisted: false,
//         defaultPayment: true
//     });

//     // Call listItem with the new Item struct
//     vaultSales.listItem(newItem);

//     // Check if the contract is paused
//     bool isContractPaused = vaultSales.paused();
//     assertTrue(isContractPaused, "Contract should be paused");
// }




// }

// pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "forge-std/Test.sol";
// import "../src/VaultSales.sol";

// contract VaultSalesTest is Test {
//     TheVaultSales public vaultSales;
//     address payable public feeAccount;
//     uint public feePercent;
//     bool public paused;
//     address public sellerAddress; // Declare it as a state variable

//     //MyERC721 public nft;

//     // Define the Item struct here
//     struct Item {
//         address nft;
//         uint tokenId;
//         uint price;
//         address seller;
//         bool unlisted;
//         bool defaultPayment;
//     }

//     Item public item;  // Declare a public variable of type Item

//     function setUp() public {
//         // Deploy the ERC721 contract and mint an NFT to the seller address
//         //nft = new MyERC721();
//         uint256 tokenId = 1; // Specify the desired token ID
//         //nft.mint(address(this), tokenId); // Mint NFT to the test contract itself
//         vaultSales = new TheVaultSales(25, payable(0x000));
//         feeAccount = payable(0x000);    
//         feePercent = 25;
//         paused = false;
//         sellerAddress = msg.sender; // Set sellerAddress to the sender's address

//         // Initialize the item with mock data
//         item = Item({
//             nft: address(nft), // Use the ERC721 contract's address
//             tokenId: tokenId, // Set the same token ID as minted
//             price: 100,
//             seller: sellerAddress, // Set the seller to your desired address
//             unlisted: false,
//             defaultPayment: true
//         });
//     }

//     function testListItem() public {
//         // Create a new Item struct in memory using the VaultSales contract
//         TheVaultSales.Item memory newItem = TheVaultSales.Item({
//             nft: address(nft),
//             tokenId: 1,
//             price: 100,
//             seller: sellerAddress,
//             unlisted: false,
//             defaultPayment: true
//         });

//         // Call listItem with the new Item struct
//         vaultSales.listItem(newItem);

//         // Check if the contract is paused
//         bool isContractPaused = vaultSales.paused();
//         assertTrue(isContractPaused, "Contract should be paused");
//     }
// }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/VaultSales.sol";

// Mock ERC721 contract for testing
contract MockERC721 {

    mapping(uint256 => address) private tokenOwners;
    mapping(address => mapping(address => bool)) private operators;

    function mint (address to, uint256 tokenId) public {
        tokenOwners[tokenId] = to;
    }

    function setApprovalForAll(address operator, bool approved) public {
        operators[msg.sender][operator] = approved;
    }
    function ownerOf(uint256 tokenId) public view returns (address) {
        return tokenOwners[tokenId]; 
        //return address(); // Mock owner address
    }

    function isApprovedForAll(address owner, address operator) public pure returns (bool) {
        return true; // Mock approval for all
    }
}

contract VaultSalesTest is Test {
    TheVaultSales public vaultSales;
    address payable public feeAccount;
    uint public feePercent;
    bool public paused;
    address public sellerAddress; // Declare it as a state variable

    MockERC721 public nft; // Use the mock ERC721 contract for testing

    // Define the Item struct here
    struct Item {
        address nft;
        uint tokenId;
        uint price;
        address seller;
        bool unlisted;
        bool defaultPayment;
    }

    Item public item;  // Declare a public variable of type Item

    function setUp() public {
        nft = new MockERC721(); // Deploy the mock ERC721 contract
        uint256 tokenId = 1; // Specify the desired token ID

        nft.mint(address(this), tokenId); // Mint NFT to the test contract itself

        vaultSales = new TheVaultSales(25, payable(0x000));
        feeAccount = payable(0x000);    
        feePercent = 25;
        paused = false;
        sellerAddress = msg.sender; // Set sellerAddress to the sender's address

        // Initialize the item with mock data
        item = Item({
            nft: address(nft), // Use the mock ERC721 contract's address
            tokenId: tokenId,
            price: 100,
            seller: sellerAddress,
            unlisted: false,
            defaultPayment: true
        });
    }

    function testListItem() public {
        // Create a new Item struct in memory using the VaultSales contract
        TheVaultSales.Item memory newItem = TheVaultSales.Item({
            nft: address(nft), // Use the mock ERC721 contract's address
            tokenId: 1,
            price: 100,
            seller: sellerAddress,
            unlisted: false,
            defaultPayment: true
        });

        // Call listItem with the new Item struct
        vaultSales.listItem(newItem);

        // Check if the contract is paused
        bool isContractPaused = vaultSales.paused();
        assertTrue(isContractPaused, "Contract should be paused");
    }
}
