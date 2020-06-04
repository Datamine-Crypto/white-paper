# Our Smart Contracts - In-Depth Breakdown

## Ethereum ERC-777 - The backbone of our tokens

Our smart Contracts are ERC-777, ERC-20 Compatble. For Techincal Details on ERC-777 Standard: [https://eips.ethereum.org/EIPS/eip-777](https://eips.ethereum.org/EIPS/eip-777)

We won't be going through all of the fantastic ERC-777 features nor the ERC-20 features on this page and instead focus purely on our smart contract implementation.

## OpenZepplin - The secure implementation layer

Our Smart Contracts are based on secure and trusted [OpenZepplin ERC-777 Smart Contract](https://docs.openzeppelin.com/contracts/2.x/api/token/erc777)

OpenZepplin code is at the heart of our tokens and we follow their security practices and implementation very carfully.

# Datamine (DAM) Token

For the base Datamine (DAM) token we've kept it as simple and basic as possible. This token is a standard ERC-777 implementation and was deployed on Ethereum mainnet with fixed supply of 25,000,000 DAM.

All extensions on the base tokens are done through the new ERC-777 "Operators". This feature allows other ethereum addresses to operate on behalf of your account. Instead of another address, we've used this functionality to grant another smart contract operator role. 

This means that we can write additional smart contracts to extend base functionality of Datamine (DAM) token. Our first cross-smart contract functionality written in this manner is FLUX, our second, mintable token.

# FLUX Token

Let's go over the FLUX smart contract in detail skipping the entire OpenZepplin ERC-777 base implementation and focusing only on the FLUX implementation.


