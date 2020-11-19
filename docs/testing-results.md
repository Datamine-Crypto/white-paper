# Testing Results

At this time we chose to keep the smart contract build & test cases private. You can find results of our unit tests below:

```
  DAM Tests
    ✓ ensure proper construction parameters with 25m premine (112ms)
    ✓ ensure proper premine (59ms)
    ✓ ensure supply burns properly (146ms)

  FLUX Minting Tests
    ✓ ensure 1 DAM mints 0.00000001 FLUX per block (535ms)
    ✓ ensure minting produces expected amount of FLUX after calling it (364ms)
    ✓ ensure burn multiplier increases and decreases correctly (481ms)
    ✓ ensure burn multiplier increases and decreases correctly (155ms)
    ✓ ensure time reward at 2x and 3x is applied correctly (1158ms)

  FLUX Token Tests
    ✓ ensure proper construction parameters with 0 premined coins (39ms)
    ✓ ensure FLUX token can be operator of DAM account holder (78ms)
    ✓ ensure DAM holder can lock DAM in FLUX smart contract (106ms)
    ✓ ensure after locking-in DAM into FLUX you can unlock 100% of DAM back (337ms)
    ✓ ensure failsafe works (417ms)
    ✓ ensure FLUX can be minted after DAM lock-in to another address (318ms)
    ✓ ensure FLUX can be target-burned (300ms)


  15 passing (7s)
```
  
# Ropsten Testnet Testing period

Before Mainnet launch we've undergone a number of deployments & testing stages. Thanks to our community for participating in testing where we've had a chance to test failsafe mode and our decentralized dashboard.

You can find examples of Ropsten Testnet deployments here:
  
Datamine (DAM) Token: https://ropsten.etherscan.io/address/0x4e80bdcc3ba564bd9a548c3349d394794d28ccea

FLUX Token: https://ropsten.etherscan.io/address/0xa071b4b13d1dd313b420c7a75af7f63d2776b8d3
