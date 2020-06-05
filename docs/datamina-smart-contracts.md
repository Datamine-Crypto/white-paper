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
The FLUX token is an ERC-777 token, that also implements `IERC777Recipient`. `IERC1820Registry` is called to register our own `tokensReceived()` implementation. This allows us to control what kinds of tokens can be sent to the FLUX token. 

The reason behind both of these decisions is discussed in [ERC-1820 ERC777TokensRecipient Implementation](#erc-1820-erc777tokensrecipient-implementation) section.


```
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
```

We're using both Math and SafeMath libraries from OpenZepplin: [https://docs.openzeppelin.com/contracts/2.x/api/math](https://docs.openzeppelin.com/contracts/2.x/api/math)

These are critical security libraries to avoid [Integer Overflow and Underflow](https://consensys.github.io/smart-contract-best-practices/known_attacks/#integer-overflow-and-underflow). All math operations such as `.add()`, `.sub()`, `.mul()`, `.div()` are done through the SafeMath library.

## Address Locking

Datamine (DAM) tokens can be locked-in to the FLUX smart contract (by using our two way ERC-777 operator cross-smart contract communication). The locking process is address-specific and is stored in a struct in the following format:

```
/**
 * @dev Representation of each DAM Lock-in
 */
struct AddressLock {
    /**
     * @dev DAM locked-in amount
     */
    uint256 amount;

    /**
     * @dev How much FLUX was burned
     */
    uint256 burnedAmount;

    /**
     * @dev When did the lock-in start
     */
    uint256 blockNumber;

    /**
     * @dev When was the last time this address minted?
     */
    uint256 lastMintBlockNumber;

    /**
     * @dev Who is allowed to mint on behalf of this address
     */
    address minterAddress;
}
```

Please pay attention to explicit `uin256` types to be in line with OpenZepplin contracts. These structs are stored in a `mapping` as described later in this page.

## Contract Inheritance & Implementations

```
/**
 * @dev Datamine Crypto - FLUX Smart Contract
 */
contract FluxToken is ERC777, IERC777Recipient {
```
Here you will notice something interesting. Flux token is both an `ERC777` contract but also implements `IERC777Recipient`. The reason behind this is discussed in [ERC-1820 ERC777TokensRecipient Implementation](#erc-1820-erc777tokensrecipient-implementation) section.

## Security: SafeMath base

```
/**
 * @dev Protect against overflows by using safe math operations (these are .add,.sub functions)
 */
using SafeMath for uint256;
 ```
This is the first line of contract and is an extremely important security feature. We use OpenZepplin SafeMath for all arithmetic operations to avoid Integer Overflow and Underflow attacks as described here: https://consensys.github.io/smart-contract-best-practices/known_attacks/#integer-overflow-and-underflow

## Security: Mutex & Checks-Effects-Interactions Pattern usage

We're over-using a mutex pattern to avoid a form of re-entrancy attacks as described here: https://consensys.github.io/smart-contract-best-practices/known_attacks/#reentrancy

We're using [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.8/security-considerations.html#use-the-checks-effects-interactions-pattern) throughout the contract. This is why mutex is over-doing it but we want over-do it on the security in favor of small gas cost increase.

```
/**
 * @dev for the re-entrancy attack protection
 */
mapping(address => bool) private mutex;

/**
 * @dev To avoid re-entrancy attacks
 */
modifier preventRecursion() {
    if(mutex[_msgSender()] == false) {
        mutex[_msgSender()] = true;
        _; // Call the actual code
        mutex[_msgSender()] = false;
    }

    // Don't call the method if you are inside one already (_ above is what does the calling)
}
```

## Security: Our Modifiers

Once again, we like to over-do it a bit on the security side in favor of gas costs. Take a look a look at our `preventSameBlock()` modifier: 

```
/**
 * @dev To limit one action per block per address 
 */
modifier preventSameBlock(address targetAddress) {
    require(addressLocks[targetAddress].blockNumber != block.number && addressLocks[targetAddress].lastMintBlockNumber != block.number, "You can not lock/unlock/mint in the same block");

    _; // Call the actual code
}
```
To keep things simple and to avoid potential attacks in the future we've limited our all smart contract state changes to one block per address. This means you can't lock/unlock or lock/mint within the same block.

Since Ethereum blocks are only ~15 seconds in duration we though this slight time delay is not a factor for any normal user and is an added security benefit.

We also have the following modifier that is used throughout all state changes:
```
/**
 * @dev DAM must be locked-in to execute this function
 */
modifier requireLocked(address targetAddress, bool requiredState) {
    if (requiredState) {
        require(addressLocks[targetAddress].amount != 0, "You must have locked-in your DAM tokens");
    }else{
        require(addressLocks[targetAddress].amount == 0, "You must have unlocked your DAM tokens");
    }

    _; // Call the actual code
}
```
This modifier allows us to quickly check if an address has DAM locked-in for a specific address. Since most state changes require this check this is an extremely useful modifier.

## Datamine (DAM) token address

In the FLUX constructor we accept an address for deployed Datamine (DAM) token smart contract address:
```
/**
 * @dev This will be DAM token smart contract address
 */
IERC777 immutable private _token;
```
Notice the `immutable` keyword, this was introduced in Solidity 0.6.5 and it's a nice security improvement as we know this address won't change somehow later in the contract.

## ERC-1820 ERC777TokensRecipient Implementation

```
/**
 * @dev Decline some incoming transactions (Only allow FLUX smart contract to send/recieve DAM tokens)
 */
function tokensReceived(
    address operator,
    address from,
    address to,
    uint256 amount,
    bytes calldata,
    bytes calldata
) external override {
    require(amount > 0, "You must receive a positive number of tokens");
    require(_msgSender() == address(_token), "You can only lock-in DAM tokens");

    // Ensure someone doesn't send in some DAM to this contract by mistake (Only the contract itself can send itself DAM)
    require(operator == address(this) , "Only FLUX contract can send itself DAM tokens");
    require(to == address(this), "Funds must be coming into FLUX token");
    require(from != to, "Why would FLUX contract send tokens to itself?");
}
```
Our ERC777TokensRecipient implementation is quite unique here. Let's go through this line by line:

```
require(amount > 0, "You must receive a positive number of tokens");
```
Over-doing it on security even though amount is a unsigned int, we don't want to somehow receive 0 tokens.

```
require(_msgSender() == address(_token), "You can only lock-in DAM tokens");
```
Ensure that only Datamine (DAM) tokens can be sent to the FLUX smart contract. Reverts any other tokens sent to the FLUX smart contract, which is most likely done by accident by the user. Since the transaction is reverted the user gets the tokens back and is not charged a gas fee.

```
// Ensure someone doesn't send in some DAM to this contract by mistake (Only the contract itself can send itself DAM)
require(operator == address(this) , "Only FLUX contract can send itself DAM tokens");
```
Since DAM tokens are locked-in to the FLUX smart contract we wanted to avoid users sending tokens to the contract itself. In beginning we considred DAM tokens to be locked-in once they are sent to the FLUX smart contract however this would cause issues if funds were sent from exchange (as the user doesn't have private key to the address that was used).

By performing this one simple check we avoid potential loss of funds down the road. Only the FLUX contract can send itself tokens, quite a clever usage of ERC-777.

```
require(to == address(this), "Funds must be coming into FLUX token");
```
Since `ERC777TokensRecipient` can be overriden in ERC-1820 registry we wanted to be 100% certain that the funds are sent to the FLUX smart contract. It shouldn't be possible so why not pay a bit of gas to be 100% sure?

```
require(from != to, "Why would FLUX contract send tokens to itself?");
````
Another impossible case is also covered by this check. If FLUX token can only operate as source or destination, why would it be both? 

## Security: Immutable State Variables

Let's take a look at the immutable state variables first. We'll be assuming our usual 1 block = 15 seconds for all calculations. This makes our math easy and avoids [Timestamp Dependence attacks](https://consensys.github.io/smart-contract-best-practices/known_attacks/#timestamp-dependence).

If Ethereum block times change significantly in the future then the entire FLUX smart contract follows suite and the rewards might be accelerated or slowed down accordingly. During our Ropsten testnet beta phase we've experienced 1 minute+ block times.

```
/**
 * @dev Set to 5760 on mainnet (min 24 hours before time bonus starts)
 */
uint256 immutable private _startTimeReward;
```
To start receiving the time bonus (reward of which is capped at 3x a person will need to wait this many blocks). This is set to ~24 hours on mainnet and prvenets users from locking-in Datamine (DAM) tokens for a short duration. Once again, our goal here is incentivized security where we want you to lock-in your tokens for months at a time.

```
/**
 * @dev Set to 161280 on mainnet (max 28 days before max 3x time reward bonus)
 */
uint256 immutable private _maxTimeReward;
```
Used in time reward multiplier math as the maximum reward point. This is set to ~28 days so if you lock-in your DAM tokens for this duration you will receive the maximum 3x time reward bonus.

```
/**
 * @dev How long until you can lock-in any DAM token amount
 */
uint256 immutable private _failsafeTargetBlock;     
```
FLUX Smart Contracts features a failsafe mode. We only let you lock-in 100 DAM for 28 days at launch. This is done in accordance with the [Ethereum Fail-Safe Security Best Practice](https://solidity.readthedocs.io/en/v0.6.8/security-considerations.html#include-a-fail-safe-mode).

## Constructor

```
constructor(address token, uint256 startTimeReward, uint256 maxTimeReward, uint256 failsafeBlockDuration) public ERC777("FLUX", "FLUX", new address[](0)) {
    _token = IERC777(token);
    _startTimeReward = startTimeReward;
    _maxTimeReward = maxTimeReward;
    _failsafeTargetBlock = block.number.add(failsafeBlockDuration);

    _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
}
```
Here we construct our FLUX token with 0 FLUX premine, assign our immutable state variables and register the contract as an `ERC777TokensRecipient`

## Constants

@todo

## Contract State Variables

Now that the contract state and structure is out of the way let's focus on business logic of the FLUX smart contract.

We'll go through each state variables making comments as we go along. State changes are imporant and require extra security considrations.

@todo



