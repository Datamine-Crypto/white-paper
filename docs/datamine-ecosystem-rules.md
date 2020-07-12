# Datamine FLUX Economic Model - Breakdown of Smart Contracts

## Precursor

Here we will describe the inner workings of the smart contract and lay it out on a step-by-step basis. This page does not describe WHY our economic system works but HOW it works behind the scenes. This page is not going to include various security and exception checks in place to ensure there is even and fair distribtuion of FLUX.

## Assumptions

- Block = 15 Seconds = 1 Ethereum Block (the whole ecosystem adjusts as block times change)

## Ecosystem Rules

### DAM Lock-in

#### When DAM tokens are locked-in the following is true:

- Your Datamine (DAM) tokens are sent to the smart contract and DAM balance is subtracted from your address
- Your total burned FLUX is ADDED to the global burned FLUX pool
- Your total DAM lock-in is ADDED to the global locked-in DAM pool

#### When DAM tokens are unlocked the following is true:

- Your Datamine (DAM) tokens are sent back from the smart contract and DAM balance is added to your address
- Your total burned FLUX is REMOVED from the global burned FLUX pool
- Your total DAM lock-in is REMOVED from the global locked-in DAM pool

#### When you mint FLUX the following is true:

- Your unminted amount is calculated (using the section below) and added to your address
- You can mint FLUX at any time on-demand as long as the unminted amount is >0
- Your unminted amount is reset to 0

## FLUX minting formula

**Unminted FLUX Amount** = (((0.00000001 * (DAM tokens Locked-in) * Unminted Blocks * Burn Bonus Multiplier ) / 10000) * Time bonus multiplier) / 10000

### Burn Bonus Multiplier

**My Ratio** = (My total burned FLUX for this address * 10000) / (My total locked-in DAM tokens)

**Global Ratio** = (Worldwide total burned FLUX for this address * 10000) / (Worldwide total locked-in DAM tokens)

**Bonus Multiplier** = Math.min(100000, ((MyRatio * 10000) / (Global Ratio)) + 10000)

### Time Bonus Multiplier

**Time Multiplier** = Math.min(30000, ((Unminted Amount * 20000) / 161280) + 10000)

\* First 161280 DAM lock-in blocks DO NOT COUNT towards time bonus


## Burning FLUX

When you burn FLUX to a specific address the following happens:

- Address burned amount goes up by the amount burned
- Global burned pool amount goes up by the amount burned
 to a specific address the following happens:

- Address burned amount goes up by the amount burned
- Global burned pool amount goes up by the amount burned


