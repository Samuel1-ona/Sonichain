## Sonichain — Collaborative Voice Story Protocol

Sonichain is a decentralized story-building game on Stacks where players contribute short voice memos to co-create evolving narrative chains. Rounds determine which contribution becomes canon, and contributors are rewarded with NFTs and an optional bounty pool once the story is sealed.

## How to Play Sonichain

Sonichain is a collaborative storytelling game where players contribute voice memos to build evolving narrative chains. Here's how to get started and play:

### Getting Started

1. **Register Your Username**
   - Call `register-user(username)` to create your unique identity
   - Choose a username (max 50 characters) that hasn't been taken
   - This links your wallet address to a memorable username

### Creating a Story

2. **Start a New Story**
   - Call `create-story(prompt, init-time, voting-window)`
   - `init-time` is an epoch timestamp (uint) for when Round 1 starts
   - `voting-window` is the per-round duration in seconds (epoch delta)
   - This creates Round 1 with `start-time = init-time` and `end-time = init-time + voting-window`
   - You become the story creator and can seal it later
   - Example: "A mysterious door appears in the forest..."

### Contributing to Stories

3. **Submit Voice Memos**
   - During any active round, call `submit-block(story-id, uri, now)`
   - Upload your voice memo to IPFS or another storage service
   - Provide the URI (max 256 characters) to your voice file
   - You can only submit once per round per story
   - `now` is an epoch timestamp (uint) used for timing validation

4. **Vote on Submissions**
   - Call `vote-block(submission-id)` to vote for your favorite submission
   - You get one vote per round per story
   - Vote for the voice memo that best continues the story
   - Voting is active during the round window

### Round Finalization

5. **Finalize Rounds**
   - After the voting window ends, anyone can call `finalize-round(story-id, round-num, now)`
   - `now` is an epoch timestamp (must be > current round's `end-time`)
   - The submission with the most votes wins
   - The winner receives an NFT containing the full story so far
   - A new round automatically begins (unless max blocks reached) with
     `start-time = prior end-time` and `end-time = prior end-time + voting-window`

### Story Completion

6. **Fund Bounties (Optional)**
   - Anyone can call `fund-bounty(story-id, amount)` to add STX to the reward pool
   - This incentivizes participation and rewards contributors
   - Funds are held by the contract until story sealing

7. **Seal the Story**
   - Only the story creator can call `seal-story(story-id)`
   - Requires at least 5 finalized blocks
   - Distributes bounty equally among all contributors
   - Takes a 2.5% platform fee
   - Marks the story as complete and immutable

### Game Mechanics

**Timing:**
- Rounds use epoch-based timing (no dependency on block height)
- Round 1: `[init-time, init-time + voting-window]`
- Round N+1: `[prev end-time, prev end-time + voting-window]`
- Minimum 5 finalized rounds required to seal a story

**Rewards:**
- Round winners get NFTs containing the full story
- All contributors share the bounty pool equally when story is sealed
- Platform takes 2.5% fee from bounty on sealing

**Voting Rules:**
- One vote per user per round
- One submission per user per round
- Winner determined by highest vote count
- Ties resolved by submission order
 - Per-round submission cap: 10 submissions
 - Per-story round cap: 10 rounds

### Example Game Flow

1. Alice creates story: "A robot discovers emotions"
2. Round 1 opens - players submit voice memos continuing the story
3. Players vote on submissions
4. Bob's submission wins - he gets an NFT and Round 2 begins
5. Process repeats for multiple rounds
6. Alice seals the story after 8 rounds
7. All contributors receive equal shares of the bounty pool

### Core Contracts
- `contracts/Sonichain.clar`: Core protocol (stories, rounds, submissions, votes, bounty, sealing)
- `contracts/Soni_NFT.clar`: Minimal NFT used to reward round winners on finalization (mint the whole story to the winner)

Key parameters and limits (see `Sonichain.clar`):
- `MIN-BLOCKS-TO-SEAL`: finalized rounds required to seal a story (u5)
- `MAX-BLOCKS-PER-STORY`: hard cap on rounds per story (u50 for legacy, flow stops at 10)
- `MAX-ROUNDS-PER-STORY`: enforced cap (u10)
- `MAX-SUBMISSIONS-PER-ROUND`: enforced cap (u10)
- `PLATFORM-FEE-BPS`: platform fee on sealing (u250)

### Main Flows
- Create story: `create-story(prompt, init-time, voting-window)` → initializes metadata and Round 1 with epoch times
- Submit block: `submit-block(story-id, uri, now)` → adds a voice memo to the current round (≤10 submissions/round)
- Vote block: `vote-block(submission-id)` → one vote per user per round; increments submission and round tallies
- Finalize round: `finalize-round(story-id, round-num, now)` → picks winner (highest vote-count), mints reward NFT, advances to next round (≤10 rounds/story)
- Fund bounty: `fund-bounty(story-id, amount)` → anyone can fund; disbursed on sealing
- Seal story: `seal-story(story-id)` → creator-only; validates minimum finalized blocks, charges platform fee, distributes bounty equally per finalized block



### Notes
- NFT minting is triggered by round finalization and requires `Soni_NFT` to authorize calls from the `Sonichain` contract.
- Sealing distributes bounty equally per finalized block.
- Read-only helpers:
  - `list-rounds(story-id)` → up to 10 round numbers
  - `list-round-submissions(story-id, round-num)` → up to 10 submission IDs
  - `is-voting-active-at(story-id, round-num, now)`
  - `can-finalize-round-at(story-id, round-num, now)`
