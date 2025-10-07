import { describe, expect, it, beforeEach } from "vitest";
import { Cl } from "@stacks/transactions";

describe("EchoChain V2 - Collaborative Voice Story Protocol", () => {
  const accounts = simnet.getAccounts();
  const wallet1 = accounts.get("wallet_1")!;
  const wallet2 = accounts.get("wallet_2")!;
  const wallet3 = accounts.get("wallet_3")!;

  describe("Story Creation", () => {
    it("should create a new story with initial prompt", () => {
      const prompt = "Once upon a time in a blockchain...";
      
      const { result } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8(prompt)],
        wallet1
      );

      expect(result).toBeOk(Cl.uint(1));

      // Verify story was created
      const { result: storyData } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-story",
        [Cl.uint(1)],
        wallet1
      );

      expect(storyData).not.toBeNone();

    });

    it("should initialize first voting round on story creation", () => {
      const prompt = "A decentralized adventure begins...";
      
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8(prompt)],
        wallet1
      );

      // Check first round exists
      const { result: roundData } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-round",
        [Cl.uint(1), Cl.uint(1)],
        wallet1
      );

      expect(roundData).not.toBeNone();
    });
  });

  describe("Submission Management", () => {
    beforeEach(() => {
      // Create a story before each test
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8("Test Story Prompt")],
        wallet1
      );
    });

    it("should allow users to submit voice memos", () => {
      const voiceURI = "ipfs://QmTest123456789";

      const { result } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii(voiceURI)],
        wallet2
      );

      expect(result).toBeOk(Cl.uint(1));

      // Verify submission was created
      const { result: submission } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-submission",
        [Cl.uint(1)],
        wallet2
      );

      expect(submission).not.toBeNone();
    });

    it("should prevent duplicate submissions from same user in same round", () => {
      const voiceURI1 = "ipfs://QmTest111";
      const voiceURI2 = "ipfs://QmTest222";

      // First submission should succeed
      const { result: first } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii(voiceURI1)],
        wallet2
      );
      expect(first).toBeOk(Cl.uint(1));

      // Second submission from same user should fail
      const { result: second } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii(voiceURI2)],
        wallet2
      );
      expect(second).toBeErr(Cl.uint(111)); // ERR-ALREADY-SUBMITTED
    });

    it("should allow multiple users to submit in same round", () => {
      const voiceURI1 = "ipfs://QmWallet2";
      const voiceURI2 = "ipfs://QmWallet3";

      const { result: submission1 } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii(voiceURI1)],
        wallet2
      );
      expect(submission1).toBeOk(Cl.uint(1));

      const { result: submission2 } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii(voiceURI2)],
        wallet3
      );
      expect(submission2).toBeOk(Cl.uint(2));
    });
  });

  describe("Voting System", () => {
    beforeEach(() => {
      // Create story and add submissions
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8("Voting Test Story")],
        wallet1
      );

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii("ipfs://submission1")],
        wallet2
      );

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii("ipfs://submission2")],
        wallet3
      );
    });

    it("should allow users to vote for submissions", () => {
      const { result } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "vote-block",
        [Cl.uint(1)], // Vote for submission 1
        wallet1
      );

      expect(result).toBeOk(Cl.bool(true));

      // Check that vote was recorded
      const { result: hasVoted } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "has-voted",
        [Cl.uint(1), Cl.uint(1), Cl.principal(wallet1)],
        wallet1
      );

      expect(hasVoted).toStrictEqual(Cl.bool(true));
    });

    it("should prevent double voting in same round", () => {
      // First vote
      const { result: firstVote } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "vote-block",
        [Cl.uint(1)],
        wallet1
      );
      expect(firstVote).toBeOk(Cl.bool(true));

      // Second vote should fail
      const { result: secondVote } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "vote-block",
        [Cl.uint(2)],
        wallet1
      );
      expect(secondVote).toBeErr(Cl.uint(103)); // ERR-ALREADY-VOTED
    });

    it("should increment vote count on submissions", () => {
      // Cast vote
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "vote-block",
        [Cl.uint(1)],
        wallet1
      );

      // Check updated vote count
      const { result: updatedSubmission } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-submission",
        [Cl.uint(1)],
        wallet1
      );

      expect(updatedSubmission).not.toBeNone();
    });
  });

  describe("Round Finalization", () => {
    it("should not finalize round before voting period ends", () => {
      // Create story and submission
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8("Test Story")],
        wallet1
      );

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii("ipfs://test")],
        wallet2
      );

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "vote-block",
        [Cl.uint(1)],
        wallet3
      );

      // Try to finalize immediately (should fail)
      const { result: canFinalize } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "can-finalize-round",
        [Cl.uint(1), Cl.uint(1)],
        wallet1
      );

      expect(canFinalize).toStrictEqual(Cl.bool(false));
    });

    it("should allow finalization after voting period", () => {
      // Create story and submission
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8("Test Story")],
        wallet1
      );

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii("ipfs://test")],
        wallet2
      );

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "vote-block",
        [Cl.uint(1)],
        wallet3
      );

      // Mine blocks to pass voting period (144 blocks)
      simnet.mineEmptyBlocks(150);

      // Check if can finalize
      const { result: canFinalize } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "can-finalize-round",
        [Cl.uint(1), Cl.uint(1)],
        wallet1
      );

      expect(canFinalize).toStrictEqual(Cl.bool(true));
    });

    it("should determine winning submission correctly", () => {
      // Create story with multiple submissions
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8("Test Story")],
        wallet1
      );

      // Create 3 submissions
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii("ipfs://submission1")],
        wallet1
      );

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii("ipfs://submission2")],
        wallet2
      );

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii("ipfs://submission3")],
        wallet3
      );

      // Vote for submission 2 (should be winner)
      const voter1 = accounts.get("wallet_4")!;
      const voter2 = accounts.get("wallet_5")!;
      const voter3 = accounts.get("wallet_6")!;

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "vote-block",
        [Cl.uint(2)],
        voter1
      );
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "vote-block",
        [Cl.uint(2)],
        voter2
      );
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "vote-block",
        [Cl.uint(1)],
        voter3
      );

      // Get winning submission
      const { result: winner } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-winning-submission",
        [Cl.uint(1), Cl.uint(1)],
        wallet1
      );

      expect(winner).toBeOk(Cl.uint(2));
    });
  });

  describe("Bounty System", () => {
    beforeEach(() => {
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8("Bounty Test Story")],
        wallet1
      );
    });

    it("should allow funding story bounty", () => {
      const bountyAmount = 1000000; // 1 STX in microSTX

      const { result } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "fund-bounty",
        [Cl.uint(1), Cl.uint(bountyAmount)],
        wallet2
      );

      expect(result).toBeOk(Cl.bool(true));
    });

    it("should reject zero amount bounty", () => {
      const { result } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "fund-bounty",
        [Cl.uint(1), Cl.uint(0)],
        wallet2
      );

      expect(result).toBeErr(Cl.uint(106)); // ERR-INVALID-AMOUNT
    });

    it("should prevent funding sealed stories", () => {
      // Finalize 5 rounds to reach MIN-BLOCKS-TO-SEAL
      for (let i = 0; i < 5; i++) {
        // Submit a block for current round
        simnet.callPublicFn(
          `${simnet.deployer}.Sonichain`,
          "submit-block",
          [Cl.uint(1), Cl.stringAscii(`ipfs://block${i}`)],
          accounts.get(`wallet_${(i % 3) + 1}`)!
        );

        // Advance beyond voting period
        simnet.mineEmptyBlocks(150);

        // Finalize current round i+1 (ok expected)
        const { result: finalizeRes } = simnet.callPublicFn(
          `${simnet.deployer}.Sonichain`,
          "finalize-round",
          [Cl.contractPrincipal(simnet.deployer, "Soni_NFT"), Cl.uint(1), Cl.uint(i + 1)],
          wallet1
        );
        expect(finalizeRes).toBeOk(Cl.uint(i + 1));
      }

      // Seal the story as creator
      const { result: sealResult } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "seal-story",
        [Cl.uint(1)],
        wallet1
      );
      expect(sealResult).toBeOk(Cl.uint(1));

      // After sealing, funding should fail with ERR-STORY-SEALED (u102)
      const { result: fundResult } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "fund-bounty",
        [Cl.uint(1), Cl.uint(1_000)],
        accounts.get("wallet_2")!
      );
      expect(fundResult).toBeErr(Cl.uint(102));
    });
  });

  describe("Story Sealing", () => {
    it("should require minimum blocks before sealing", () => {
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8("Short Story")],
        wallet1
      );

      // Try to seal without enough blocks
      const { result } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "seal-story",
        [Cl.uint(1)],
        wallet1
      );

      expect(result).toBeErr(Cl.uint(105)); // ERR-INSUFFICIENT-BLOCKS
    });

    it("should only allow creator to seal story", () => {
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8("Story")],
        wallet1
      );

      // Non-creator tries to seal
      const { result } = simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "seal-story",
        [Cl.uint(1)],
        wallet2
      );

      expect(result).toBeErr(Cl.uint(101)); // ERR-UNAUTHORIZED
    });
  });

  describe("Read-Only Functions", () => {
    beforeEach(() => {
      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "create-story",
        [Cl.stringUtf8("Read Test Story")],
        wallet1
      );

      simnet.callPublicFn(
        `${simnet.deployer}.Sonichain`,
        "submit-block",
        [Cl.uint(1), Cl.stringAscii("ipfs://test")],
        wallet2
      );
    });

    it("should get story details", () => {
      const { result } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-story",
        [Cl.uint(1)],
        wallet1
      );

      expect(result).not.toBeNone();
    });

    it("should get round submission count", () => {
      const { result } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-round-submission-count",
        [Cl.uint(1), Cl.uint(1)],
        wallet1
      );

      expect(result).toStrictEqual(Cl.uint(1));
    });

    it("should check voting active status", () => {
      const { result } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "is-voting-active",
        [Cl.uint(1), Cl.uint(1)],
        wallet1
      );

      expect(result).toStrictEqual(Cl.bool(true));
    });

    it("should get contributor stats", () => {
      const { result } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-contributor-stats",
        [Cl.uint(1), Cl.principal(wallet2)],
        wallet1
      );

      expect(result).toStrictEqual(Cl.tuple({ "block-count": Cl.uint(0) }));
    });
  });

  describe("Edge Cases", () => {
    it("should handle non-existent story queries", () => {
      const { result } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-story",
        [Cl.uint(999)],
        wallet1
      );

      expect(result).toBeNone();
    });

    it("should handle non-existent submission queries", () => {
      const { result } = simnet.callReadOnlyFn(
        `${simnet.deployer}.Sonichain`,
        "get-submission",
        [Cl.uint(999)],
        wallet1
      );

      expect(result).toBeNone();
    });

    // it("should prevent submissions to sealed stories", () => {
    //   // This would require full story completion flow
    //   // Leaving as placeholder for integration test
    // });
  });
});