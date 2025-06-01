// SPDX-License-Identifier: MIT

/*
================================================================================
|                DATAMINE TIME-IN-MARKET REWARDS (Version 2)                   |
================================================================================
|                                                                              |
|   This smart contract (v2) manages a rewards system interacting with an       |
|   ERC777-like token (fluxToken). It allows users to deposit (lock)           |
|   tokens, set rewards percentage (with a default), min block number, and     |
|   min burn amount. It triggers minting events and rewards distribution.      |
|   Users can withdraw accumulated rewards. It implements IERC777Recipient     |
|   and registers with ERC1820 for token reception.                            |
|                                                                              |
================================================================================
*/

pragma solidity ^0.8.20; // Updated Solidity version

// Import OpenZeppelin's Context contract to use _msgSender()
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/Context.sol"; // Using URL for clarity; use package manager in practice
// Import the ERC777 Recipient interface
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/token/ERC777/IERC777Recipient.sol"; // Using URL
// Import the ERC1820 Registry interface
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/v4.9.3/contracts/utils/introspection/IERC1820Registry.sol"; // Using URL

/**
 * @title IFluxToken Interface
 * @dev This interface defines the expected function(s) for the fluxToken contract.
 * @dev _targetBlock parameter in mintToAddress and getMintAmount will receive block.number from burnTokens.
 */
interface IFluxToken {
    /**
     * @dev Struct defining lock details from the FluxToken contract.
     */
    struct AddressLock {
        uint256 amount;
        uint256 burnedAmount;
        uint256 blockNumber;
        uint256 lastMintBlockNumber;
        address minterAddress;
    }

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
    function addressLocks(address account) external view returns (AddressLock memory); // Added addressLocks mapping getter
}

/**
 * @title DatamineTimRewardsVersionTwo
 * @dev Contract (v2) to interact with fluxToken, burn/mint, manage locks, and allow withdrawals/deposits.
 * @dev Implements IERC777Recipient and registers with ERC1820.
 */
contract DatamineTimRewardsVersionTwo is Context, IERC777Recipient {

    struct AddressLock {
        uint256 rewardsAmount;
        uint256 rewardsPercent; // Can be 0 to use defaultRewardsPercent
        uint256 minBlockNumber;
        bool isPaused;
        uint256 minBurnAmount;
    }

    /**
     * @dev Structure to define a burn request for batch processing.
     */
    struct BurnRequest {
        uint256 amountToBurn; // User's desired amountToBurn, can be 0
        address burnToAddress;
    }

    /**
     * @dev Structure to hold the result of a single burn operation within a batch.
     */
    struct BurnOperationResult {
        uint256 actualAmountBurned; // The actual amount that was burned
        address burnToAddress;
        uint256 amountToMint;     // The amount minted in this operation
        uint256 tipAmount;        // The tip amount calculated for this operation
    }

    /**
     * @dev Structure to hold detailed information about an address's lock and mint status.
     */
    struct AddressLockDetails {
        address targetAddress;
        uint256 amountToMint;
        uint256 rewardsAmount;
        uint256 rewardsPercent;
        uint256 minBlockNumber;
        uint256 minBurnAmount;
        bool isPaused;
        address minterAddressFromFluxToken;
    }


    // --- Events ---
    event TokensBurned(
        address indexed burnToAddress,
        address indexed caller,
        uint256 amountActuallyBurned, 
        uint256 amountToReceive, // This is actualAmountBurned + tipAmount
        uint256 currentBlock,
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
        uint256 currentBlock
    );
    event AttemptedBurnFailed(
        address indexed caller,
        uint256 amountToBurnInput, 
        address indexed burnToAddress,
        bytes errorData
    );


    // --- State Variables ---
    IFluxToken public fluxToken;
    mapping (address => AddressLock) public addressLocks; // This contract's AddressLock mapping

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
    /**
     * @notice Burns tokens for a target address.
     * @param _amountToBurnInput The desired amount to burn. If 0, it defaults to a calculated portion of `amountToMint`.
     * @param burnToAddress The address whose tokens are targeted for burning and rewards calculation.
     * @return actualAmountBurned The actual amount of tokens that were burned.
     * @return amountToMintValue The amount of tokens calculated to be minted by `fluxToken.getMintAmount` *after* the burn.
     * @return tipAmountValue The tip amount calculated for the burn operation.
     */
    function burnTokens(uint256 _amountToBurnInput, address burnToAddress) public returns (uint256 actualAmountBurned, uint256 amountToMintValue, uint256 tipAmountValue) {
        uint256 currentBlock = block.number;

        require(currentBlock > 0, "Current block must be > 0");

        AddressLock storage burnToAddressLock = addressLocks[burnToAddress];
        AddressLock storage burnFromAddressLock = addressLocks[_msgSender()];

        require(!burnToAddressLock.isPaused, "Burn address is paused");
        require(currentBlock > burnToAddressLock.minBlockNumber, "Current block must be > min lock block");

        uint256 effectiveRewardsPercent = burnToAddressLock.rewardsPercent;
        if (effectiveRewardsPercent == 0) {
            effectiveRewardsPercent = defaultRewardsPercent;
        }

        // tipAmountValue is now a return parameter, so we assign to it directly
        actualAmountBurned = _amountToBurnInput; 

        if (actualAmountBurned == 0) {
            uint256 amountToMintBeforeBurn = fluxToken.getMintAmount(burnToAddress, currentBlock);
            require(amountToMintBeforeBurn > 0, "Mint amount for automatic burn must be > 0"); // Updated comment
            
            tipAmountValue = (amountToMintBeforeBurn * effectiveRewardsPercent) / 10000; 
            
            require(tipAmountValue < amountToMintBeforeBurn, "No amount to mint after tip");
            actualAmountBurned = amountToMintBeforeBurn - tipAmountValue; 
        } else {
            tipAmountValue = (actualAmountBurned * effectiveRewardsPercent) / 10000; 
        }
        
        require(tipAmountValue > 0, "Tip amount cannot be 0"); 
        require(actualAmountBurned > 0, "Amount to burn is 0"); 
        require(actualAmountBurned >= burnToAddressLock.minBurnAmount, "Amount < min burn amount");

        require(burnFromAddressLock.rewardsAmount >= actualAmountBurned, "Caller rewards < amountToBurn");
        burnFromAddressLock.rewardsAmount -= actualAmountBurned;

        // Burning tokens from address(this)
        fluxToken.burnToAddress(burnToAddress, actualAmountBurned);
        
        // Capture contract's balance *after* burn but *before* mint
        uint256 beforeAddressThisFluxBalance = fluxToken.balanceOf(address(this));

        amountToMintValue = fluxToken.getMintAmount(burnToAddress, currentBlock); 
        require(amountToMintValue > 0, "Mint amount (post-burn) must be > 0");

        uint256 calculatedAmountToReceive = actualAmountBurned + tipAmountValue; 

        burnToAddressLock.rewardsAmount += amountToMintValue;

        require(burnToAddressLock.rewardsAmount >= calculatedAmountToReceive, "Insufficient rewards");
        burnToAddressLock.rewardsAmount -= calculatedAmountToReceive;
        burnFromAddressLock.rewardsAmount += calculatedAmountToReceive;

        fluxToken.mintToAddress(burnToAddress, address(this), currentBlock);

        uint256 addressThisFluxBalance = fluxToken.balanceOf(address(this));
        // Balance check updated: beforeAddressThisFluxBalance is now after the burn.
        require(addressThisFluxBalance == beforeAddressThisFluxBalance + amountToMintValue, "Expected contract balance mismatch");

        emit TokensBurned(
            burnToAddress,
            _msgSender(),
            actualAmountBurned,
            calculatedAmountToReceive,
            currentBlock,
            amountToMintValue
        );

        // Return values updated
    }

    function burnTokensFromAddresses(BurnRequest[] calldata requests) public returns (BurnOperationResult[] memory) {
        uint256 numRequests = requests.length;
        require(numRequests > 0, "No burn requests provided");

        BurnOperationResult[] memory results = new BurnOperationResult[](numRequests);

        for (uint256 i = 0; i < numRequests; i++) {
            BurnRequest calldata currentRequest = requests[i];
            (uint256 actualBurned, uint256 mintedAmount, uint256 tip) = burnTokens(currentRequest.amountToBurn, currentRequest.burnToAddress);

            results[i] = BurnOperationResult({
                actualAmountBurned: actualBurned, 
                burnToAddress: currentRequest.burnToAddress,
                amountToMint: mintedAmount,
                tipAmount: tip
            });
        }
        return results;
    }

    /**
     * @notice Attempts to burn tokens for multiple addresses in a batch, using try/catch.
     * @param requests An array of BurnRequest structs, each specifying an amount and address.
     * @return successfulResults An array of BurnOperationResult structs, detailing only successful operations.
     * @dev This function iterates through each request and calls burnTokens within a try/catch block.
     * @dev Failed individual burnTokens calls are skipped.
     */
    function attemptBurnTokensFromAddresses(BurnRequest[] calldata requests) public returns (BurnOperationResult[] memory) {
        uint256 numRequests = requests.length;
        require(numRequests > 0, "No burn requests provided");

        BurnOperationResult[] memory tempResults = new BurnOperationResult[](numRequests);
        uint256 successCount = 0;

        for (uint256 i = 0; i < numRequests; i++) {
            BurnRequest calldata currentRequest = requests[i];
            try this.burnTokens(currentRequest.amountToBurn, currentRequest.burnToAddress) returns (uint256 actualBurned, uint256 mintedAmount, uint256 tip) {
                tempResults[successCount] = BurnOperationResult({
                    actualAmountBurned: actualBurned,
                    burnToAddress: currentRequest.burnToAddress,
                    amountToMint: mintedAmount,
                    tipAmount: tip
                });
                successCount++;
            } catch (bytes memory errorData) {
                emit AttemptedBurnFailed(_msgSender(), currentRequest.amountToBurn, currentRequest.burnToAddress, errorData);
            }
        }

        BurnOperationResult[] memory successfulResults = new BurnOperationResult[](successCount);
        for (uint256 i = 0; i < successCount; i++) {
            successfulResults[i] = tempResults[i];
        }

        return successfulResults;
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
        require(rewardsPercent <= 10000, "Rewards % must be <= 10000"); // User can set to 0

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

    function normalMintToAddress(address targetAddress) public {
        uint256 currentBlock = block.number;
        fluxToken.mintToAddress(_msgSender(), targetAddress, currentBlock);
        emit NormalMint(_msgSender(), targetAddress, currentBlock);
    }

    /**
     * @notice Retrieves lock details and current mintable amount for a list of addresses.
     * @param addressesToQuery An array of addresses to query.
     * @return details An array of AddressLockDetails structs.
     * @return currentBlockNumber The current block number when the query was made.
     */
    function getAddressLockDetailsBatch(address[] calldata addressesToQuery) public view returns (AddressLockDetails[] memory details, uint256 currentBlockNumber) {
        uint256 numAddresses = addressesToQuery.length;
        require(numAddresses > 0, "No addresses provided to query");

        details = new AddressLockDetails[](numAddresses);
        currentBlockNumber = block.number; // Cache block.number for efficiency and return

        for (uint256 i = 0; i < numAddresses; i++) {
            address currentAddress = addressesToQuery[i];
            AddressLock storage timAddressLock = addressLocks[currentAddress]; // This contract's lock
            IFluxToken.AddressLock memory fluxLockData = fluxToken.addressLocks(currentAddress); // FluxToken's lock

            uint256 amountToMint = fluxToken.getMintAmount(currentAddress, currentBlockNumber);

            details[i] = AddressLockDetails({
                targetAddress: currentAddress,
                amountToMint: amountToMint,
                rewardsAmount: timAddressLock.rewardsAmount,
                rewardsPercent: timAddressLock.rewardsPercent,
                minBlockNumber: timAddressLock.minBlockNumber,
                minBurnAmount: timAddressLock.minBurnAmount,
                isPaused: timAddressLock.isPaused,
                minterAddressFromFluxToken: fluxLockData.minterAddress
            });
        }
        // Implicit return of details and currentBlockNumber
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
