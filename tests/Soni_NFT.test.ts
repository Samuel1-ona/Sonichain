import { describe, expect, it } from "vitest";
import { Cl, standardPrincipalCV } from "@stacks/transactions";

// // describe("Test Soni_Nft minting function", () => {



    
  it("should mint the Soni nft to the address", () => {
    const accounts = simnet.getAccounts();
    const deployer = simnet.deployer;
    const wallet = accounts.get("wallet_1")!;
    const wallet2 = accounts.get("wallet_2")!;

    const { result: mint1 } = simnet.callPublicFn(
      `${simnet.deployer}.Soni_NFT`,
      "mint",
      [standardPrincipalCV(wallet)],
      deployer
    );
    expect(mint1).toBeOk(Cl.uint(1));

    const { result: tokenId } = simnet.callReadOnlyFn(
       `${simnet.deployer}.Soni_NFT`,
      "get-last-token-id",
      [],
      wallet
    );
    expect(tokenId).toBeOk(Cl.uint(1));

    const { result: owner } = simnet.callReadOnlyFn(
      `${simnet.deployer}.Soni_NFT`,
      "get-owner",
      [Cl.uint(1)],
      wallet
    );
    expect(owner).toBeOk(Cl.some(standardPrincipalCV(wallet)));

    const { result: mint2 } = simnet.callPublicFn(
      `${simnet.deployer}.Soni_NFT`,
      "mint",
      [standardPrincipalCV(wallet)],
      deployer
    );
    expect(mint2).toBeOk(Cl.uint(2));

    const { result: tokenId2 } = simnet.callReadOnlyFn(
       `${simnet.deployer}.Soni_NFT`,
      "get-last-token-id",
      [],
      wallet
    );
    expect(tokenId2).toBeOk(Cl.uint(2));

    const { result: transfer } = simnet.callPublicFn(
       `${simnet.deployer}.Soni_NFT`,
      "transfer",
      [Cl.uint(1), standardPrincipalCV(wallet), standardPrincipalCV(wallet2)],
      wallet
    );
    expect(transfer).toBeOk(Cl.bool(true));

    const { result: burn1 } = simnet.callPublicFn(
      `${simnet.deployer}.Soni_NFT`,
      "burn",
      [Cl.uint(1)],
      deployer
    );
    expect(burn1).toBeOk(Cl.bool(true));

    const { result: owner2 } = simnet.callReadOnlyFn(
       `${simnet.deployer}.Soni_NFT`,
      "get-owner",
      [Cl.uint(1)],
      wallet
    );
    expect(owner2).toBeOk(Cl.none());
  });
