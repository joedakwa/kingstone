# Introduction

A time-boxed security review of the **TheVaultSales** protocol was done by **Joe Dakwa**, with a focus on the security aspects of the application's smart contracts implementation.

# Disclaimer

A smart contract security review can never verify the complete absence of vulnerabilities. This is a time, resource and expertise bound effort where I try to find as many vulnerabilities as possible. I can not guarantee 100% security after the review or even if the review will find any problems with your smart contracts. Subsequent security reviews, bug bounty programs and on-chain monitoring are strongly recommended.

# About **Joe Dakwa**

I an independent smart contract security researcher. Having found numerous security vulnerabilities in various protocols, I does my best to contribute to the blockchain ecosystem and its protocols by putting time and effort into security research & reviews. 

# About **The Vault Sales**

The Vault Sales is a modern NFT Marketplace designed to allow individuals to freely trade their ERC721 NFTs.

## Observations

Protocol is using 2 Open Zeppelin libraries, including the reentrancy guard and the interface for ERC721 implementations.

## Privileged Roles & Actors

Deployer is owner of the contract and has the ability to change ownership and fee structure within the protocol.

# Severity classification

| Severity               | Impact: High | Impact: Medium | Impact: Low |
| ---------------------- | ------------ | -------------- | ----------- |
| **Likelihood: High**   | Critical     | High           | Medium      |
| **Likelihood: Medium** | High         | Medium         | Low         |
| **Likelihood: Low**    | Medium       | Low            | Low         |

**Impact** - the technical, economic and reputation damage of a successful attack

**Likelihood** - the chance that a particular vulnerability gets discovered and exploited

**Severity** - the overall criticality of the risk

# Security Assessment Summary

### Scope

The following smart contracts were in scope of the audit:

- `VautSales`
- `Open Zeppelin Contracts`
- `Interfaces`

---

# Findings Summary

| ID     | Title                   | Severity | Status |
| ------ | ----------------------- | -------- | ------ |
| [C-01] | BNB is stuck within the feeAccount forever | Critical | TBD    |
| [C-02] | Malicious seller can steal funds from buyer by calling unlistItem | Critical | TBD |
| [H-01] | The owner can change the fee structure at any time, resulting in losses for buyers and gains for sellers | Critical | TBD |
| [H-02] | listItem doesn't check if the seller of the NFT is the owner of the NFT, which can lead to loss of funds for buyers     | High     | TBD    |
| [H-03] | An attacker can frontrun the seller and list an NFT for a low price, and then purchase the same NFT | High | TBD |
| [H-04] | Attacker can frontrun the seller and purchase the NFT before the seller's unlistItem transaction is processed | High | TBD |
| [M-01] | Sellers can list the same NFTs consistently    | Medium   | TBD    |
| [M-02] | BNB can be paused at Admin level causing failures in transactions | Medium | TBD |
| [M-03] | Missing return values on BNB transfer | Medium | TBD |
| [M-04] | transferFrom doesnt revert the transaction upon failure | Medium | TBD |
| [M-05] | Block gas limit can be reached in purchaseItem | Medium | TBD |
| [L-01] | Locking the contract forever is possible      | Low      | TBD    |
| [L-02] | Use a two-step ownership transfer approach | Low | TBD |
| [G-01] | Use unchecked in for loops | Gas | TBD |
| [G-02] | Use calldata instead of memory | Gas | TBD |
| [G-03] | Use custom errors where possible | Gas | TBD |

# Detailed Findings

# [C-01] BNB is stuck within the feeAccount forever.

## Severity

**Impact:** High, because native tokens sent to feeAccount will never be withdrawn

**Likelihood:** High, because there is no way for it to be withdrawn currently

## Description

During function ```purchaseItem```, the payable modifier in Solidity is used to send BNB to the feeAccount.

However, there is currently no way to withdraw BNB from the feeAccount.

This means that once BNB is sent to the ```feeAccount```, it will remain there indefinitely, and there is no automated way for the contract owner to retrieve those funds.

## Recommendations

Mitigation:

In the ```feeAccount```, allow for a withdraw function. Also make sure the ```feeAccount``` has a payable receiver in order to receive the BNB.


```solidity
    function withdrawFees() public {
        require(msg.sender == owner, "Not Owner");
        uint256 balance = address(this).balance;
        require(balance > 0, "No funds available for withdrawal");
        payable(owner).transfer(balance);
    }
```

# [C-02] Malicious seller can steal funds from buyer by calling unlistItem

## Severity

**Impact:** High, because sellers can game the system at any point

**Likelihood:** High, because there is no way to stop this currently

## Description

In function ```purchaseItem```, there is a call to transfer the proceeds of the sale to the seller.

```solidity
        //send remaining BNB to seller
        payable(item.seller).transfer(_item[i].price * (1000-feePercent) / 1000);
```

However, the seller can call function ```unlistItem``` right after this, which will result in the buyer losing their funds, as
```unlistItem``` deletes the NFT from the items array.

This means that the seller has just received proceeds before the item has even been transferred to the buyer.

The buyer will not receive the NFT, because unlistItem deletes the item from the items array.


## Recommendations

Add a check to see if the item is still in the items array before transferring funds to the seller.

I would recommend to change the sequence management and synchronization of the function flow between
```purchaseItem```and ```unlistItem```. Allow for the automatic delisting of the NFT only after transferFrom has been successfully executed and the buyer has the NFT.

# [H-01] The owner can change the fee structure at any time, resulting in losses for buyers and gains for sellers.

## Severity

**Impact:** High, because sellers can game the system at any point

**Likelihood:** Medium, because there is responsibility on the owner to set the fee structure, which will happen in real time

## Description

In function ```changeFee```, it is set to be called only by the owner.

```solidity
    function changeFee (uint _newFee) public {
        require(msg.sender == owner, "Not Owner");
        feePercent = _newFee;
    }
```
However, this is a centralisation risk, as the owner can change the fee structure at any time, even during key 
execution during purchaseItem.

POC:

User lists NFT for sale at 1 BNB.

Buyer calls ```purchaseItem``` and passes in the _item obeject and 1 BNB.

The function checks that msg.value is greater than or equal to the price of the item, and then calculates the fee.

```solidity
  require(msg.value >= _totalPrice, "Insufficient funds");
        //send Fee to Markeplace owner
        feeAccount.transfer(_totalPrice * feePercent / 1000);
```

So we get ```_totalPrice * feePercent / 1000 = 1 * 25 / 1000 = 0.025 BNB```

Now, the owner changes the ```feePercent``` to say 50 from 25.

So we get ```_totalPrice * feePercent / 1000 = 1 * 50 / 1000 = 0.05 BNB```

So the owner has doubled the fee, and the buyer has no way of knowing this, which means the seller will receive
more than they expected, and the buyer will pay more than they expected by the time the below call is made.

```solidity
        //send remaining BNB to seller

payable(item.seller).transfer(_item[i].price * (1000-feePercent) / 1000);
```

## Recommendations

Set a constant feePercent as a state variable, set a local variable to store the current feePercent in the function or only allow fees to be changed if the contract is paused.
(Import Open Zeppelin pausable library) 
This may mitigate this scenario, coupled with notifying users of the change in fees.

# [H-02] listItem doesn't check if the seller of the NFT is the owner of the NFT, which can lead to loss of funds for buyers.

## Severity

**Impact:** High, because this will result in loss of funds

**Likelihood:** Medium, because malicious users will almost always gameify this.

## Description

In function ```listItem``` there is only currently a call to ```isApprovedForAll``` to check if the contract is authorised to transfer the NFT.

However, there is no explicit check to see if the seller of the NFT is the owner.

This means that anyone can list an NFT for sale, even if they don't own it.

So when a malicious seller lists an item for sale by observing the details of a genuine seller's input and a buyer then calls ```purchaseItem```, the malicious seller
will receive the funds, but the buyer will not receive the NFT.

```solidity
            payable(item.seller).transfer(_item[i].price * (1000-feePercent) / 1000);
```

Because there is no check to see if the seller is the owner of the NFT, the seller can steal the funds from the buyer and the buyer will not receive the NFT.


## Recommendations

Add a check to see if the seller is the owner of the NFT before listing it for sale.

```solidity
require(_nft.ownerOf(_id) == msg.sender, "Not the owner of this NFT");
```

# [H-03] An attacker can frontrun the seller and list an NFT for a low price, and then purchase the same NFT.

## Severity

**Impact:** High, because this will result in loss of funds and NFTs

**Likelihood:** Medium, because malicious users will almost always gameify this.

## Description

In listItem there are no checks to see if the NFT is owned by the original caller of the function.

There is also no check to see if the NFT is already listed for sale.

Therefore, once a seller calls ```listItem```, the transaction will hang in the mempool.

The attacker, observing the mempool, can list that same NFT for a lower price, and then call ```purchaseItem```.

Stealing the NFT from the seller and receiving the funds from the buyer (himself), 
as he listed the NFT, when he calls purchaseItem. He is also able to receive the sale fee,

```solidity
            payable(item.seller).transfer(_item[i].price * (1000-feePercent) / 1000);
```
 as he listed the NFT.

He then calls ```unlistItem``` and the item is no longer for sale.

The attacker does this by submitting a higher gas fee than the genuine seller, which gets his transaction
processed before the genuine seller's transaction.

## Recommendations

Refactor the code to check if the NFT is owned by the caller of listItem, 
and also check if the NFT is already listed for sale.

# [H-04] Attacker can frontrun the seller and purchase the NFT before the seller's unlistItem transaction is processed.

## Severity

**Impact:** High, because this will result in loss of NFTs

**Likelihood:** Medium, because malicious users will almost always gameify this.

## Description

Lets say a seller wants to unlist the NFT..

He does so by calling ```unlistItem```.

Lets now say a nefarious actor observes this transaction hanging in the mempool, 
they now decide to quickly call ```purchaseItem``` passing in the same params of the NFT.

This happens before the seller's transaction is processed.

The nefarious actor now owns the NFT and the seller has lost the NFT.


## Recommendations

When the seller initiates the unlisting of an item, instead of immediately deleting the listing, you can mark it as "unlisted" in the contract state.
Before allowing a purchase through the purchaseItem function, check if the item is marked as "unlisted." If it is, prevent the purchase.
After a certain period of time or once the unlisting transaction is confirmed, you can allow the listing to be fully removed from the contract state.

# [M-01] Sellers can list the same NFTs consistently 

## Severity

**Impact:** High, because this will result in loss of NFTs

**Likelihood:** Low, because it will take up some time to keep track of all NFTs listed in this manner

## Description

In the listItem function, there is no check to see if the item is already listed. This means that a seller can list the same NFTs consistently, which will result in the same NFT being listed multiple times..

This will lead to confusion amongst buyers as to which NFT is the genuine one, and will also lead to the seller receiving multiple payments for the same NFT.


## Recommendations

Add a check to see if the item is already listed before listing it.

```solidity
require(!itemExists[_item[i].id], "Item already listed");
```

# [M-02] BNB can be paused at Admin level causing failures in transactions 

## Severity

**Impact:** High, because this will result in failure of multiple transactions

**Likelihood:** Low, because pausing native currencies will be conducted at admin level and not too often

## Description

In the midst of ```purchaseItem```, there are 2 calls to transfer BNB.

```solidity
        //send Fee to Markeplace owner
        feeAccount.transfer(_totalPrice * feePercent / 1000);

        //send remaining BNB to seller
        payable(item.seller).transfer(_item[i].price * (1000-feePercent) / 1000);
```

Now, BNB has an admin level function that allows the admin to pause the contract.

If this happens:

Paused Transactions: 
If the native coin is paused or frozen, it would prevent the transfers of BNB between addresses. In the context of your purchaseItem function, this could lead to failures during the execution of the following parts:

The ```feeAccount.transfer(_totalPrice * feePercent / 1000)``` line: 
The transfer of the fee from the buyer to the marketplace owner might fail if the native coin is paused.

The ```payable(item.seller).transfer(_item[i].price * (1000-feePercent) / 1000)``` line: 
The transfer of the sale fee to the seller might also fail if the native coin is paused.

The ```_nft.transferFrom(seller, msg.sender, id)``` line: If the native coin is paused, this could prevent the transfer of the NFT from the seller to the buyer.

Incomplete Transactions: 

If any part of the transaction fails due to the pause or freeze of the native coin, the transaction might be left in an incomplete state. This could result in the buyer losing their funds without receiving the NFT or the seller not receiving their funds.

## Recommendations

It is wise before any transfer of funds to check if the BNB contract is paused.


# [M-03] Missing return values on BNB transfer

## Severity

**Impact:** High, because this will result in failure of verifying return values

**Likelihood:** Medium, as this will likely happen from time to time without checking

## Description

During the ```purchaseItem``` function, there is an external call to transfer the fee to the marketplace owner.

```solidity
        //send Fee to Markeplace owner
        feeAccount.transfer(_totalPrice * feePercent / 1000);

        and 
        //send saleFee
        payable(item.seller).transfer(_item[i].price * (1000-feePercent) / 1000);
```

However, there is no check to see if the transfer was successful.

If using BNB, it (transfer) will not return a bool on erc20 methods. Missing a return value.
https://twitter.com/Uniswap/status/1072286773554876416


If the transaction reverts after the marketplace owner's fee has been deducted but before the transaction is completed, you might end up in an inconsistent state where the fee has been taken from the buyer but hasn't been received by the marketplace owner.

If the transfer of funds to the seller reverts, the buyer would lose their funds without receiving the NFT, and the seller would not receive their payment.

## Recommendations


Its important to use the .call method when calling external contracts, and check the return value, rather than ```.transfer```.

For example:

```solidity
// Sending fee to marketplace owner
(bool feeTransferSuccess, ) = feeAccount.call{value: _totalPrice * feePercent / 1000}("");
require(feeTransferSuccess, "Fee transfer failed");

// Sending sale fee to seller
(bool saleFeeTransferSuccess, ) = payable(item.seller).call{value: _item[i].price * (1000-feePercent) / 1000}("");
require(saleFeeTransferSuccess, "Sale fee transfer failed");
```

Keep in mind ```.call``` can open up for reentrancy attacks, so alteratively use Open Zeppellins ```sendValue``` method.

# [M-04] transferFrom doesnt revert the transaction upon failure

## Severity

**Impact:** High, because this will result in loss of funds

**Likelihood:** Medium, as this will likely happen from time to time without checking

## Description

In the purchaseItem function, there is a call to transfer the NFT from the seller to the buyer.

```solidity
        //transfer NFT to buyer
        _nft.transferFrom(seller, msg.sender, id);
```

However, if this transfer fails, the transaction will not revert.

This means that the buyer will lose their funds, but will not receive the NFT. As the mapping of the item to the buyer will not be updated, as its been deleted from the items array.

## Recommendations

Use Open Zeppellins SafeERC20 library, which will revert the transaction if the transfer fails.

```_nft.safeTransferFrom(seller, msg.sender, id);```

# [M-05] Block gas limit can be reached in purchaseItem

## Severity

**Impact:** High, because this will result in failed transactions

**Likelihood:** Medium, as this will likely happen almost everytime the ```purchaseItem``` function call

## Description

In the ```purchaseItem``` function, there are 2 for loops, which iterate over the items array.

There are several state changes taking place in this function, which will result in higher gas fees than usual.

When the items array is large, this could result in the block gas limit being reached, which would result in the transaction failing.

## Recommendations

Combine multiple operations into a single loop to reduce the number of iterations. For instance, batch the transfer of NFTs and payments to sellers together in a single loop.

# [L-01] Locking the contract forever is possible

## Severity

**Impact:** High, because this will result in locked contract

**Likelihood:** Low, although care is assumed, mitigation here is a must and there is a chance of the wrong address being passed in

## Description

There is no check that the address of the new owner is the zero address.

If the current owner deliberately or accidently sets the new owner to the zero address, the contract will be permanently locked.

```solidity
  function changeOwner (address _newOwner) public {
        require(msg.sender == owner, "Not Owner");
        owner = _newOwner;
    }
```

## Recommendations

Add a require statement that prevents the new owner from being the zero address.

```require(_newOwner != address(0), "New owner cannot be zero address");```


# [L-02] Use a two-step ownership transfer approach

## Severity

**Impact:** Medium, because this will result in accidently tranfering ownership to an address not desired

**Likelihood:** Low, although care is assumed, mitigation here is a must and there is a chance of the wrong address being passed in

## Description

When transfering ownership, please use Open Zeppelin's Ownable contract and import it into the contract.

Specifically the Ownable2Step contract.

## Recommendations

As it gives you the security of not unintentionally sending the owner role to an address you do not control.

See below current implementation.

```solidity
  function changeOwner (address _newOwner) public {
        require(msg.sender == owner, "Not Owner");
        owner = _newOwner;
    }
```

By using the Ownable2Step library this ensures you are following the industry best practices.

# [G-01] Use unchecked in for loops 


## Description

Use unchecked for arithmetic where you are sure it won't over or underflow, 
saving gas costs for checks added from solidity v0.8.0.

In the example below, the variable i cannot overflow because of the condition i < length, where length is defined as uint256. The maximum value i can reach is max(uint)-1. 

Thus, incrementing i inside unchecked block is safe and consumes lesser gas.

```solidity
function loop(uint256 length) public {
	for (uint256 i = 0; i < length; ) {
	    // do something
	    unchecked {
	        i++;
	    }
	}
}
```

## Recommendations

In function ```purchaseItem``` implement these changes into the for loop.

# [G-02] Use calldata instead of memory

## Description

It is generally cheaper to load variables directly from calldata, rather than copying them to memory. Only use memory if the variable needs to be modified.


## Recommendations

```solidity
    function listItem(Item memory _item) external nonReentrant 
```

Change to:

```solidity
    function listItem(Item calldata _item) external nonReentrant 
```

# [G-03] Use custom errors where possible

## Severity

**Impact:** Medium, because this will result in accidently tranfering ownership to an address not desired

**Likelihood:** Low, although care is assumed, mitigation here is a must and there is a chance of the wrong address being passed in

## Description

Instead of using strings for error messages (e.g., require(msg.sender == owner, “unauthorized”)), you can use custom errors to reduce both deployment and runtime gas costs. In addition, they are very convenient as you can easily pass dynamic information to them.

## Recommendations


Use custom errors where possible, as they are cheaper than revert.
```solidity
            require(item.seller != address(0), "item doesn't exist");
```
Change to:

List the error in the contract body:

```error ItemDoesNotExist(uint256 id);```

Then use it in the require statement:

```require(item.seller != address(0))```

```revert ItemDoesNotExist(id);```


