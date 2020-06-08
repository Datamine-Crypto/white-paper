# Our Smart Contracts - In-Depth Breakdown

## Ethereum ERC-777 - The backbone of our tokens

Our smart Contracts are ERC-777, ERC-20 Compatble. For Techincal Details on ERC-777 Standard: [https://eips.ethereum.org/EIPS/eip-777](https://eips.ethereum.org/EIPS/eip-777)

We won't be going through all of the fantastic ERC-777 features nor the ERC-20 features on this page and instead focus purely on our smart contract implementation.

DAM and FLUX tokens were written in Solidity. Be sure to check out their tutorial before jumping into code: [https://solidity.readthedocs.io/en/v0.6.9/introduction-to-smart-contracts.html](https://solidity.readthedocs.io/en/v0.6.9/introduction-to-smart-contracts.html)

## OpenZeppelin - The secure implementation layer

Our Smart Contracts are based on secure and trusted [OpenZeppelin ERC-777 Smart Contract](https://docs.openzeppelin.com/contracts/2.x/api/token/erc777)

OpenZeppelin code is at the heart of our tokens and we follow their security practices and implementation very carefully.

# Datamine (DAM) Token

For the base Datamine (DAM) token we've kept it as simple and basic as possible. This token is a standard ERC-777 implementation and was deployed on Ethereum mainnet with fixed supply of 25,000,000 DAM. We'll have the final amount of burned DAM tokens after the BWK coin -> DAM token is complete.

All extensions on the base tokens are done through the new ERC-777 "Operators". This feature allows other ethereum addresses to operate on behalf of your account. Instead of another address, we've used this functionality to grant another smart contract operator role. 

This means that we can write additional smart contracts to extend base functionality of Datamine (DAM) token. Our first cross-smart contract functionality written in this manner is FLUX, our second, mintable token.

Full Datamine (DAM) Token source code can be found here: https://etherscan.io/address/0xf80d589b3dbe130c270a69f1a69d050f268786df#code

# FLUX Token

Let's go over the FLUX smart contract in detail skipping the entire OpenZeppelin ERC-777 base implementation and focusing only on the FLUX implementation.

The FLUX smart contract drives the business logic of Datamine, it's important that our business logic is open for the rest of the world to see. Let's jump right into the FLUX smart contract code. We'll go through code in logical blocks.

Full Datamine (DAM) Token source code can be found here: https://etherscan.io/address/0x469eda64aed3a3ad6f868c44564291aa415cb1d9#code

## Libraries & Interfaces

```Solidity
pragma solidity 0.6.9;
```
We've deployed FLUX token to mainnet with solidity 0.6.9. This number is locked as per security recommendation: [Lock pragmas to specific compiler version](https://consensys.github.io/smart-contract-best-practices/recommendations/#lock-pragmas-to-specific-compiler-version)

```Solidity
import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
```
Right away we get into the heavy usage of OpenZeppelin secure libraries. This is the base ERC-777 implementation that FLUX is based on.


```Solidity
import "@openzeppelin/contracts/token/ERC777/IERC777.sol";
```
We've already included ERC777.sol, why include the interface? FLUX smart contract accepts a _token as one of the constructore parameters. We'll discuss this in the **constructor** section below.

```Solidity
import "@openzeppelin/contracts/token/ERC777/IERC777Recipient.sol";
import "@openzeppelin/contracts/introspection/IERC1820Registry.sol";
```
The FLUX token is an ERC-777 token, that also implements `IERC777Recipient`. `IERC1820Registry` is called to register our own `tokensReceived()` implementation. This allows us to control what kinds of tokens can be sent to the FLUX token. 

The reason behind both of these decisions is discussed in [ERC-1820 ERC777TokensRecipient Implementation](#erc-1820-erc777tokensrecipient-implementation) section.


```Solidity
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/math/Math.sol";
```

We're using both Math and SafeMath libraries from OpenZeppelin: [https://docs.openzeppelin.com/contracts/2.x/api/math](https://docs.openzeppelin.com/contracts/2.x/api/math)

These are critical security libraries to avoid [Integer Overflow and Underflow](https://consensys.github.io/smart-contract-best-practices/known_attacks/#integer-overflow-and-underflow). All math operations such as `.add()`, `.sub()`, `.mul()`, `.div()` are done through the SafeMath library.

## Address Locking

Datamine (DAM) tokens can be locked-in to the FLUX smart contract (by using our two way ERC-777 operator cross-smart contract communication). The locking process is address-specific and is stored in a struct in the following format:

```Solidity
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

Please pay attention to explicit `uin256` types to be in line with OpenZeppelin contracts. These structs are stored in a `mapping` as described later in this page.

## Contract Inheritance & Implementations

```Solidity
/**
 * @dev Datamine Crypto - FLUX Smart Contract
 */
contract FluxToken is ERC777, IERC777Recipient {
```
Here you will notice something interesting. Flux token is both an `ERC777` contract but also implements `IERC777Recipient`. The reason behind this is discussed in [ERC-1820 ERC777TokensRecipient Implementation](#erc-1820-erc777tokensrecipient-implementation) section.

## Security: SafeMath base

```Solidity
/**
 * @dev Protect against overflows by using safe math operations (these are .add,.sub functions)
 */
using SafeMath for uint256;
 ```
This is the first line of contract and is an extremely important security feature. We use OpenZeppelin SafeMath for all arithmetic operations to avoid Integer Overflow and Underflow attacks as described here: https://consensys.github.io/smart-contract-best-practices/known_attacks/#integer-overflow-and-underflow

## Security: Mutex & Checks-Effects-Interactions Pattern usage

We're over-using a mutex pattern to avoid a form of re-entrancy attacks as described here: https://consensys.github.io/smart-contract-best-practices/known_attacks/#reentrancy

We're using [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#use-the-checks-effects-interactions-pattern) throughout the contract. This is why mutex is over-doing it but we want to over-do it on the security in favor of small gas cost increase.

```Solidity
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

```Solidity
/**
 * @dev To limit one action per block per address 
 */
modifier preventSameBlock(address targetAddress) {
    require(addressLocks[targetAddress].blockNumber != block.number && addressLocks[targetAddress].lastMintBlockNumber != block.number, "You can not lock/unlock/mint in the same block");

    _; // Call the actual code
}
```
To keep things simple and to avoid potential attacks in the future we've limited our all smart contract state changes to one block per address. This means you can't lock/unlock or lock/mint within the same block.

Since Ethereum blocks are only ~15 seconds in duration we thought this slight time delay is not a factor for any normal user and is an added security benefit.

We also have the following modifier that is used throughout all state changes:
```Solidity
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
```Solidity
/**
 * @dev This will be DAM token smart contract address
 */
IERC777 immutable private _token;
```
Notice the `immutable` keyword, this was introduced in Solidity 0.6.5 and it's a nice security improvement as we know this address won't change somehow later in the contract.

## ERC-1820 ERC777TokensRecipient Implementation

```Solidity
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

```Solidity
require(amount > 0, "You must receive a positive number of tokens");
```
Over-doing it on security even though amount is a unsigned int, we don't want to somehow receive 0 tokens.

```Solidity
require(_msgSender() == address(_token), "You can only lock-in DAM tokens");
```
Ensure that only Datamine (DAM) tokens can be sent to the FLUX smart contract. Reverts any other tokens sent to the FLUX smart contract, which is most likely done by accident by the user. Since the transaction is reverted the user gets the tokens back and is not charged a gas fee.

```Solidity
// Ensure someone doesn't send in some DAM to this contract by mistake (Only the contract itself can send itself DAM)
require(operator == address(this) , "Only FLUX contract can send itself DAM tokens");
```
Since DAM tokens are locked-in to the FLUX smart contract we wanted to avoid users sending tokens to the contract itself. In beginning we considred DAM tokens to be locked-in once they are sent to the FLUX smart contract however this would cause issues if funds were sent from exchange (as the user doesn't have private key to the address that was used).

By performing this one simple check we avoid potential loss of funds down the road. Only the FLUX contract can send itself tokens, quite a clever usage of ERC-777.

```Solidity
require(to == address(this), "Funds must be coming into FLUX token");
```
Since `ERC777TokensRecipient` can be overriden in ERC-1820 registry we wanted to be 100% certain that the funds are sent to the FLUX smart contract. It shouldn't be possible so why not pay a bit of gas to be 100% sure?

```Solidity
require(from != to, "Why would FLUX contract send tokens to itself?");
````
Another impossible case is also covered by this check. If FLUX token can only operate as source or destination, why would it be both? 

## Security: Immutable State Variables

New to Solidity 0.6.5, let's take a look at our immutable state variables. We'll be assuming our usual 1 block = 15 seconds for all calculations. This makes our math easy and avoids [Timestamp Dependence attacks](https://consensys.github.io/smart-contract-best-practices/known_attacks/#timestamp-dependence).

If Ethereum block times change significantly in the future then the entire FLUX smart contract follows suite and the rewards might be accelerated or slowed down accordingly. During our Ropsten testnet beta phase we've experienced 1 minute+ block times.

```Solidity
/**
 * @dev Set to 5760 on mainnet (min 24 hours before time bonus starts)
 */
uint256 immutable private _startTimeReward;
```
To start receiving the time bonus (reward of which is capped at 3x a person will need to wait this many blocks). This is set to ~24 hours on mainnet and prevents users from locking-in Datamine (DAM) tokens for a short duration. Once again, our goal here is incentivized security where we want you to lock-in your tokens for months at a time.

```Solidity
/**
 * @dev Set to 161280 on mainnet (max 28 days before max 3x time reward bonus)
 */
uint256 immutable private _maxTimeReward;
```
Used in time reward multiplier math as the maximum reward point. This is set to ~28 days so if you lock-in your DAM tokens for this duration you will receive the maximum 3x time reward bonus.

```Solidity
/**
 * @dev How long until you can lock-in any DAM token amount
 */
uint256 immutable private _failsafeTargetBlock;     
```
FLUX Smart Contracts features a failsafe mode. We only let you lock-in 100 DAM for 28 days at launch. This is done in accordance with the [Ethereum Fail-Safe Security Best Practice](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#include-a-fail-safe-mode).

## Constructor

```Solidity
constructor(address token, uint256 startTimeReward, uint256 maxTimeReward, uint256 failsafeBlockDuration) public ERC777("FLUX", "FLUX", new address[](0)) {  
    require(maxTimeReward > 0, "maxTimeReward must be at least 1 block"); // to avoid division by 0

    _token = IERC777(token);
    _startTimeReward = startTimeReward;
    _maxTimeReward = maxTimeReward;
    _failsafeTargetBlock = block.number.add(failsafeBlockDuration);

    _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
}
```
Here we construct our FLUX token with 0 FLUX premine, assign our immutable state variables and register the contract as an `ERC777TokensRecipient`

**Security Note:** Notice that we are using `block.number.add()` here to find out when failsafe ends (approx 28 days), using OpenZeppelin SafeMath.

**Security Note:** Notice that we are using `require(maxTimeReward > 0)` here to avoid division by 0 for any other smart contracts implementing our contract. This is done to avoid division by 0 and is an extra guard for incorrect Smart Contract deployment.

## Constants

All of our constants are private and are hardcoded at time of smart contract creation. Let's go through constants one by one:

```Solidity
/**
 * @dev How much max DAM can you lock-in during failsafe duration?
 */
 uint256 private constant _failsafeMaxAmount = 100 * (10 ** 18);
```
This is the maximum amount of Datamine (DAM) tokens that can be locked-in to the FLUX smart contract during the failsafe mode. Datamine (DAM) are 18 decimals hence `10 ** 18`. And you can only lock-in 100 DAM during failsafe mode (which lasts ~28 days).

```Solidity
/**
 * @dev 0.00000001 FLUX minted/block/1 DAM
 * @dev 10^18 / 10^8 = 10^10
 */
uint256 private constant _mintPerBlockDivisor = 10 ** 8;
```
The amount of FLUX that can be minted each block is fixed. This is the number that we divide by at the end of the mint formula. We want 1 DAM (10^18) to mint exactly 00000001 FLUX (10^10).

```Solidity
/**
 * @dev To avoid small FLUX/DAM burn ratios we multiply the ratios by this number.
 */
uint256 private constant _ratioMultiplier = 10 ** 10;
```
Because there are no decimals if amount of burned FLUX is < amount locked-in Datamine (DAM) tokens then we would always get 1x burn multiplier. While this is not going to be a problem in the future (assuming ~8m FLUX is minted per year eventually amount of burned FLUX > locked-in DAM tokens) we wanted to make sure the formula would still be rewarding during early stages of mainnet launch.

```Solidity
/**
 * @dev To get 4 decimals on our multipliers we'll multiply all ratios & divide ratios by this number.
 * @dev This is done because we're using integers without any decimals.
 */
uint256 private constant _percentMultiplier = 10000;
```
Both time and burn multipliers have 4 decimal precision. Because we're using only integers we can't actually get decimals. So we always use this as base "1.0000x" multiplier. This means ratios are always multiplied by this number.

```Solidity
/**
 * @dev This is our max 10x FLUX burn multiplier. It's multiplicative with the time multiplier.
 */
uint256 private constant _maxBurnMultiplier = 100000;
```
You can burn FLUX to get up to 10x burn multiplier. This is that number and is used in the minting formula. This number is divided by `_percentMultiplier` constant.

```Solidity
/**
 * @dev This is our max 3x DAM lock-in time multiplier. It's multiplicative with the burn multiplier.
 */
uint256 private constant _maxTimeMultiplier = 30000;
```
You can get up to 3x DAM lock-in time multiplier. This number is divided by `_percentMultiplier` constant.

```Solidity
/**
 * @dev How does time reward bonus scales? This is the "2x" in the "1x base + (0x to 2x bonus) = max 3x"
 */
uint256 private constant  _targetBlockMultiplier = 20000;
```
To get to the 3x time bonus we will be starting from 0 and gradually going up to 2x (`_targetBlockMultiplier/_percentMultiplier`). This number would only start to go up after `startTimeReward` # of blocks elapsed.

## Public State Variables

Here we will cover the logic of the FLUX smart contract and the contract's state variables. Here we must pay extra attention to security as these are the mutable variables. These variables are also marked as PUBLIC FACING for both ability to read their values in ABIs on our dashboard.

```Solidity
/**
 * @dev PUBLIC FACING: By making addressLocks public we can access elements through the contract view (vs having to create methods)
 */
mapping (address => AddressLock) public addressLocks;
```
This is the most important state variable. Here we specify state of each DAM lock-in address. The struct itself is explained in detail in [Address Locking Section](#address-locking). By using a struct for all address states we can greatly simplify our business logic and it's great that Solidity supports structs.

```Solidity
/**
 * @dev PUBLIC FACING: Store how much locked in DAM there is globally
 */
uint256 public globalLockedAmount;
```
Whenever some locks-in some Datamine (DAM) tokens they will be added to this number. This number will also be effected when an address unlockes their DAM tokens back.

```Solidity
/**
 * @dev PUBLIC FACING: Store how much is burned globally (only from the locked-in DAM addresses)
 */
uint256 public globalBurnedAmount;
```
This number is adjusted by lock/unlock just like `globalLockedAmount` variable but tracks sum of all burned FLUX. Please note that this is the global aggregate of only locked-in DAM addresses. This keeps the smart contract future-proof as the number of DAM locked-in gradually decreases.


## Events

All user interaction that modifies state variables produce events. This is crucial for Datamine Framework analytics as we rely on these events for multiple data points.

We're using [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#use-the-checks-effects-interactions-pattern) for events to ensure any external calls are performed at the end and that events occur before these calls.

Our events are extra light, if data can be figured out by iterating through previous events we do not send them along with the event (This data can always be viewed or constructed). Let's go through these events one by one:

```Solidity
event Locked(address sender, uint256 blockNumber, address minterAddress, uint256 amount, uint256 burnedAmountIncrease);
```
Occurs when Datamine (DAM) tokens are locked-in to the FLUX smart contract.

- **sender**: What address locked-in the DAM tokens?
- **blockNumber**: On what block number were the funds locked-in? This number is included in the event as there is math that is bassed off this number and we have to be specific to what number was used in the calculations.
- **amount**: How much DAM was locked-in?
- **burnedAmountIncrease**: How much did the global burn amount increase by? This is taking the burned amount of the address that locked-in the DAM tokens.

```Solidity
event Unlocked(address sender, uint256 amount, uint256 burnedAmountDecrease);
```
Occurs when Datamine (DAM) tokens are unlocked from the FLUX smart contract. Note that we don't emit block number of when this was done as it's not used in calculations.

- **sender**: What address unlocked the DAM tokens?
- **amount**: How much DAM was unlocked?
- **burnedAmountDecrease**: How much did the global burn amount decrease by? This is taking the burned amount of the address that locked-in the DAM tokens.

```Solidity
event BurnedToAddress(address sender, address targetAddress, uint256 amount);
```
Occurs when FLUX tokens are burned to an address with DAM locked-in tokens.

- **sender**: What address burned the FLUX tokens?
- **targetAddress**: To what address did they burn FLUX tokens?
- **amount**: How much FLUX was burned to this target address?

```Solidity
event Minted(address sender, uint256 blockNumber, address sourceAddress, address targetAddress, uint256 targetBlock, uint256 amount);
```
Occurs when FLUX tokens are minted by the delegated minter. 

- **sender**: What is the address of the delegated minter?
- **blockNumber**: What block number did this mint occur on? This is important for math calculations, need to be precise here.
- **sourceAddress**: From what address are we minting from? The minted amount will be based on this address and the sender must be the delegated minter for this address.
- **targetAddress**: What address are we minting this FLUX to? (The recipient of the mint)
- **targetBlock**: Up to what block are we minting? This works for partial minting as you can mint up to a specific block (without minting your entire outstanding FLUX balance).
- **amount**: How much FLUX was minted?

## Public State Modifying Functions

Let's now go through the core actionable functions. These are the functions that perform all of the interactive state changes such as locking, unlocking, burning and minting of FLUX.

### lock()

Let's take a look at how Datamine (DAM) tokens get locked-in to the FLUX smart contract.

```Solidity
/**
 * @dev PUBLIC FACING: Lock-in DAM tokens with the specified address as the minter.
 */
function lock(address minterAddress, uint256 amount) 
    preventRecursion 
    preventSameBlock(_msgSender())
    requireLocked(_msgSender(), false) // Ensure DAM is unlocked for sender
public {
```

- **minterAddress**: Who do we want the target minter to be?
- **amount**: How much Datamine (DAM) tokens are we locking in?
- **preventRecursion modifier**: [Mutex-locking](#security-mutex--checks-effects-interactions-pattern-usage).
- **preventSameBlock modifier**: We don't want the message sender address that is performing an action to be able to execute multiple actions within the same block. This avoids potential forms of [transaction spamming](#security-our-modifiers).
- **requireLocked modifier**: When calling `lock()` function make sure that current message sender does not have Datamine (DAM) tokens locked-in their address (it is UNLOCKED). To keep things simple there are only two states to addresses: "locked/unlocked".

Let's go through the function body:

```Solidity
require(amount > 0, "You must provide a positive amount to lock-in");
```
We don't want users locking in 0 DAM tokens. Since we're using unsigned integers this could also be written as `amount != 0`

```Solidity
// Ensure you can only lock up to 100 DAM during failsafe period
if (block.number < _failsafeTargetBlock) {
    require(amount <= _failsafeMaxAmount, "You can only lock-in up to 100 DAM during failsafe.");
}
```
During our fail-safe mode (Based on [Ethereum Fail-Safe Security Best Practice](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#include-a-fail-safe-mode)) we don't want addresses to lock-in more than `_failsafeMaxAmount` which is 100 DAM (10^18) at launch. This allows us to pull smart contract for 28 days in case of an issue.

```Solidity
AddressLock storage senderAddressLock = addressLocks[_msgSender()]; // Shortcut accessor
```
You will notice this common pattern for a mapping value reference in many FLUX smart contract functions. This allows us to use `senderAddressLock` instead of `addressLocks[_msgSender()]` while accessing struct. You can read more about it here: https://solidity.readthedocs.io/en/v0.6.9/types.html#structs

```Solidity
senderAddressLock.amount = amount;
senderAddressLock.blockNumber = block.number;
senderAddressLock.lastMintBlockNumber = block.number; // Reset the last mint height to new lock height
senderAddressLock.minterAddress = minterAddress;
```
Here we are storing DAM lock-in amount, block number of when the sender called the function and saving the delegated minter address into the struct. Notice we also reset `lastMintBlockNumber` to the same block as the DAM lock-in.

```Solidity
globalLockedAmount = globalLockedAmount.add(amount);
globalBurnedAmount = globalBurnedAmount.add(senderAddressLock.burnedAmount);
```
Adjust the global lock & burn amounts using SafeMath functions. We will now emit our state change event:

```Solidity
emit Locked(_msgSender(), block.number, minterAddress, amount, senderAddressLock.burnedAmount);
```
Emit that DAM was locked-in by the message sender on this block with the delegated minter. You can read more about this event in our [Events Section](#events)

```Solidity
// Send [amount] of DAM token from the address that is calling this function to FLUX smart contract.
IERC777(_token).operatorSend(_msgSender(), address(this), amount, "", ""); // [RE-ENTRANCY WARNING] external call, must be at the end
```
Finally the "Interactions" in [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#use-the-checks-effects-interactions-pattern). Here we use the new ERC-777 Operators to move DAM tokens (by the FLUX smart contract) into the FLUX smart contract itself. The amount comes from function.

**Security Note:** There are no checks on the balance of FLUX tokens as this check is performed internally by the `operatorSend()` function.

### unlock()

You can always choose to unlock your Datamine (DAM) lock-in tokens to get 100% of your DAM tokens back. This is an extremly useful feature and it's done in a completey secure and decentralized manner.

```Solidity
function unlock() 
    preventRecursion 
    preventSameBlock(_msgSender())
    requireLocked(_msgSender(), true)  // Ensure DAM is locked-in for sender
public {
```
- **preventRecursion modifier**: [Mutex-locking](#security-mutex--checks-effects-interactions-pattern-usage).
- **preventSameBlock modifier**: We don't want the message sender address that is performing an action to be able to execute multiple actions within the same block. This avoids potential forms of [transaction spamming](#security-our-modifiers).
- **requireLocked modifier**: When calling `unlock()` function make sure that current message sender has at least some Datamine (DAM) tokens locked-in their address (it is LOCKED). To keep things simple there are only two states to addresses: "locked/unlocked".

```Solidity
AddressLock storage senderAddressLock = addressLocks[_msgSender()]; // Shortcut accessor
```
You will notice this common pattern for a mapping value reference in many FLUX smart contract functions. This allows us to use `senderAddressLock` instead of `addressLocks[_msgSender()]` while accessing struct. You can read more about it here: https://solidity.readthedocs.io/en/v0.6.9/types.html#structs

```Solidity
uint256 amount = senderAddressLock.amount;
senderAddressLock.amount = 0;
```
A secure amount -> 0 swap so we stop referring to the `senderAddressLock.amount` later in the function as we want to avoid any type of re-entrancy.

```Solidity
globalLockedAmount = globalLockedAmount.sub(amount);
globalBurnedAmount = globalBurnedAmount.sub(senderAddressLock.burnedAmount);
```
When unlocking Datamine (DAM) tokens the address contributions are subtracted from global amounts. This is done to ensure the global competition remains fair even in the future as less DAM tokens are available on the market.

We will now emit our state change event:

```Solidity
emit Unlocked(_msgSender(), amount, senderAddressLock.burnedAmount);
```
Emit that DAM was unlocked by the message sender. You can read more about this event in our [Events Section](#events)

```Solidity
// Send back the locked-in DAM amount to person calling the method
IERC777(_token).send(_msgSender(), amount, "");  // [RE-ENTRANCY WARNING] external call, must be at the end   
```
Finally the "Interactions" in [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#use-the-checks-effects-interactions-pattern). Here we use the new ERC-777 `send()` function to send the locked-in DAM tokens from the FLUX token address back to the message sender.

**Security Note:** There are no checks on the balance of DAM tokens as this check is performed internally by the `send()` function.

### burnToAddress()

FLUX was desgined to be burned through on-chain reward mechanism. By burning FLUX you receive higher mint multiplier. Let's take a look at how this function works:

```Solidity
/**
 * @dev PUBLIC FACING: Burn FLUX tokens to a specific address
 */
function burnToAddress(address targetAddress, uint256 amount) 
    preventRecursion 
    requireLocked(targetAddress, true) // Ensure the address you are burning to has DAM locked-in
public {
```
- **preventRecursion modifier**: [Mutex-locking](#security-mutex--checks-effects-interactions-pattern-usage).
- **requireLocked modifier**: When calling `burnToAddress()` function make sure that the TARGET ADDRESS has at least some Datamine (DAM) tokens locked-in their address (it is LOCKED). To keep things simple there are only two states to addresses: "locked/unlocked".

```Solidity
require(amount > 0, "You must burn > 0 FLUX");
```
We don't want to deal with 0 FLUX burn cases so it's the first check to sanitize the user input.

```Solidity
AddressLock storage targetAddressLock = addressLocks[targetAddress]; // Shortcut accessor, pay attention to targetAddress here
```
You will notice this common pattern for a mapping value reference in many FLUX smart contract functions. This allows us to use `senderAddressLock` instead of `addressLocks[_msgSender()]` while accessing struct. Notice the targetAddress here, we want to be sure that the address we are burning TO has some DAM tokens locked-in. This is an extra quality of life check to ensure addresses don't accidentally burn FLUX to wrong address.

```Solidity
targetAddressLock.burnedAmount = targetAddressLock.burnedAmount.add(amount);
```
Credit the address we are burning to with the burned amount (even though the message sender is the one that has the FLUX burned).

```Solidity
globalBurnedAmount = globalBurnedAmount.add(amount);
```
Increase the global burned amount by the additional target-burned amount using SafeMath.

We will now emit our state change event:

```Solidity
emit BurnedToAddress(_msgSender(), targetAddress, amount);
```
Emit that DAM was burned by the message sender to the target address. You can read more about this event in our [Events Section](#events)

```Solidity
// Call the normal ERC-777 burn (this will destroy FLUX tokens). We don't check address balance for amount because the internal burn does this check for us.
_burn(_msgSender(), amount, "", "");
```
Finally the "Interactions" in [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#use-the-checks-effects-interactions-pattern). Here we use the ERC-777 `_burn()` function to finally burn the message sender's amount of FLUX.

**Security Note:** There are no checks on the balance of DAM tokens as this check is performed internally by the `_burn()` function.

### mintToAddress()

This is the final state modifying function that drives the entire minting logic. The area requires maximum security as we're creating new tokens. Let's jump right into it:

```Solidity
/**
 * @dev PUBLIC FACING: Mint FLUX tokens from a specific address to a specified address UP TO the target block
 */
function mintToAddress(address sourceAddress, address targetAddress, uint256 targetBlock) 
    preventRecursion 
    preventSameBlock(sourceAddress)
    requireLocked(sourceAddress, true) // Ensure the adress that is being minted from has DAM locked-in
public {
```

- **preventRecursion modifier**: [Mutex-locking](#security-mutex--checks-effects-interactions-pattern-usage).
- **preventSameBlock modifier**: We don't want the SOURCE ADDRESS (Address with DAM lock-in) that is performing an action to be able to execute multiple actions within the same block. This avoids potential forms of [transaction spamming](#security-our-modifiers).
- **requireLocked modifier**: When calling `unlock()` function make sure that SOURCE ADDRESS has at least some Datamine (DAM) tokens locked-in their address (it is LOCKED). To keep things simple there are only two states to addresses: "locked/unlocked".

Let's jump into the function body:

```Solidity
require(targetBlock <= block.number, "You can only mint up to current block");
```
Since you can target burn up to a specific block (without minting your entire balance) we don't want you to mint FLUX with a block number in the future.

```Solidity
AddressLock storage sourceAddressLock = addressLocks[sourceAddress]; // Shortcut accessor, pay attention to sourceAddress here
```
You will notice this common pattern for a mapping value reference in many FLUX smart contract functions. This allows us to use `sourceAddressLock` instead of `addressLocks[sourceAddress]` while accessing struct. Notice the sourceAddress here, since we are minting FROM a specific address that is not the message sender (delegated minting).

```Solidity
require(sourceAddressLock.lastMintBlockNumber < targetBlock, "You can only mint ahead of last mint block");
```
This is an additional security mechanism to prevent minting prior to the last mint block. That means you can lock-in your Datamine (DAM) tokens in block 1, mint on block 3 and the next time you can't mint prior to block 4 even though the DAM lock-in happened on block 1.

```Solidity
require(sourceAddressLock.minterAddress == _msgSender(), "You must be the delegated minter of the sourceAddress");
```
Ensure that the delegated minter of the source address is the message sender. This means the delegated minter address can also be the source address itself.

```Solidity
uint256 mintAmount = getMintAmount(sourceAddress, targetBlock);
require(mintAmount > 0, "You can not mint zero balance");
```
Here we use the same public-facing view-only `getMintAmount()` function to get the actual mintable amount for the source address up to the target block. This function must return a positive balance so you can't mint 0 FLUX.

```Solidity
sourceAddressLock.lastMintBlockNumber = targetBlock; // Reset the mint height
```
It is important for us to reset the mint height to the TARGET BLOCK. So the next time we can continue from the partial mint block and can't target a block before the new target block mint.

We will now emit our state change event:

```Solidity
emit Minted(_msgSender(), block.number, sourceAddress, targetAddress, targetBlock, mintAmount);
```
Emit that FLUX was minted by the message sender on the current block number from source address to the target address. You can read more about this event in our [Events Section](#events)

Finally the "Interactions" in [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#use-the-checks-effects-interactions-pattern). Here we use the ERC-777 `_mint()` function to finally mint the outstanding FLUX amount to the target address.

**Security Note:** There are no checks on the balance of DAM tokens as this check is performed internally by the ERC-777 `_mint()` function.

## Public View-Only Functions

In this section there are no state changes so these functions are all view-only and don't cost any gas to call. We use these public functions to fetch smart contract data on our Dashboard. Here you will find all of the mathematics behind our logic.

### getMintAmount()

Let's take a look at how we calculate how much FLUX to mint for an address that has Datamine (DAM) tokens locked-in. The returned number is the total amount of FLUX that would be minted if the current address performs a mint:

```Solidity
/**
* @dev PUBLIC FACING: Get mint amount of a specific amount up to a target block
*/
function getMintAmount(address targetAddress, uint256 targetBlock) public view returns(uint256) {
```

- **targetAddress:** To figure out how much is being minted we require a target address and target block. This target address must have some Datamine (DAM) tokens locked.
- **targetBlock:** We can perform partial mints by specifying a target block some time after the DAM lock-in block number. The target block can not exceed current block.

```Solidity
// Ensure this address has DAM locked-in
if (targetAddressLock.amount == 0) {
    return 0;
}
```
This is similar to `requireLocked()` modifier in terms of logic. However if the address doesn't have any Datamine (DAM) tokens locked- in return 0 instead of reverting.

```Solidity
require(targetBlock <= block.number, "You can only calculate up to current block");
```
We don't want to specify a block in the future. If you are trying to use this function for a form of mint forecasting please use Datamine framework as it has built in forecasting and analytics for smart contracts.

```Solidity
require(targetAddressLock.lastMintBlockNumber <= targetBlock, "You can only specify blocks at or ahead of last mint block");
```
We want to ensure that you can't specify an address BEFORE your lock-in period (as this would an overflow revert. Instead there is a more descriptive error message.

### Minted Amount Logic

Let's look into how the actual mint amount is calculated inside `getMintAmount()` function:

```Soliditiy
uint256 blocksMinted = targetBlock.sub(targetAddressLock.lastMintBlockNumber);
```
Using SafeMath, how many blocks passed since the last mint (DAM lock-in is the default date for this until a mint occurs)?

```Solidity
uint256 amount = targetAddressLock.amount; // Total of locked-in DAM for this address
uint256 blocksMintedByAmount = amount.mul(blocksMinted);
```
How much Datamine (DAM) tokens are locked in? Take the number of blocks that passed since last mint and multiply them by the amount of DAM locked-in tokens.

Next we take our multipliers:

```Solidity
// Adjust by multipliers
uint256 burnMultiplier = getAddressBurnMultiplier(targetAddress);
uint256 timeMultipler = getAddressTimeMultiplier(targetAddress);
```
At 1.0000x multiplier, these will be returned as 10000. You can read up more on multipliers in [Constants Section](#constants)

```Solidity
uint256 fluxAfterMultiplier = blocksMintedByAmount.mul(burnMultiplier).div(_percentMultiplier).mul(timeMultipler).div(_percentMultiplier);
```
Modify the `amount * blocksMinted` by multipliers. This would return the same amount as `blocksMintedByAmount` if both multipliers are at 1.0000x.

Finally we must take the multiplied number and divide it by how much FLUX mint divisor:

```Solidity
uint256 actualFluxMinted = fluxAfterMultiplier.div(_mintPerBlockDivisor);
return actualFluxMinted;
```

The divsor gets us to our expected `0.00000001 FLUX minted/block/1 DAM` fromula. To explain this divsor, let's assume the following condition:

- 30.0 DAM locked-in
- For 150 blocks
- 2.5000x FLUX burn multiplier
- 6.3400x DAM lock-in time bonus multiplier

```Solidity
((30 * 10^18) * 150)      // amount.mul(blocksMinted) = blocksMintedByAmount
.mul(25000)               // .mul(burnMultiplier)
.div(10000)               // .div(_percentMultiplier)
.mul(63400)               // .mul(timeMultipler)
.div(10000)               // .div(_percentMultiplier)
.div(10^8)                // .div(_mintPerBlockDivisor)

= 713250000000000         //(0.00071325 FLUX as 1 FLUX = 10^18)
```

### getAddressTimeMultiplier()

Let's take a look at how Datamine (DAM) lock-in time bonus works:

```Solidity
/**
 * @dev PUBLIC FACING: Find out the current address DAM lock-in time bonus (Using 1 block = 15 sec formula)
 */
function getAddressTimeMultiplier(address targetAddress) public view returns(uint256) {

AddressLock storage targetAddressLock = addressLocks[targetAddress]; // Shortcut accessor
```
The function accepts a target address who has the DAM locked-in amount. Notice we also get the address lock details of the address we are targeting. The returned value of this function will be the time multiplier where 1.0000x = 10000.

```Solidity
// Ensure this address has DAM locked-in
if (targetAddressLock.amount == 0) {
    return _percentMultiplier;
}
```
This is similar to `requireLocked()` modifier in terms of logic. However if the address doesn't have any Datamine (DAM) tokens locked- in return 10000 instead of reverting.

```Solidity
// You don't get any bonus until min blocks passed
uint256 targetBlockNumber = targetAddressLock.blockNumber.add(_startTimeReward);
if (block.number < targetBlockNumber) {
    return _percentMultiplier;
}
```
This is how we handle our "min 24 hour" Datamine (DAM) lock-in period. `_startTimeReward` is provided at time of FLUX construction so it can be changed easily in unit tests. If the 24 hours has not passed yet return 10000 (1.0000x time multiplier).

Next let's take a look at how the actual multiplier is calculated:

```Soliditiy
// 24 hours - min before starting to receive rewards
// 28 days - max for waiting 28 days (The function returns PERCENT (10000x) the multiplier for 4 decimal accuracy
uint256 blockDiff = block.number.sub(targetBlockNumber).mul(_targetBlockMultiplier).div(_maxTimeReward).add(_percentMultiplier); 
```

- `block.number.sub(targetBlockNumber)` would give us the number of blocks that passed since 24 min lock-in period. 
- `.mul(_targetBlockMultiplier)` multiply the difference in blocks by 20000.
- `.div(_maxTimeReward)` divide the number by the destination number of blocks (28 days = 161280 blocks)
- `.add(_percentMultiplier)` add 10000 (1.0000x multiplier) to the total

We then finally return the time multiplier:

```Solidity
uint256 timeMultiplier = Math.min(_maxTimeMultiplier, blockDiff); // Min 1x, Max 3x
return timeMultiplier;
```
Using SafeMath helper library ensure we don't exceed 30000 time bonus multiplier. Let's look at an example of the full formula:

- Datamine (DAM) lock-in block: 1
- Current block: 100001

```Solidity
(100001 - 1)              // block.number.sub(targetBlockNumber)
.mul(20000)               // .mul(_targetBlockMultiplier)
.div(161280)              // .div(_maxTimeReward)
.add(10000)               // .add(_percentMultiplier)

= 22400                   // This is divided by 10000 = 2.2400x multiplier
```

### getAddressBurnMultiplier()


Let's take a look at how FLUX burning bonus works:

```Solidity
/**
 * @dev PUBLIC FACING: Get burn multipler for a specific address. This will be returned as PERCENT (10000x)
 */
function getAddressBurnMultiplier(address targetAddress) public view returns(uint256) {
```
We can specify any address (even if it doesn't have Datamine (DAM) tokens locked-in). If there are no DAM tokens locked-in 10000 (1.0000x multiplier) will be returned.

Now let's take a look at how we fetch address & global ratios:

```Solidity
uint256 myRatio = getAddressRatio(targetAddress);
uint256 globalRatio = getGlobalRatio();

// Avoid division by 0 & ensure 1x multiplier if nothing is locked
if (globalRatio == 0 || myRatio == 0) {
    return _percentMultiplier;
}
```
If either of these ratios return 0 then return the default 10000 (1.0000x multiplier). These functions are detailed in later sections.

Finally we use the ratios in the following formula:

```Solidity
// The final multiplier is return with 10000x multiplication and will need to be divided by 10000 for final number
uint256 burnMultiplier = Math.min(_maxBurnMultiplier, myRatio.mul(_percentMultiplier).div(globalRatio).add(_percentMultiplier)); // Min 1x, Max 10x
return burnMultiplier;
```
Here the SafeMath helper ensures we never exceed `_maxBurnMultiplier` (1000000 = 10.0000x). 

We take address ratio, multiply it by 10000 and divide it by global ratio and add 10000. That means to get the maximum burn multiplier bonus the address must burn 9x the global average (think `Math.min(10, 9 + 1)`)

Finally let's look at this formula in detail with the following example:

- Address ratio: 20000 (2.0000x)
- Global ratio: 16000 (1.6000x)

```Solidity
(20000)                   // myRatio
.mul(10000)               // .mul(_percentMultiplier)
.div(16000)               // .div(globalRatio)
.add(10000)               // .add(_percentMultiplier)

= 22500                   // This is divided by 10000 = 2.2500x multiplier
```

## Address & Global FLUX Burn Ratios

There are only two view-only functions left to go through. These are the Address and Global FLUX Burn Ratios.

### getAddressRatio()

Let's see how we get the address ratio:

```Solidity
/**
 * @dev PUBLIC FACING: Get DAM/FLUX burn ratio for a specific address
 */
function getAddressRatio(address targetAddress) public view returns(uint256) {
    AddressLock storage targetAddressLock = addressLocks[targetAddress]; // Shortcut accessor
```
We accept a target address and return a number for the BURN ratio. This number can be 0 if FLUX was not burned on the targetAddress. We'll also have a shortcut accessor to `targetAddressLock`.

```Solidity
uint256 addressLockedAmount = targetAddressLock.amount;
uint256 addressBurnedAmount = targetAddressLock.burnedAmount;

// If you haven't minted or burned anything then you get the default 1x multiplier
if (addressLockedAmount == 0) {
    return 0;
}
```
We create two local variables for ease of access and ensure `addressLockedAmount` is not zero to avoid division by zero below.

Finally we get our address ratio:

```Solidity
// Burn/Lock-in ratios for both address & network
// Note that we multiply both ratios by the ratio multiplier before dividing. For tiny FLUX/DAM burn ratios.
uint256 myRatio = addressBurnedAmount.mul(_ratioMultiplier).div(addressLockedAmount);
return myRatio;
```
The formula is quite simple and `.mul(_ratioMultiplier)` ensures we handle cases where less FLUX is burned than total DAM locked-in tokens. See [Constants Section](#constants) for more details.
 
### getGlobalRatio()

Let's take a look at the final public view-only function:

```Solidity
/**
 * @dev PUBLIC FACING: Get DAM/FLUX burn ratio for global (entire network)
 */
function getGlobalRatio() public view returns(uint256) {
    // If you haven't minted or burned anything then you get the default 1x multiplier
    if (globalLockedAmount == 0) {
        return 0;
    }
```
There are no arguments, and we ensure `globalLockedAmount` is not zero to avoid division by zero. Finally the global ratio is calculated in similar fashion as the `getAddressRatio()` above:

```Solidity
// Burn/Lock-in ratios for both address & network
// Note that we multiply both ratios by the ratio multiplier before dividing. For tiny FLUX/DAM burn ratios.
uint256 globalRatio = globalBurnedAmount.mul(_ratioMultiplier).div(globalLockedAmount);
return globalRatio;
```
The formula is quite simple and `.mul(_ratioMultiplier)` ensures we handle cases where less FLUX is burned than total DAM locked-in tokens. See [Constants Section](#constants) for more details.

## Data Aggregation Helper Functions

In the contract you will also find two view-only functions:

```Solidity
/**
 * @dev PUBLIC FACING: Grab a collection of data
 * @dev ABIEncoderV2 was still experimental at time of writing this. Better approach would be to return struct.
 */
function getAddressDetails(address targetAddress) public view returns(uint256,uint256,uint256,uint256,uint256,uint256,uint256) {
    uint256 fluxBalance = balanceOf(targetAddress);
    uint256 mintAmount = getMintAmount(targetAddress, block.number);

    uint256 addressTimeMultiplier = getAddressTimeMultiplier(targetAddress);
    uint256 addressBurnMultiplier = getAddressBurnMultiplier(targetAddress);

    return (
        block.number, 
        fluxBalance, 
        mintAmount, 
        addressTimeMultiplier,
        addressBurnMultiplier,
        globalLockedAmount, 
        globalBurnedAmount);
}

/**
 * @dev PUBLIC FACING: Grab additional token details
 * @dev ABIEncoderV2 was still experimental at time of writing this. Better approach would be to return struct.
 */
function getAddressTokenDetails(address targetAddress) public view returns(uint256,bool,uint256,uint256,uint256) {
    bool isFluxOperator = IERC777(_token).isOperatorFor(address(this), targetAddress);
    uint256 damBalance = IERC777(_token).balanceOf(targetAddress);

    uint256 myRatio = getAddressRatio(targetAddress);
    uint256 globalRatio = getGlobalRatio();

    return (
        block.number, 
        isFluxOperator, 
        damBalance,
        myRatio,
        globalRatio);
}
```
These functions fetch a number of data points and consolidate them as multiple function returns. This is done to reduce number of smart contract network calls and to fetch the data we need on the Dashboard.

These functions are not used anywhere in the contract and are only there to provide a quick form of data aggregation. We do not use these functions in the Datamine Framework.

Additionally `ABIEncoderV2` was still in experimental mode so we did not use it and instead simply return multiple values. Due to the limited number of memory variables in Ethereum this data aggregation had to be split into two seprate functions.

## Additional Security Considerations (ConsenSys)

Here we'll go through a quick checklist of Best Security Practices, known attacks and various steps we took to ensure the contract is secure. Be sure to follow along: [Ethereum Smart Contract Security Best Practices
](https://consensys.github.io/smart-contract-best-practices/)

### General Philosophy

Let's go through the main points one-by-one:

#### Prepare for failure

We have a fail-safe where you can only lock-in 100 Datamine (DAM) tokens for 28 days. This will allow us to pull the smart contract and re-deploy a new version and refund any users. Depending on the serverity of the exploit it is possible the users could simply unlock their tokens from the old contract if it comes to that.

We are also launching with 50,000 Datamine (DAM) token bug bounty. With this techinical whitepaper we believe there is enough for a seasoned security expert to review.

Since we control the Datamine website & dashboard we can always release a new smart contract seamlessly so the upgrade path is clear.

#### Rollout carefully

We've been testing testing on Ropsten Testnet for almost a month with a variety of smart contract parameters. We also go through a number of attack vectors in this whitepaper so a lot of research was done on best practices.

We decided not to release the FLUX smart contract source code in Testnet due to being first-to-market and the continuous changes throughout the testnet. The source code for FLUX smart contract is planned to be launched at time of Datamine (DAM) token swap on Graviex exchange.

#### Keep contracts simple

We've split up the smart contract into multiple easy-to-understand constants, immutable variables and functions. There were some ideas that were scrapped to keep the contract as simple as possible but powerful enough to provide new features like Delegated Minting, FLUX target-burning and partial minting.

We've chosen the best security base possible at time of writing FLUX smart contract: OpenZeppelin. We've used their entire product line including unit testing and Smart Contract libraries.

We also chose to split up all logic and prefer clear variable names instead of reducing lines of code. Overdoing it on require checks in favor of improved errors instead of relying on SafeMath overflow protection in places. Everything is well documented and we go through the entire smart contract in detail in this whitepaper.

#### Stay up to date

We're using the latest Solidity v0.6.9 which was released only days prior to the mainnet launch. We've also used the latest OpenZeppelin available smart contracts.

#### Be aware of blockchain properties

All of our math is based off block numbers as opposed to timestamps to avoid [Timestamp Dependance](https://consensys.github.io/smart-contract-best-practices/recommendations/#timestamp-dependence).

We use [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#use-the-checks-effects-interactions-pattern) for all state modifications.

#### Fundamental Tradeoffs: Simplicity versus Complexity cases

Through use of clever modifiers and constants we've kept the code base clean. There is a clear sepration of header, state modification and view-only functions. 

By only having two states "locked" or "unlocked" all of the logic is greatly simplified. We've also saved a lot of unnecessary checks by limiting actions to one per block per address.

### Secure Development Recommendations

#### External Calls

##### Use caution when making external calls
We follow [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#use-the-checks-effects-interactions-pattern) pattern for any logic and they're always done at the end of the function.

##### Mark untrusted contracts
All external calls are marked with `[RE-ENTRANCY WARNING]  external call, must be at the end` to clearly mark these functions.

##### Avoid state changes after external calls
We follow [Checks-Effects-Interactions Pattern](https://solidity.readthedocs.io/en/v0.6.9/security-considerations.html#use-the-checks-effects-interactions-pattern) pattern so there are never any state changes after an external call.

##### Don't use transfer() or send().
We use the ERC-777 base functions so this security problem does not apply.

##### Handle errors in external calls
Due to ERC-777 nature all external calls revert with error message so they do not need to be handled in our case.

#### Remember that on-chain data is public

We've clearly marked our functions with `@dev PUBLIC FACING:`. The only reason variables are private is because they're immutable or constant so they can be derived from the construction of the smart contract.

#### Beware of negation of the most negative signed integer

We're using only unsigned integers and only `uint256` with all arithmetic operations performed with SafeMath.

#### Use assert(), require(), revert() properly

We validate all user input with heavy use of `require()`. No use of `assert()` but the best place for this would have been during locking & burning (to ensure the global lock-in and burn amounts are modified as expected.

#### Use modifiers only for checks

Our modifiers are read-only. Be sure to check our modifiers in [Security: Our Modifiers Section](#security-our-modifiers)

#### Beware rounding with integer division

Before division we always double check for unexpected division by zero. With `Math.min()` we also don't run into unexpected rounding issues.

### Fallback Functions

We do not have a fallback function so these types of attacks do not apply.

### Explicitly mark visibility in functions and state variables

All functions are explicitly marked with visibility

### Lock pragmas to specific compiler version

FLUX was deployed with Compiled Solidity `0.6.9` (optimized build). This number is locked in the source code.

### Use events to monitor contract activity

All state modifying functions have events associated with them. See [Events Section](#events) for more details.

### Avoid using tx.origin

We're always using `_msgSender()` (GSN version of msg.sender) to follow OpenZeppelin style of coding. There are no `tx.origin` references in the FLUX smart contract. However there are safe `tx.origin` uses in OpenZeppeling ERC-777.

### Timestamp Dependence

To keep the time math formulas basic we've based all of our math around the fact that 1 block = 15 seconds. This assumes that this number is variable and can change in the future. The goal of this is to stay away from timestamp drifting and to avoid time-based inaccuracy.
