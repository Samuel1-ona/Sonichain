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
   - Call `create-story(prompt)` with your story prompt (max 500 characters)
   - This creates Round 1 and opens the voting window
   - You become the story creator and can seal it later
   - Example: "A mysterious door appears in the forest..."

### Contributing to Stories

3. **Submit Voice Memos**
   - During any active round, call `submit-block(story-id, uri)`
   - Upload your voice memo to IPFS or another storage service
   - Provide the URI (max 256 characters) to your voice file
   - You can only submit once per round per story
   - Each round lasts 144 blocks (approximately 24 hours)

4. **Vote on Submissions**
   - Call `vote-block(submission-id)` to vote for your favorite submission
   - You get one vote per round per story
   - Vote for the voice memo that best continues the story
   - Voting is active during the round window

### Round Finalization

5. **Finalize Rounds**
   - After the voting window ends, anyone can call `finalize-round(story-id, round-num)`
   - The submission with the most votes wins
   - The winner receives an NFT containing the full story so far
   - A new round automatically begins (unless max blocks reached)

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
- Each round lasts 144 blocks (~24 hours)
- Stories can have up to 50 blocks maximum
- Minimum 5 blocks required to seal a story

**Rewards:**
- Round winners get NFTs containing the full story
- All contributors share the bounty pool equally when story is sealed
- Platform takes 2.5% fee from bounty on sealing

**Voting Rules:**
- One vote per user per round
- One submission per user per round
- Winner determined by highest vote count
- Ties resolved by submission order

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

Key constants (see `Sonichain.clar`):
- `VOTING-PERIOD`: blocks a round remains open
- `MIN-BLOCKS-TO-SEAL`: finalized blocks required to seal a story
- `MAX-BLOCKS-PER-STORY`: hard cap on blocks (rounds) per story
- `PLATFORM-FEE-BPS`: platform fee on sealing (taken from bounty)

### Main Flows
- Create story: initializes metadata and Round 1 with a voting window
- Submit block: adds a voice memo to the current round; one submission per user per round
- Vote block: one vote per user per round; increments submission and round tallies
- Finalize round: picks winner (highest vote-count), mints reward NFT, advances to next round
- Fund bounty: anyone can fund; disbursed on sealing
- Seal story: creator-only; validates minimum finalized blocks, charges platform fee, distributes bounty pro-rata to contributors



### Notes
- NFT minting is triggered by round finalization and requires `Soni_NFT` to authorize calls from the `Sonichain` contract.
- Sealing distributes bounty equally per finalized block.
