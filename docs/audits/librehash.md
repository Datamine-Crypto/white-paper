# Security Audit - Librehash

## Preface

**YOUR FUNDS ARE SAFE AND THERE IS NO EXPLOIT WITHIN THE LOCK-IN MECHANISM**

The core exploit that this audit mentions was already outlined in our whitepaper: [Note on EIP20 API Approve / TransferFrom multiple withdrawal attack
](docs/datamine-smart-contracts.md#note-on-eip20-api-approve--transferfrom-multiple-withdrawal-attack)

Since this is a well-known ERC-20 bug additional security measures must be taken in consideration when using `approve()` and `transferFrom()` functions in any ERC-20 smart contract.

## Does this mean there is an exploit in DAM/FLUX smart contracts?

In DeFi fashion, our ERC-777 smart contracts are backwards-compatible with ERC-20. And as such implement the `approve()` function as per ERC-20 standard. This allows other DeFi contracts to interface with ours (ex: Uniswap).

We're using OpenZeppelin implementation which is considered to be one of the most secure libraries for Smart Contracts.

There is nothing to worry about but you should be aware that poorly coded smart contracts that use DAM/FLUX tokens (or most ERC-20 tokens) might be vulnerable to the above exploit.

The core FLUX contract does not use the mentioned methods so there is no attack vector for locked-in DAM funds. 

## Why can't DAM lock-in funds be "drained" from the FLUX smart contract?

First of all we don't use either `approve()` or `transferFrom()` within the smart contract logic. These functions are only there for ERC-20 backwards-compatability for external use.

We instead use the new and much more secure ERC-777 functions such as `operatorSend()` and `send()`. The whole allowance/approval portion is separate from core FLUX logic.

# Points Made In Audit

## **WRONG**: "The Entire 'Foundational' Code for the Smart Contract Was Plagiarized From 'OpenZeppelin'"

Not quite sure what is meant but this, our entire code base is using the OpenZeppelin ERC-777 secure libraries. We make this clear throughout the website and whitepaper as it's at heart of everything in Datamine.

## **WRONG**: "Finding the Original Smart Contract Code From the Plagiarized Re-purposed Flux Contract Deployment"

We've even made the whole source code public! The base ERC-777 library is not a secret and is publicly available from OpenZeppelin Website: [https://docs.openzeppelin.com/contracts/2.x/api/token/erc777](https://docs.openzeppelin.com/contracts/2.x/api/token/erc777)

## **WRONG**: "OpenZeppelin Documentation Explains Interoperability Between the ERC20 and ERC777 Token Standardizations"

As the auditor mentions "Notice the mention of the 'approve' function in the excerpt above.". But the context is "no need to do `approve` and `transferFrom` which we don't use and instead use the ERC-777 operators.

## **WRONG**: "Embarrassing Oversight by Flux"

The auditor misreads the documentation warning which clearly states that CALLING the `approve()` function is dangerous. The warning is clear to anyone using the `approve()` function and should not be handled by the token (for backwards-compatability with ERC-20)

Instead they misinterpret this as the basis of "exploit" for the whole audit.

## **WRONG**: "There Are Proposed Mitigations"

The auditor mistakenly says that `decreaseAllowance()` and `increaseAllowance()` would mitigate the attack. The mistake in this approach is that  the original `approve()` function is still there which still has the original exploit.

Because these are NON-STANDARD ERC-20 functions we can't expect other contracts to know that they're in our contract so these can be hand rolled by any other contract trying to utilize DAM/FLUX tokens.

## **WRONG**: "Flux Did Not Employ Any of the Proposed Mitigations (Unsurprisingly)"

The ERC-777 functions we're using are safe and are not exploitable with this form of attack. So the best way to "fix it" as in our approach is to not use them at all!

## **WRONG**: "Whitepaper Blasts the Use of the 'Approve' Function ERC20 Smart Contracts"

The whitepaper in question is this: [https://arxiv.org/pdf/1907.00903.pdf](https://arxiv.org/pdf/1907.00903.pdf)

They provide a number of attempts to fix the exploit but the conclusion is **THERE IS NO WAY TO FIX THIS TYPE OF EXPLOIT WITHOUT BREAKING ERC-20 STANDARD**

In the two proposals that is mentioned for the fix the whitepaper can only fix `approve()` (by breaking ERC-20 standard)

Another approach reads as follows "Our solution, which is compliant with a careful reading of ERC20, **is to interpret allowance as a ‘global’ or ‘lifetime’ allowance value, instead of the amount allowed at the specific time of invocation**"

We can't have a DeFi token where things are left up to "interpretations". There will be various suggestions on fixes but until it's part of the ERC-20 standard we can't leave things up to "interpretation".

As per EIP-20 standard, "To prevent attack vectors like the one described here and discussed here, clients SHOULD make sure to create **user interfaces** in such a way that they set the allowance first to 0 before setting it to another value for the same spender. **THOUGH The contract itself shouldn’t enforce it, to allow backwards compatibility with contracts deployed before**".

# Conclusion

In conclusion, this is a low effort audit that makes wild accusations, assumptions and personal threats. In the small blockchain space these types of auditors are frowned upon and could do with more professionalism.

We've sent this reply to the auditor and will update this response as deemed necessary. Almost every point made in the audit is wrong and was taken out of context from lack of basic EIP-20 / ERC-777 understanding.

Perhaps if we used `transferFrom()` internally for FLUX movements we would've had to deal with this form of exploit but because we chose the newer and more secure ERC-777 base these attacks are not applicable.

There is no backward compatible resolution to this problem. If you are interested on reading up more on developments of this general ERC-20 issue be sure to check out  [EIP-738](https://github.com/ethereum/EIPs/issues/738)




