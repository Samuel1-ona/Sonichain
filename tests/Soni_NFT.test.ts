import { describe, expect, it } from "vitest";
import { Cl, standardPrincipalCV } from "@stacks/transactions";

// // describe("Test Soni_Nft minting function", () => {



    
  it("should mint via Sonichain finalize-round (contract-caller)", () => {
    const accounts = simnet.getAccounts();
    const deployer = simnet.deployer;
    const wallet1 = accounts.get("wallet_1")!;

    const initTime = 1_700_000_000;
    const votingWindow = 600;
    const withinRound = initTime + 1;
    const afterRound = initTime + votingWindow + 1;
    const uri = "ipfs://token-1";

    // 1) Create story
    const { result: createRes } = simnet.callPublicFn(
      `${deployer}.Sonichain`,
      "create-story",
      [Cl.stringUtf8("Test story"), Cl.uint(initTime), Cl.uint(votingWindow)],
      wallet1
    );
    expect(createRes).toBeOk(Cl.uint(1));

    // 2) Submit one block in round 1
    const { result: submitRes } = simnet.callPublicFn(
      `${deployer}.Sonichain`,
      "submit-block",
      [Cl.uint(1), Cl.stringAscii(uri), Cl.uint(withinRound)],
      wallet1
    );
    expect(submitRes).toBeOk(Cl.uint(1));

    // 3) Finalize round 1 after end-time (mints NFT via Sonichain -> Soni_NFT)
    const { result: finalizeRes } = simnet.callPublicFn(
      `${deployer}.Sonichain`,
      "finalize-round",
      [Cl.uint(1), Cl.uint(1), Cl.uint(afterRound)],
      wallet1
    );
    expect(finalizeRes).toBeOk(Cl.uint(1));

    // 4) Validate NFT state
    const { result: tokenId } = simnet.callReadOnlyFn(
      `${deployer}.Soni_NFT`,
      "get-last-token-id",
      [],
      wallet1
    );
    expect(tokenId).toBeOk(Cl.uint(1));

    const { result: owner } = simnet.callReadOnlyFn(
      `${deployer}.Soni_NFT`,
      "get-owner",
      [Cl.uint(1)],
      wallet1
    );
    expect(owner).toBeOk(Cl.some(standardPrincipalCV(wallet1)));

    const { result: uri1 } = simnet.callReadOnlyFn(
      `${deployer}.Soni_NFT`,
      "get-token-uri",
      [Cl.uint(1)],
      wallet1
    );
    expect(uri1).toBeOk(Cl.some(Cl.stringAscii(uri)));
  });
