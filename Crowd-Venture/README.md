# DeVenture: Decentralized Venture DAO Smart Contract

## Overview

DeVenture is a fully decentralized platform for community-driven venture capital investments built on the Stacks blockchain. The platform enables democratic governance, staking rewards, and pool management capabilities through a comprehensive smart contract system.

## Key Features

- **Investment Pool Creation**: Users can create decentralized investment pools
- **Democratic Governance**: Community voting on investment proposals
- **Staking Rewards**: Earn rewards for locking your capital in pools
- **Pool Management**: Metadata customization and fund contribution tracking
- **Proposal System**: Submit, vote on, and execute investment proposals

## Contract Architecture

The DeVenture smart contract is built with the following components:

### Constants & Configuration
- Minimum contribution: 1 STX
- Proposal funding threshold: 100 STX minimum pool size
- Voting duration: ~24 hours (144 blocks)
- Initial staking reward rate: 0.005 STX per block per unit

### Data Structures
- Investment pools registry
- Individual contribution tracking
- Investment proposals
- Voting registry
- Pool descriptive metadata
- Staking registry and rewards
- Pool consolidation proposals

## Public Functions

### Pool Management

#### `create-investment-pool`
Creates a new investment pool and assigns the caller as the pool creator.

```
(create-investment-pool)
```

Returns: Pool ID (uint)

#### `contribute-to-pool`
Adds funds to an existing investment pool.

```
(contribute-to-pool pool-id contribution-amount)
```

Parameters:
- `pool-id`: ID of the target pool
- `contribution-amount`: Amount of STX to contribute (minimum 1 STX)

Returns: Boolean success indicator

#### `update-pool-metadata`
Updates descriptive information for a pool (creator only).

```
(update-pool-metadata pool-id pool-name pool-description investment-category brand-image-url)
```

Parameters:
- `pool-id`: ID of the target pool
- `pool-name`: Name of the pool (max 64 chars)
- `pool-description`: Description of the pool (max 256 chars)
- `investment-category`: Category classification (max 64 chars)
- `brand-image-url`: URL to pool branding image (max 256 chars)

Returns: Boolean success indicator

### Proposals & Voting

#### `submit-investment-proposal`
Creates a new investment proposal for a pool.

```
(submit-investment-proposal pool-id recipient-address requested-amount proposal-description)
```

Parameters:
- `pool-id`: ID of the target pool
- `recipient-address`: Principal address to receive funds if approved
- `requested-amount`: Amount of STX requested
- `proposal-description`: Description of the investment proposal (max 256 chars)

Returns: Proposal ID (uint)

#### `cast-vote-on-proposal`
Votes on an active proposal with voting power proportional to contribution.

```
(cast-vote-on-proposal pool-id proposal-id support-proposal)
```

Parameters:
- `pool-id`: ID of the target pool
- `proposal-id`: ID of the proposal
- `support-proposal`: Boolean indicating support (true) or opposition (false)

Returns: Boolean success indicator

#### `finalize-proposal`
Processes the outcome of a proposal after voting period ends.

```
(finalize-proposal pool-id proposal-id)
```

Parameters:
- `pool-id`: ID of the target pool
- `proposal-id`: ID of the proposal

Returns: Boolean indicating whether the proposal was executed (true) or rejected (false)

### Staking & Rewards

#### `update-staking-reward-rate`
Updates the reward rate for staking (admin only).

```
(update-staking-reward-rate new-rate)
```

Parameters:
- `new-rate`: New reward rate value

Returns: Boolean success indicator

#### `stake-pool-contribution`
Stakes a portion of your pool contribution to earn rewards.

```
(stake-pool-contribution pool-id stake-amount)
```

Parameters:
- `pool-id`: ID of the target pool
- `stake-amount`: Amount to stake from your contribution

Returns: Boolean success indicator

#### `claim-staking-rewards`
Claims accumulated rewards from staking.

```
(claim-staking-rewards pool-id)
```

Parameters:
- `pool-id`: ID of the target pool

Returns: STX transfer response

## Read-Only Functions

### `get-pool-details`
Retrieves investment pool information.

```
(get-pool-details pool-id)
```

### `get-investor-contribution`
Gets an investor's contribution to a specific pool.

```
(get-investor-contribution pool-id investor-address)
```

### `get-proposal-details`
Retrieves details about an investment proposal.

```
(get-proposal-details pool-id proposal-id)
```

### `get-investor-vote`
Checks an investor's vote on a specific proposal.

```
(get-investor-vote pool-id proposal-id voter-address)
```

### `get-pool-descriptive-data`
Gets metadata for a pool.

```
(get-pool-descriptive-data pool-id)
```

### `get-investor-stake`
Retrieves staking information for an investor.

```
(get-investor-stake pool-id staker-address)
```

### `calculate-pending-rewards`
Calculates pending staking rewards for the caller.

```
(calculate-pending-rewards pool-id)
```

## Error Codes

- `ERR-UNAUTHORIZED-ACCESS` (100): Caller doesn't have required permissions
- `ERR-INSUFFICIENT-BALANCE` (101): Not enough funds for operation
- `ERR-POOL-DOES-NOT-EXIST` (102): Referenced pool doesn't exist
- `ERR-INVALID-CONTRIBUTION-AMOUNT` (103): Contribution below minimum
- `ERR-DUPLICATE-VOTE` (104): User already voted on proposal
- `ERR-VOTING-PERIOD-ENDED` (105): Voting period has ended
- `ERR-BELOW-FUNDING-THRESHOLD` (106): Pool below required funding level
- `ERR-INVALID-METADATA-FORMAT` (107): Metadata format invalid
- `ERR-NO-ACTIVE-STAKE` (108): No active stake record found
- `ERR-ALREADY-STAKING` (109): User already has active stake
- `ERR-POOL-MERGER-FAILED` (110): Pool merger operation failed
- `ERR-IDENTICAL-POOL-MERGER` (111): Cannot merge pool with itself
- `ERR-STAKING-LOCK-PERIOD` (112): Staking still in lock period

## Getting Started

1. Deploy the contract to the Stacks blockchain
2. Create a new investment pool with `create-investment-pool`
3. Add descriptive metadata with `update-pool-metadata`
4. Contribute funds with `contribute-to-pool`
5. Stake funds to earn rewards with `stake-pool-contribution`
6. Submit investment proposals with `submit-investment-proposal`
7. Vote on proposals with `cast-vote-on-proposal`
8. Finalize proposals after voting period with `finalize-proposal`
9. Claim staking rewards with `claim-staking-rewards`

## Security Considerations

- Minimum contribution thresholds protect against spam
- Voting power is proportional to contributions
- Admin-only functions are protected with authorization checks
- Staking locks capital to encourage long-term commitment