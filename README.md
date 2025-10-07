## Sonichain — Collaborative Voice Story Protocol

Sonichain is a decentralized story-building game on Stacks where players contribute short voice memos to co-create evolving narrative chains. Rounds determine which contribution becomes canon, and contributors are rewarded with NFTs and an optional bounty pool once the story is sealed.

### High-level Gameplay
1. Create a story with a prompt. The protocol opens Round 1 for voting.
2. Players submit voice memos (URIs, e.g., IPFS) during the round.
3. Players vote once per round. After the voting window ends, anyone may finalize the round.
4. Finalizing selects the winning submission (highest votes), mints an NFT to the winner, and advances to the next round.
5. After at least MIN blocks have been finalized, the creator can seal the story to distribute the bounty and end the game.

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
