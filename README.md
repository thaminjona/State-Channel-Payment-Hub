# 🚀 State Channel Payment Hub

> ⚡ Lightning-fast off-chain microtransactions with on-chain finality on Stacks blockchain

## 📋 Overview

The State Channel Payment Hub enables **instant, low-cost microtransactions** between two parties by keeping most activity off-chain while maintaining security through periodic on-chain settlement. Perfect for high-frequency payments, gaming, streaming, and micropayments! 💰

## ✨ Key Features

- 🔐 **Secure Off-Chain Transactions** - Conduct unlimited microtransactions without blockchain fees
- ⏱️ **Instant Settlement** - No waiting for block confirmations during normal operation  
- 🛡️ **Dispute Resolution** - Challenge mechanism protects against fraud
- 💎 **Cooperative Closing** - Mutually agreed channel closure with immediate settlement
- 🚨 **Emergency Exit** - Unilateral channel closure with challenge period for security

## 🏗️ How It Works

1. **Open Channel** 🎯 - Two parties deposit STX to create a payment channel
2. **Transact Off-Chain** ⚡ - Exchange signed state updates for instant payments
3. **Settle Periodically** 📈 - Update on-chain state with latest balances
4. **Close Channel** 🔒 - Cooperatively close or use challenge mechanism

## 🛠️ Usage Instructions

### Opening a Payment Channel

```clarity
;; Participant A opens channel with Participant B
(contract-call? .state-channel-payment-hub open-channel 'SP2PARTICIPANT-B-ADDRESS u1000000)
```

### Adding Funds to Channel

```clarity
;; Add 500,000 microSTX to channel #1
(contract-call? .state-channel-payment-hub deposit-to-channel u1 u500000)
```

### Updating Channel State

```clarity
;; Update balances (only by channel participants)
(contract-call? .state-channel-payment-hub update-channel-state 
    u1           ;; channel-id
    u800000      ;; new-balance-a  
    u700000      ;; new-balance-b
    u5           ;; new-nonce
)
```

### Cooperative Channel Closure

```clarity
;; Close channel with mutual agreement
(contract-call? .state-channel-payment-hub cooperative-close
    u1           ;; channel-id
    u800000      ;; final-balance-a
    u700000      ;; final-balance-b  
)
```

### Challenge Mechanism (Dispute Resolution)

```clarity
;; Initiate challenge period
(contract-call? .state-channel-payment-hub initiate-challenge u1)

;; Respond to challenge with latest state
(contract-call? .state-channel-payment-hub respond-to-challenge 
    u1 u800000 u700000 u10)

;; Finalize after challenge period expires
(contract-call? .state-channel-payment-hub finalize-challenge u1)
```

## 📊 Read-Only Functions

```clarity
;; Get channel information
(contract-call? .state-channel-payment-hub get-channel u1)

;; Check participant deposits  
(contract-call? .state-channel-payment-hub get-channel-deposit u1 'SP2PARTICIPANT-ADDRESS)

;; View challenge status
(contract-call? .state-channel-payment-hub get-challenge-status u1)

;; Verify if user is channel participant
(contract-call? .state-channel-payment-hub is-participant u1 'SP2USER-ADDRESS)
```

## 🔧 Development Setup

### Prerequisites
- [Clarinet](https://docs.hiro.so/clarinet) installed
- Node.js (for testing)
- Stacks wallet for deployment

### Local Development

```bash
# Clone the repository
git clone <repo-url>
cd State-Channel-Payment-Hub

# Check contract syntax
clarinet check

# Run tests  
clarinet test

# Start local development environment
clarinet integrate
```

### Testing

```bash
# Run all tests
npm test

# Run specific test files
npm run test:channels
npm run test:disputes
```

## 🏛️ Contract Architecture

- **Channel Management** - Open, deposit, and track channel states
- **State Updates** - Off-chain signed state transitions  
- **Dispute Resolution** - Challenge/response mechanism with timelock
- **Settlement** - Cooperative and unilateral channel closure
- **Security** - Signature verification and balance validation

## 🔐 Security Features  

- ✅ **Access Control** - Only channel participants can update state
- ✅ **Nonce Protection** - Prevents replay attacks with increasing nonces  
- ✅ **Balance Validation** - Ensures total balances remain consistent
- ✅ **Challenge Period** - 144-block dispute window for security

## 📚 Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 100 | `ERR_UNAUTHORIZED` | Caller not authorized for this action |
| 101 | `ERR_CHANNEL_NOT_FOUND` | Channel doesn't exist |
| 102 | `ERR_CHANNEL_CLOSED` | Channel already closed |
| 103 | `ERR_INVALID_SIGNATURE` | Invalid or missing signature |
| 104 | `ERR_INSUFFICIENT_BALANCE` | Insufficient funds for operation |
| 105 | `ERR_INVALID_NONCE` | Invalid nonce (must be increasing) |
| 106 | `ERR_CHALLENGE_PERIOD_ACTIVE` | Challenge period currently active |
| 107 | `ERR_CHALLENGE_PERIOD_EXPIRED` | Challenge period has expired |
| 108 | `ERR_INVALID_PARTICIPANT` | Invalid channel participant |
| 109 | `ERR_CHANNEL_ALREADY_EXISTS` | Channel already exists |

## 🤝 Contributing

Contributions welcome! Please feel free to submit a Pull Request. 

## 📄 License

MIT License - see LICENSE file for details.

---

**Built with ❤️ for the Stacks ecosystem** 🟠
