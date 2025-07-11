import Types "types";
module {
    type Account = Types.Account;
    type Arg = Types.Arg;
    type ApprovalInfo = Types.ApprovalInfo;
    
    public type TestArg = {
      testCase: TestCases;
      args: [Arg];
      caller: Principal;
      expected: ?UnifiedError;
      expectedBalances: [(Account, ?Nat, Nat)]; //account, tokenId, balance
      expectedApprovals: [(?(Account, Account), ?Nat, ApprovalInfo)];
    };

    public type Users = {
        caller: Account;
        from: Account;
        spender: Account;
        to: Account;
        admin: Account;
        unauthorisedCaller: Account;
        unmatchedSubaccount: ?Blob;
    };

    public type TestCases = {
        #Mint: MintTests;
        #Burn: BurnTests;
        #Transfer: TransferTests;
        #ApproveCollection : ApproveCollectionTests;
        #ApproveToken: ApproveTokenTests;
        #RevokeCollection: RevokeCollectionTests;
        #RevokeToken : RevokeTokenTests;
        #TransferFrom : TransferFromTests;
        #UpdateMetadata: UpdateMetadataTests;
    };

    public type BaseTests = {
      #TooOld;                       // Timestamp is older than allowed window
      #CreatedInFuture;             // Timestamp is in the future
      #AnonymousCaller;               // Caller is not authorized
      #InvalidSubaccount;          // Subaccount doesn't match ownership
      //#OverflowOrUnderflow;        // Arithmetic errors in balances
      #UnauthorizedAccess;         // Caller doesn’t own or isn’t allowed
      #WithMemo;
      #WithCreatedAtTime;
    };

    public type MintTests = {
      #BaseTests : BaseTests;
      #MintSingle;                 // Standard one-token mint
      #MintMultiple;               // Batch minting
      #MintToSelf;                 // Minting to self
      #ExceedsMax;                  // Token exceeds max supply / limits
      #MintWithoutPermission;      // Caller lacks mint role
    };

    public type BurnTests = {
      #BaseTests: BaseTests;
      #BurnOwned;                  // Valid burn
      #BurnUnownedWrongAccount;                // Caller doesn’t own token
      #BurnNonExistentToken;       // Token doesn't exist
      #BurnTwice;                  // Double burn
      #BurnTokenWithApproval;    // Burn while approved to another
    };

    public type TransferTests = {
      #BaseTests: BaseTests;
      #TransferOwnedToken;         // Normal transfer
      #TransferToSelf;             // No-op or self-transfer
      #TransferUnownedToken;       // Caller doesn't own
      #TransferNonexistentToken;   // Token ID doesn't exist
      #TransferWithApproval;       // Covered by approval
      #TransferFromSubaccount;     // Transfer from specific subaccount
      #TransferToSubaccount;       // Transfer to subaccount
      #TransferToKnownAccount;
    };

    public type TransferFromTests = {
      #BaseTests: BaseTests;
      #ValidTransferFromWithCollectionApproval;          // Covered by approval
      #ValidTransferFromWithTokenApproval;          // Covered by approval
      #TransferFromWithoutApproval;// No rights
      #TransferFromExpiredCollectionApproval;// Expired approval
      #TransferFromExpiredTokenApproval;// Expired approval
      #TransferFromWrongSpender;   // Wrong caller despite approval
      #TransferFromRevoked;        // Revoked explicitly
      #TransferFromNotOwnedByFrom;    // From address is invalid
      #TransferFromNonExistingTokenId;  // Token doesn't exist
    };

    public type ApproveCollectionTests = {
      #BaseTests: BaseTests;
      #ApproveValidSpender;        // Works correctly
      #ApproveSelf;                // Approving oneself
      #ApproveDuplicate;           // Re-approval without revoke
      #ApproveWithExpiry;          // Set expiry properly
    };

    public type RevokeCollectionTests = {
      #BaseTests: BaseTests;
      #RevokeValidSpender;         // Valid revoke
      #RevokeNonexistent;          // Revoke someone not approved
      #RevokeExpiredApproval;      // Revoke already-expired approval
    };

    public type ApproveTokenTests = {
      #BaseTests: BaseTests;
      #ApproveValidToken;          // Works normally
      #ApproveAlreadyApproved;     // Double approval
      #ApproveNonexistentToken;    // Token not found
      #ApproveUnownedToken;        // Caller doesn’t own
      #ApproveSelf;                // Self-approval
      #ApproveWithExpiry;          // Time-limited approval
    };

    public type RevokeTokenTests = {
      #BaseTests: BaseTests;
      #RevokeValidApproval;        // Standard
      #RevokeUnapproved;           // Nothing to revoke
      #RevokeNonexistentToken;     // Token not found
      #RevokeAsNonOwner;           // Not authorized
      #RevokeExpired;              // Already expired approval
    };

    public type UpdateMetadataTests = {
      #BaseTests: BaseTests;
      #UpdateExistingMetadata;     // Normal update
      #UpdateWithoutPermission;    // Not allowed to update
      #UpdateNonexistentToken;     // Token not found
      #UpdateClearsMetadata;       // Intentionally clears it
      #UpdatePartially;            // Updates some fields only
    };

    public type TestCaseSet = {
      mint: [MintTests];
      burn: [BurnTests];
      transfer: [TransferTests];
      transferFrom: [TransferFromTests];
      approveCollection: [ApproveCollectionTests];
      revokeCollection: [RevokeCollectionTests];
      approveToken: [ApproveTokenTests];
      revokeToken: [RevokeTokenTests];
      updateMetadata: [UpdateMetadataTests];
    };

    public type UnifiedError = {
      #TooOld;
      #CreatedInFuture : {ledger_time: Nat64};
      #GenericError : {error_code : Nat; message : Text};
      #GenericBatchError : {error_code : Nat; message : Text};
      #ApprovalDoesNotExist ;
      #InvalidSpender ;
      #Unauthorized ;
      #NonExistingTokenId ;
      #InvalidRecipient ;
      #Duplicate : {duplicate_of : Nat};
      #ExceedsMaxSupply;
    };

   




}