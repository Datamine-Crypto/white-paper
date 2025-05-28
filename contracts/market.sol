// SPDX-License-Identifier: MIT

/*
================================================================================
|                      DATAMINE TIME-IN-MARKET REWARDS                         |
================================================================================
|                                                                              |
|   This smart contract manages a rewards system interacting with an            |
|   ERC777-like token (fluxToken). It allows users to deposit (lock)           |
|   tokens, set rewards percentage (with a default), min block number, and     |
|   min burn amount. It triggers minting events and rewards distribution.      |
|   Users can withdraw accumulated rewards. It implements IERC777Recipient     |
|   and registers with ERC1820 for token reception.                            |
|                                                                              |
================================================================================
*/

pragma solidity ^0.8.0;

// Import OpenZeppelin's Context contract to use _msgSender()
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/Context.sol"; // Using URL for clarity; use package manager in practice
// Import the ERC777 Recipient interface
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC777/IERC777Recipient.sol"; // Using URL
// Import the ERC1820 Registry interface
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/introspection/IERC1820Registry.sol"; // Using URL

/**
 * @title IFluxToken Interface
 * @dev This interface defines the expected function(s) for the fluxToken contract.
 */
interface IFluxToken {
    function burnToAddress(address _targetAddress, uint256 _amount) external;
    function mintToAddress(address _sourceAddress, address _targetAddress, uint256 _targetBlock) external;
    function getMintAmount(address _sourceAddress, uint256 _targetBlock) external view returns (uint256);
    function send(address _to, uint256 _amount, bytes memory _data) external;
    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;
    function balanceOf(address who) external view returns (uint256);
}

/**
 * @title DatamineTimRewards
 * @dev Contract to interact with fluxToken, burn/mint, manage locks, and allow withdrawals/deposits.
 * @dev Implements IERC777Recipient and registers with ERC1820.
 */
contract DatamineTimRewards is Context, IERC777Recipient {

    struct AddressLock {
        uint256 rewardsAmount;
        uint256 rewardsPercent; // Can be 0 to use defaultRewardsPercent
        uint256 minBlockNumber;
        bool isPaused;
        uint256 minBurnAmount;
    }

    // --- Events ---
    event TokensBurned(
        address indexed burnToAddress,
        address indexed caller,
        uint256 amountToBurn,
        uint256 amountToReceive,
        uint256 targetBlock,
        uint256 amountToMint
    );
    event Withdrawn(address indexed user, uint256 amount);
    event Deposited(
        address indexed user,
        uint256 amountDeposited,
        uint256 rewardsPercent,
        uint256 totalRewardsAmount,
        uint256 minBlockNumber,
        uint256 minBurnAmount
    );
    event PausedChanged(address indexed user, bool isPaused);
    event NormalMint(
        address indexed caller,
        address indexed targetAddress,
        uint256 targetBlock
    );

    // --- State Variables ---
    IFluxToken public fluxToken;
    mapping (address => AddressLock) public addressLocks;

    uint256 public defaultRewardsPercent = 500; // Default 5.00% (500 / 10000)

    IERC1820Registry private constant _erc1820 = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
    bytes32 private constant TOKENS_RECIPIENT_INTERFACE_HASH = keccak256("ERC777TokensRecipient");

    // --- Constructor ---
    constructor(address _fluxTokenAddress) {
        require(_fluxTokenAddress != address(0), "FluxToken address cannot be zero");
        fluxToken = IFluxToken(_fluxTokenAddress);
        _erc1820.setInterfaceImplementer(address(this), TOKENS_RECIPIENT_INTERFACE_HASH, address(this));
    }

    // --- Main Functions ---
    function burnTokens(uint256 amountToBurn, uint256 amountToReceive, address burnToAddress, uint256 targetBlock) public {
        require(amountToReceive > amountToBurn, "Receive must be > burn");

        uint256 amountToMint = fluxToken.getMintAmount(burnToAddress, targetBlock);
        require(amountToMint > 0, "Mint amount must be > 0");

        require(targetBlock > 0, "Target block must be > 0");
        uint256 amountToMintPreviousBlock = fluxToken.getMintAmount(burnToAddress, targetBlock - 1);
        require(amountToMintPreviousBlock < amountToReceive, "Prev mint < receive");

        AddressLock storage burnToAddressLock = addressLocks[burnToAddress];
        AddressLock storage burnFromAddressLock = addressLocks[_msgSender()];

        require(!burnToAddressLock.isPaused, "Burn address is paused");
        require(amountToBurn >= burnToAddressLock.minBurnAmount, "Amount < min burn amount");
        require(targetBlock > burnToAddressLock.minBlockNumber, "Target block must be > min lock block");

        uint256 effectiveRewardsPercent = burnToAddressLock.rewardsPercent;
        if (effectiveRewardsPercent == 0) {
            effectiveRewardsPercent = defaultRewardsPercent;
        }
        // Since defaultRewardsPercent is 500, effectiveRewardsPercent will be > 0.
        // The deposit function ensures user-set rewardsPercent is <= 10000.

        require(amountToReceive == amountToBurn + ((amountToBurn * effectiveRewardsPercent) / 10000), "Invalid amountToReceive");

        burnToAddressLock.rewardsAmount += amountToMint;

        require(burnFromAddressLock.rewardsAmount >= amountToBurn, "Caller rewards < amountToBurn");
        burnFromAddressLock.rewardsAmount -= amountToBurn;

        require(burnToAddressLock.rewardsAmount >= amountToReceive, "Insufficient rewards");
        burnToAddressLock.rewardsAmount -= amountToReceive;
        burnFromAddressLock.rewardsAmount += amountToReceive;

        fluxToken.burnToAddress(burnToAddress, amountToBurn);
        fluxToken.mintToAddress(burnToAddress, address(this), targetBlock);

        emit TokensBurned(
            burnToAddress,
            _msgSender(),
            amountToBurn,
            amountToReceive,
            targetBlock,
            amountToMint
        );
    }

    function withdrawAll() public {
        AddressLock storage senderAddressLock = addressLocks[_msgSender()];
        uint256 amountToSend = senderAddressLock.rewardsAmount;
        require(amountToSend > 0, "No rewards to withdraw");

        senderAddressLock.rewardsAmount = 0;

        fluxToken.send(_msgSender(), amountToSend, "");

        emit Withdrawn(_msgSender(), amountToSend);
    }

    function deposit(uint256 amountToDeposit, uint256 rewardsPercent, uint256 minBlockNumber, uint256 minBurnAmount) public {
        require(amountToDeposit >= 0, "Deposit amount must be >= 0");
        // User can set rewardsPercent to 0 to use the default in burnTokens.
        require(rewardsPercent <= 10000, "Rewards % must be <= 10000");

        AddressLock storage senderAddressLock = addressLocks[_msgSender()];
        senderAddressLock.rewardsAmount += amountToDeposit;
        senderAddressLock.rewardsPercent = rewardsPercent;
        senderAddressLock.minBlockNumber = minBlockNumber;
        senderAddressLock.minBurnAmount = minBurnAmount;

        if (amountToDeposit > 0) {
            fluxToken.operatorSend(_msgSender(), address(this), amountToDeposit, "", "");
        }

        emit Deposited(
            _msgSender(),
            amountToDeposit,
            rewardsPercent,
            senderAddressLock.rewardsAmount,
            minBlockNumber,
            minBurnAmount
        );
    }

    function setPaused(bool isPaused) public {
        AddressLock storage pauseAddressLock = addressLocks[_msgSender()];
        pauseAddressLock.isPaused = isPaused;
        emit PausedChanged(_msgSender(), isPaused);
    }

    function normalMintToAddress(address targetAddress, uint256 targetBlock) public {
        fluxToken.mintToAddress(_msgSender(), targetAddress, targetBlock);
        emit NormalMint(_msgSender(), targetAddress, targetBlock);
    }

    // --- ERC777 Hook ---
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external override {
        require(amount > 0, "Must receive a positive number of tokens");
    }
}
