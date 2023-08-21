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

**_review commit hash_ - [fffffffff](url)**

**_fixes review commit hash_ - [fffffffff](url)**

### Scope

The following smart contracts were in scope of the audit:

- `VautSales`
- `Open Zeppelin Contracts`
- `Interfaces`

---

# Findings Summary

| ID     | Title                   | Severity | Status |
| ------ | ----------------------- | -------- | ------ |
| [C-01] | Any Critical Title Here | Critical | TBD    |
| [H-01] | Any High Title Here     | High     | TBD    |
| [M-01] | Any Medium Title Here   | Medium   | TBD    |
| [L-01] | Any Low Title Here      | Low      | TBD    |

# Detailed Findings

# [C-01] BNB is stuck within the feeAccount forever.

## Severity

**Impact:** High, because native tokens sent to feeAccount will never be withdrawn

**Likelihood:** High, because there is no way for it to be withdrawn currently

## Description

During ```purchaseItem```, the payable modifier in Solidity is used to send BNB to the feeAccount.

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

# [C-01] BNB is stuck within the feeAccount forever.

## Severity

**Impact:** High, because native tokens sent to feeAccount will never be withdrawn

**Likelihood:** High, because there is no way for it to be withdrawn currently

## Description

During ```purchaseItem```, the payable modifier in Solidity is used to send BNB to the feeAccount.

However, there is currently no way to withdraw BNB from the feeAccount.

This means that once BNB is sent to the ```feeAccount```, it will remain there indefinitely, and there is no automated way for the contract owner to retrieve those funds.

## Recommendations

