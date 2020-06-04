# Our Smart Contracts - In-Depth Breakdown

## Ethereum ERC-777 - The backbone of our tokens

Our smart Contracts are ERC-777, ERC-20 Compatble. For Techincal Details on ERC-777 Standard: [https://eips.ethereum.org/EIPS/eip-777](https://eips.ethereum.org/EIPS/eip-777)

We won't be going through all of the fantastic ERC-777 features nor the ERC-20 features on this page and instead focus purely on our smart contract implementation.

DAM and FLUX tokens were written in Solidity. Be sure to check out their tutorial before jumping into code: [https://solidity.readthedocs.io/en/v0.4.24/introduction-to-smart-contracts.html](https://solidity.readthedocs.io/en/v0.4.24/introduction-to-smart-contracts.html)

## OpenZepplin - The secure implementation layer

Our Smart Contracts are based on secure and trusted [OpenZepplin ERC-777 Smart Contract](https://docs.openzeppelin.com/contracts/2.x/api/token/erc777)

OpenZepplin code is at the heart of our tokens and we follow their security practices and implementation very carfully.

# Datamine (DAM) Token

For the base Datamine (DAM) token we've kept it as simple and basic as possible. This token is a standard ERC-777 implementation and was deployed on Ethereum mainnet with fixed supply of 25,000,000 DAM.

All extensions on the base tokens are done through the new ERC-777 "Operators". This feature allows other ethereum addresses to operate on behalf of your account. Instead of another address, we've used this functionality to grant another smart contract operator role. 

This means that we can write additional smart contracts to extend base functionality of Datamine (DAM) token. Our first cross-smart contract functionality written in this manner is FLUX, our second, mintable token.

# FLUX Token

Let's go over the FLUX smart contract in detail skipping the entire OpenZepplin ERC-777 base implementation and focusing only on the FLUX implementation.

Let's jump right into the FLUX smart contract code. We'll go through code in logical blocks.

## Libraries & Interfaces

```
pragma solidity ^0.6.0;
```
To follow the OpenZepplin approach, we've decided to go with the same min compiler version. We've deployed FLUX token to mainnet with solidity 0.6.9


```
import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
```
Right away we get into the heavy usage of OpenZepplin secure libraries. This is the base ERC-777 implementation that FLUX is based on.


```
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
```
We've already included ERC777.sol, why include the interface? FLUX smart contract accepts a _token as one of the constructore parameters. We'll discuss this in the **constructor** section below.

```
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
```
The FLUX token is an ERC-777 token, that also implements `IERC777Recipient`. The reason behind this is discussed in **tokensReceived** section.

`IERC1820Registry` is called to register our own `tokensReceived()` implementation. This allows us to control what kinds of tokens can be sent to the FLUX token. There are a few requirements here as discussed in **tokensReceived** section.


```
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
```

We're using both Math and SafeMath libraries from OpenZepplin: [https://docs.openzeppelin.com/contracts/2.x/api/math](https://docs.openzeppelin.com/contracts/2.x/api/math)

These are critical security libraries to avoid [Integer Overflow and Underflow](https://consensys.github.io/smart-contract-best-practices/known_attacks/#integer-overflow-and-underflow). All math operations such as `.add()`, `.sub()`, `.mul()`, `.div()` are done through the SafeMath library.


