import Types "types";
import TestTypes "testTypes";
import Utils "utils";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import HashMap "mo:base/HashMap";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";
import Nat "mo:base/Nat";
import CertTree "mo:ic-certification/CertTree";
import Array "mo:base/Array";
import Debug "mo:base/Debug";
import ICRC7 "icrc7";
import ICRC37 "icrc37";
import Option "mo:base/Option";

module {
    type Arg = Types.Arg;
    type MintArg = Types.MintArg;
    type BurnArg = Types.BurnArg;
    type TransferArg = Types.TransferArg;
    type ApproveCollectionArg = Types.ApproveCollectionArg;
    type ApproveTokenArg = Types.ApproveTokenArg;
    type RevokeCollectionApprovalArg = Types.RevokeCollectionApprovalArg;
    type RevokeTokenApprovalArg = Types.RevokeTokenApprovalArg;
    type TransferFromArg = Types.TransferFromArg;
    type TokenMetadataArg = Types.TokenMetadataArg;
    type TxnContext = Types.TxnContext;
    type Users = TestTypes.Users;
    type ApprovalInfo = Types.ApprovalInfo;
    type BaseTests = TestTypes.BaseTests;
    type TestCases = TestTypes.TestCases;
    type MintTests = TestTypes.MintTests;
    type BurnTests = TestTypes.BurnTests;
    type TransferTests = TestTypes.TransferTests;
    type ApproveCollectionTests = TestTypes.ApproveCollectionTests;
    type ApproveTokenTests = TestTypes.ApproveTokenTests;
    type RevokeCollectionTests = TestTypes.RevokeCollectionTests;
    type RevokeTokenTests = TestTypes.RevokeTokenTests;
    type TransferFromTests = TestTypes.TransferFromTests;
    type UpdateMetadataTests = TestTypes.UpdateMetadataTests;
    type UnifiedError = TestTypes.UnifiedError;
    type TokenRecord = Types.TokenRecord;
    type BlockValue = Types.BlockValue;
    type Account = Types.Account;
    type AccountRecord = Types.AccountRecord;
    type Value = Types.Value;
    type Error = Types.Error;
    type Metadata = HashMap.HashMap<Text, Value>;
    type ArgFlag = Types.ArgFlag;
    type TestArg = TestTypes.TestArg;
    type TestCaseSet = TestTypes.TestCaseSet;

    func getUsers(): Users {
        {
            caller = {owner = Principal.fromText("2e7fg-mfyxt-iivfx-l7pim-ysvwq-qetwz-h4rhz-t76tr-5zob4-oopr3-hae"); subaccount = null};
            from = {owner = Principal.fromText("fdiem-i5wk4-rm5ln-2jctb-zn7b7-wy6qb-vga36-7wodq-4clo4-5ewbb-5qe"); subaccount = null};
            spender = {owner = Principal.fromText("gy63g-ojiyh-6pivx-zvzs7-yqy64-q6ex6-wn5lq-zop7a-c74eo-2lbpy-2ae"); subaccount = null};
            to = {owner = Principal.fromText("ytpaf-ed5q3-psc3d-3g634-d2sbf-23lm4-2iwim-n6t7u-drrvl-i6qsi-bqe"); subaccount = null};
            admin = {owner = Principal.fromText("vq2za-kqaaa-aaaas-amlvq-cai"); subaccount = null;};
            unauthorisedCaller =  {owner = Principal.fromText("2vxsx-fae"); subaccount = null};
            unmatchedSubaccount = ?Text.encodeUtf8("unmatched");
        }
    };

    func seedTestTokenState(ctx: TxnContext, token_id: Nat, owner: Account, metadata: [(Text, Value)], tokenApprovals: [ApprovalInfo], collectionApprovals: [ApprovalInfo], balance: Nat): () {
      ctx.tokens.put(token_id, { owner = owner; metadata = metadata; approvals = tokenApprovals });
      ctx.accounts.put(owner, { balance = balance; owned_tokens = [token_id]; approvals = collectionApprovals });
      ctx.totalSupply := balance;
    };

    func createMockTxnContext(): TxnContext {
      let ctx = {
        var index = 0;
        var tokens = HashMap.HashMap<Nat, TokenRecord>(0, Nat.equal, Utils.natToHash);
        var ledger = Buffer.Buffer<BlockValue>(0);
        var accounts = HashMap.HashMap<Account, AccountRecord>(0, Utils.accountEqual, Utils.accountHash);
        var totalSupply = 2;
        var metadata = HashMap.HashMap<Text, Value>(0, Text.equal, Text.hash);
        var errors = HashMap.HashMap<Nat, Error>(0, Nat.equal, Utils.natToHash);
        var phash = Blob.fromArray([]);
        var cert = CertTree.newStore();
        admin = getUsers().admin;
      };
      initMockMetadata(ctx);
    };

    func initMockMetadata(ctx: TxnContext): TxnContext {
      let metadata = ctx.metadata;
      metadata.put("icrc7:total_supply", #Nat(ctx.totalSupply));
      metadata.put("icrc7:supply_cap", #Nat(576));

      // Technical parameters needed for validation logic
      metadata.put("icrc7:tx_window", #Nat(60000));
      metadata.put("icrc7:permitted_drift", #Nat(60000));
      metadata.put("icrc7:max_memo_size", #Nat(500));
      metadata.put("icrc7:max_query_batch_size", #Nat(100));
      metadata.put("icrc7:max_update_batch_size", #Nat(1001));
      metadata.put("icrc7:default_take_value", #Nat(50));
      metadata.put("icrc7:max_take_value", #Nat(500));
      metadata.put("icrc7:atomic_batch_transfers", #Text("false"));

      metadata.put("icrc37_max_approvals_per_token_or_collection", #Nat(100));
      metadata.put("icrc37:max_revoke_approvals", #Nat(100));

      return ctx;
    };

    public func getAllTestCases(): TestCaseSet {
      let base = [#BaseTests(#TooOld), #BaseTests(#CreatedInFuture), #BaseTests(#AnonymousCaller), #BaseTests(#InvalidSubaccount), #BaseTests(#UnauthorizedAccess), #BaseTests(#WithMemo), #BaseTests(#WithCreatedAtTime)];

      {
        mint = Array.append([#MintSingle, #MintMultiple, #MintToSelf, #ExceedsMax, #MintWithoutPermission], base);
        burn = Array.append([#BurnOwned, #BurnUnownedWrongAccount, #BurnNonExistentToken, #BurnTwice, #BurnTokenWithApproval], base);
        transfer = Array.append([#TransferOwnedToken, #TransferToSelf, #TransferUnownedToken, #TransferNonexistentToken, #TransferWithApproval, #TransferFromSubaccount, #TransferToSubaccount, #TransferToKnownAccount], base);
        transferFrom = Array.append([#ValidTransferFromWithCollectionApproval, #ValidTransferFromWithTokenApproval, #TransferFromWithoutApproval, #TransferFromExpiredCollectionApproval, #TransferFromExpiredTokenApproval, #TransferFromWrongSpender, #TransferFromRevoked, #TransferFromNotOwnedByFrom, #TransferFromNonExistingTokenId], base);
        approveCollection = Array.append([#ApproveValidSpender, #ApproveSelf, #ApproveDuplicate, #ApproveWithExpiry], base);
        revokeCollection = Array.append([#RevokeValidSpender, #RevokeNonexistent, #RevokeExpiredApproval], base);
        approveToken = Array.append([#ApproveValidToken, #ApproveAlreadyApproved, #ApproveNonexistentToken, #ApproveUnownedToken, #ApproveSelf, #ApproveWithExpiry], base);
        revokeToken = Array.append([#RevokeValidApproval, #RevokeUnapproved, #RevokeNonexistentToken, #RevokeAsNonOwner, #RevokeExpired], base);
        updateMetadata = Array.append([#UpdateExistingMetadata, #UpdateWithoutPermission, #UpdateNonexistentToken, #UpdateClearsMetadata, #UpdatePartially], base);
      }
    };


/////////////////
///Create Args
/////////////////////

    func createMintArg(): MintArg {
        {
            meta = [];
            from_subaccount = null;
            to = getUsers().to;
            memo = null;
            created_at_time = null;
        }
    };

    func createBurnArg(): BurnArg {
        {
            token_id = 1;
            from_subaccount = null;
            memo = null;
            created_at_time = null;
        }
    };

      func createTransferArg(): TransferArg {
        {
            createBurnArg() with
            to = getUsers().to;
        }
    };

    func createApprovalInfo() : ApprovalInfo {
        {
            spender = getUsers().spender;
            from_subaccount = null;
            expires_at = null;
            memo = null;
            created_at_time = Nat64.fromIntWrap(Time.now());
        }
    };

    func mockApproval(spender: Account): ApprovalInfo {
      {
        spender = spender;
        from_subaccount = null;
        expires_at = null;
        memo = null;
        created_at_time = Nat64.fromIntWrap(Time.now());
      };
    };

    func createApproveCollectionArg(): ApproveCollectionArg {
        {
            approval_info = createApprovalInfo();
        }
    };

    func createTokenApprovalArg(): ApproveTokenArg {
        {
            token_id = 1;
            approval_info = createApprovalInfo();
        }
    };

    func createCollectionRevokeArg(): RevokeCollectionApprovalArg {
        {
            spender = ?getUsers().spender;
            from_subaccount = null;
            memo = null;
            created_at_time = null;
        }
    };

    func createTokenRevokeArg(): RevokeTokenApprovalArg {
        {
            createCollectionRevokeArg() with 
            token_id = 1;
        }
    };

    func createTransferFromArg(): TransferFromArg {
        {
            spender_subaccount = null;
            from = getUsers().from;
            to = getUsers().to;
            token_id = 1;
            memo = null;
            created_at_time = null;
        }
    };

    func createTokenMetadataArg(): TokenMetadataArg {
        {
            token_id = 1;
            key = "name";
            value = #Text("test");
            from_subaccount = null;
            created_at_time = null;
            memo = null;
        }
    };

    func argToMintArg(arg: TransferFromArg): MintArg {
        {
            meta = [];
            from_subaccount = arg.from.subaccount;
            to = arg.to;
            memo = arg.memo;
            created_at_time = arg.created_at_time;
        }
    };

    func argToBurnArg(arg: TransferFromArg): BurnArg {
        {
            token_id = arg.token_id;
            from_subaccount = arg.from.subaccount;
            memo = arg.memo;
            created_at_time = arg.created_at_time;
        }
    };

    func argToTransferArg(arg: TransferFromArg): TransferArg {
        {
            argToBurnArg(arg) with
            to = arg.to;
        }
    };

    func argToApprovalInfo(arg: TransferFromArg): ApprovalInfo {
        {
            spender = getUsers().spender;
            from_subaccount = arg.from.subaccount;
            expires_at = null;
            memo = arg.memo;
            created_at_time = Option.get(arg.created_at_time, Nat64.fromIntWrap(Time.now()));
        }
    };

    func argToApproveCollectionArg(arg: TransferFromArg): ApproveCollectionArg {
        {
            approval_info = argToApprovalInfo(arg);
        }
    };

    func argToRevokeCollectionArg(arg: TransferFromArg): RevokeCollectionApprovalArg {
        {
            spender = null;
            from_subaccount = arg.from.subaccount;
            memo = arg.memo;
            created_at_time = arg.created_at_time;
        }
    };

    func argToApproveTokenArg(arg: TransferFromArg): ApproveTokenArg {
        {
            token_id = arg.token_id;
            approval_info = argToApprovalInfo(arg);
        }
    };

    func argRevokeTokenApprovalArg(arg: TransferFromArg): RevokeTokenApprovalArg {
        {
            argToRevokeCollectionArg(arg) with
            token_id = arg.token_id;
        }
    };

    func argUpdateTokenMetadataArg(arg: TransferFromArg): TokenMetadataArg {
        {
            token_id = arg.token_id;
            key = "name";
            value = #Text("test");
            from_subaccount = arg.from.subaccount;
            created_at_time = arg.created_at_time;
            memo = arg.memo;
        }
    };

    func unwrapMetadataNat64(ctx: TxnContext, key: Text): Nat64 {
        switch(ctx.metadata.get(key)){
            case(?#Nat(n)) Nat64.fromNat(n);
            case(_) 0;
        };
    };

    func testCaseToTransferFromArg(test: BaseTests, ctx: TxnContext): TransferFromArg {
        let arg = createTransferFromArg();
        switch(test){
            case(#TooOld) return {arg with created_at_time = ?Utils.safeSubNat64(Nat64.fromIntWrap(Time.now()), unwrapMetadataNat64(ctx, "icrc7:tx_window") + 100000)};
            case(#CreatedInFuture) return {arg with created_at_time = ?(Nat64.fromIntWrap(Time.now()) + unwrapMetadataNat64(ctx, "icrc7:permitted_drift") + 100000)};
            case(#WithCreatedAtTime) return {arg with created_at_time = ?Nat64.fromIntWrap(Time.now())};
            case(#InvalidSubaccount) return {arg with from = {owner = arg.from.owner; subaccount = getUsers().unmatchedSubaccount}};
            case(#WithMemo) return {arg with memo = ?Text.encodeUtf8("memo")};
            case(#AnonymousCaller or #UnauthorizedAccess) return arg;
        };
    };

    func testCaseToMintArgs(test: MintTests, ctx: TxnContext): [Arg] {
      let arg = createMintArg();
      switch(test) {
        case (#MintSingle or #MintWithoutPermission) return [#Mint(arg)];
        case (#ExceedsMax) {
            ctx.metadata.put(("icrc7:total_supply", #Nat(576)));
            ctx.totalSupply := 576;
            return [#Mint(arg)]
        };
        case (#MintMultiple) return [#Mint(arg), #Mint(arg)];
        case (#MintToSelf) return [#Mint({arg with to = getUsers().caller})];
        case (#BaseTests(base)) return [#Mint(argToMintArg(testCaseToTransferFromArg(base, ctx)))];
      };
    };

    func testCaseToBurnArgs(test: BurnTests, ctx: TxnContext): [Arg] {
      let arg = createBurnArg();
      switch(test) {
        case (#BurnOwned) return [#Burn(arg)];
        case (#BurnUnownedWrongAccount) return [#Burn({arg with from_subaccount = getUsers().unmatchedSubaccount})];
        case (#BurnNonExistentToken) return [#Burn({arg with token_id = 100000})];
        case (#BurnTwice) return [#Burn(arg), #Burn(arg)];
        case (#BurnTokenWithApproval) return [#Burn(arg)];
        case (#BaseTests(tests)) return [#Burn(argToBurnArg(testCaseToTransferFromArg(tests, ctx)))];
      }
    };

    func testCaseToTransferArgs(test: TransferTests, ctx: TxnContext): [Arg] {
      let arg = createTransferArg();
      switch (test) {
        case (#TransferOwnedToken) return [#Transfer(arg)];
        case (#TransferToSelf) return [#Transfer({arg with to = getUsers().caller})];
        case (#TransferUnownedToken) return [#Transfer({arg with from_subaccount = getUsers().unmatchedSubaccount})];
        case (#TransferNonexistentToken) return [#Transfer({arg with token_id = 99999})];
        case (#TransferWithApproval) return [#Transfer(arg)];
        case (#TransferToKnownAccount) return [#Transfer(arg)];
        case (#TransferFromSubaccount) return [#Transfer({arg with from_subaccount = ?Text.encodeUtf8("sub-from")})];
        case (#TransferToSubaccount) return [#Transfer({arg with to = {owner = getUsers().caller.owner; subaccount = ?Text.encodeUtf8("sub-to")}})];
        case (#BaseTests(base)) return [#Transfer(argToTransferArg(testCaseToTransferFromArg(base, ctx)))];
      }
    };

    func testCaseToTransferFromArgs(test: TransferFromTests, ctx: TxnContext): [Arg] {
      let arg = createTransferFromArg();
      switch (test) {
        case (#ValidTransferFromWithCollectionApproval) return [#TransferFrom(arg)];
        case (#ValidTransferFromWithTokenApproval) return [#TransferFrom(arg)];
        case (#TransferFromWithoutApproval) return [#TransferFrom(arg)];
        case (#TransferFromExpiredCollectionApproval) return [#TransferFrom(arg)];
        case (#TransferFromExpiredTokenApproval) return [#TransferFrom(arg)];
        case (#TransferFromWrongSpender) return [#TransferFrom(arg)];
        case (#TransferFromRevoked) return [#TransferFrom(arg)];
        case (#TransferFromNotOwnedByFrom) return [#TransferFrom({arg with from = getUsers().to})];
        case (#TransferFromNonExistingTokenId) return [#TransferFrom({arg with token_id = 123456})];
        case (#BaseTests(base)) return [#TransferFrom(testCaseToTransferFromArg(base, ctx))];
      }
    };

    func testCaseToApproveCollectionArgs(test: ApproveCollectionTests, ctx: TxnContext): [Arg] {
      let arg = createApproveCollectionArg();
      switch (test) {
        case (#ApproveValidSpender) return [#ApproveCollection(arg)];
        case (#ApproveSelf) return [#ApproveCollection({arg with approval_info = {arg.approval_info with spender = getUsers().caller}})];
        case (#ApproveDuplicate) return [#ApproveCollection(arg)];
        case (#ApproveWithExpiry) return [#ApproveCollection({arg with approval_info = {arg.approval_info with expires_at = ?(Nat64.fromIntWrap(Time.now()) + 10_000_000)}})];
        case (#BaseTests(base)) return [#ApproveCollection(argToApproveCollectionArg(testCaseToTransferFromArg(base, ctx)))];
      }
    };

    func testCaseToRevokeCollectionArgs(test: RevokeCollectionTests, ctx: TxnContext): [Arg] {
      let arg = createCollectionRevokeArg();
      switch (test) {
        case (#RevokeValidSpender) return [#RevokeCollection(arg)];
        case (#RevokeNonexistent) return [#RevokeCollection(arg)];
        case (#RevokeExpiredApproval) return [#RevokeCollection(arg)];
        case (#BaseTests(base)) return [#RevokeCollection(argToRevokeCollectionArg(testCaseToTransferFromArg(base, ctx)))];
      }
    };

    func testCaseToApproveTokenArgs(test: ApproveTokenTests, ctx: TxnContext): [Arg] {
      let arg = createTokenApprovalArg();
      switch (test) {
        case (#ApproveValidToken) return [#ApproveToken(arg)];
        case (#ApproveAlreadyApproved) return [#ApproveToken(arg)];
        case (#ApproveNonexistentToken) return [#ApproveToken({arg with token_id = 99999})];
        case (#ApproveUnownedToken) return [#ApproveToken({arg with approval_info = {arg.approval_info with from_subaccount = getUsers().unmatchedSubaccount}})];
        case (#ApproveSelf) return [#ApproveToken({arg with approval_info = {arg.approval_info with spender = getUsers().caller}})];
        case (#ApproveWithExpiry) return [#ApproveToken({arg with approval_info = {arg.approval_info with expires_at = ?(Nat64.fromIntWrap(Time.now()) + 5000)}})];
        case (#BaseTests(base)) return [#ApproveToken(argToApproveTokenArg(testCaseToTransferFromArg(base, ctx)))];
      }
    };

    func testCaseToRevokeTokenArgs(test: RevokeTokenTests, ctx: TxnContext): [Arg] {
      let arg = createTokenRevokeArg();
      switch (test) {
        case (#RevokeValidApproval) return [#RevokeToken(arg)];
        case (#RevokeUnapproved) return [#RevokeToken(arg)];
        case (#RevokeNonexistentToken) return [#RevokeToken({arg with token_id = 100000})];
        case (#RevokeAsNonOwner) return [#RevokeToken({arg with from_subaccount = getUsers().unmatchedSubaccount})];
        case (#RevokeExpired) return [#RevokeToken(arg)];
        case (#BaseTests(base)) return [#RevokeToken(argRevokeTokenApprovalArg(testCaseToTransferFromArg(base, ctx)))];
      }
    };

    func testCaseToUpdateMetadataArgs(test: UpdateMetadataTests, ctx: TxnContext): [Arg] {
      let arg = createTokenMetadataArg();
      switch (test) {
        case (#UpdateExistingMetadata) return [#UpdateMetadata(arg)];
        case (#UpdateWithoutPermission) return [#UpdateMetadata({arg with from_subaccount = getUsers().unmatchedSubaccount})];
        case (#UpdateNonexistentToken) return [#UpdateMetadata({arg with token_id = 99999})];
        case (#UpdateClearsMetadata) return [#UpdateMetadata({arg with value = #Text("")})];
        case (#UpdatePartially) return [#UpdateMetadata({arg with key = "other"; value = #Text("alt")})];
        case (#BaseTests(base)) return [#UpdateMetadata(argUpdateTokenMetadataArg(testCaseToTransferFromArg(base, ctx)))];
      }
    };

    func testCaseToArgs(test: TestCases, ctx: TxnContext): [Arg] {
        switch (test) {
            case (#Mint(m)) return testCaseToMintArgs(m, ctx);
            case (#Burn(b)) return testCaseToBurnArgs(b, ctx);
            case (#Transfer(t)) return testCaseToTransferArgs(t, ctx);
            case (#TransferFrom(tf)) return testCaseToTransferFromArgs(tf, ctx);
            case (#ApproveCollection(ac)) return testCaseToApproveCollectionArgs(ac, ctx);
            case (#ApproveToken(at)) return testCaseToApproveTokenArgs(at, ctx);
            case (#RevokeCollection(rc)) return testCaseToRevokeCollectionArgs(rc, ctx);
            case (#RevokeToken(rt)) return testCaseToRevokeTokenArgs(rt, ctx);
            case (#UpdateMetadata(um)) return testCaseToUpdateMetadataArgs(um, ctx);
        };
    };
    

    ////////////////////////////////
    //////Expected Errors or null
    ///////////////////////////////
    func expectedBaseError(test: BaseTests): ?UnifiedError {
        switch(test) {
          case (#TooOld) return ?#TooOld;
          case (#CreatedInFuture) return ?#CreatedInFuture{ledger_time = Nat64.fromIntWrap(Time.now())};
          case (#AnonymousCaller) return ?#Unauthorized;
          case (#InvalidSubaccount) return ?#Unauthorized;
          case (#UnauthorizedAccess) return ?#Unauthorized;
          case (#WithMemo) return null;
          case(#WithCreatedAtTime) return null;
        };
    };

    func expectedMintTestsError(test: MintTests): ?UnifiedError {
      switch(test) {
        case (#MintSingle) return null;
        case (#ExceedsMax) return ?#ExceedsMaxSupply;
        case (#MintWithoutPermission) return ?#Unauthorized;
        case (#MintMultiple) return null;
        case (#MintToSelf) return null;
        case (#BaseTests(base)) return expectedBaseError(base);
      };
    };

    func expectedBurnTestsError(test: BurnTests): ?UnifiedError {
      switch(test) {
        case (#BurnOwned) return null;
        case (#BurnUnownedWrongAccount) return ?#Unauthorized;
        case (#BurnNonExistentToken) return ?#NonExistingTokenId;
        case (#BurnTwice) return ?#NonExistingTokenId;
        case (#BurnTokenWithApproval) return null;
        case (#BaseTests(base)) return expectedBaseError(base);
      };
    };

    func expectedTransferTestsError(test: TransferTests): ?UnifiedError {
      switch(test) {
        case (#TransferOwnedToken) return null;
        case (#TransferToSelf) return null;
        case (#TransferUnownedToken) return ?#Unauthorized;
        case (#TransferNonexistentToken) return ?#NonExistingTokenId;
        case (#TransferWithApproval) return null;
        case (#TransferFromSubaccount) return null;
        case (#TransferToSubaccount) return null;
        case (#TransferToKnownAccount) return null;
        case (#BaseTests(base)) return expectedBaseError(base);
      };
    };

    func expectedTransferFromTestsError(test: TransferFromTests): ?UnifiedError {
      switch(test) {
        case (#ValidTransferFromWithCollectionApproval) return null;
        case (#ValidTransferFromWithTokenApproval) return null;
        case (#TransferFromWithoutApproval) return ?#Unauthorized;
        case (#TransferFromExpiredCollectionApproval) return ?#Unauthorized;
        case (#TransferFromExpiredTokenApproval) return ?#Unauthorized;
        case (#TransferFromWrongSpender) return ?#Unauthorized;
        case (#TransferFromRevoked) return ?#Unauthorized;
        case (#TransferFromNotOwnedByFrom) return ?#Unauthorized;
        case (#TransferFromNonExistingTokenId) return ?#NonExistingTokenId;
        case (#BaseTests(base)) return expectedBaseError(base);
      };
    };

    func expectedApproveCollectionTestsError(test: ApproveCollectionTests): ?UnifiedError {
      switch(test) {
        case (#ApproveValidSpender) return null;
        case (#ApproveSelf) return ?#InvalidSpender;
        case (#ApproveDuplicate) return null;
        case (#ApproveWithExpiry) return null;
        case(#BaseTests(#InvalidSubaccount)) return null;
        case(#BaseTests(#UnauthorizedAccess)) return null;
        case(#BaseTests(#AnonymousCaller)) return ?#GenericError{error_code = 700; message = "Anonymous Principal"};
        case (#BaseTests(base)) return expectedBaseError(base);
      };
    };

    func expectedRevokeCollectionTestsError(test: RevokeCollectionTests): ?UnifiedError {
      switch(test) {
        case (#RevokeValidSpender) return null;
        case (#RevokeNonexistent) return ?#ApprovalDoesNotExist;
        case (#RevokeExpiredApproval) return ?#ApprovalDoesNotExist;
        case (#BaseTests(#AnonymousCaller)) return ?#ApprovalDoesNotExist;
        case (#BaseTests(#InvalidSubaccount)) return ?#ApprovalDoesNotExist;
        case (#BaseTests(#UnauthorizedAccess)) return ?#ApprovalDoesNotExist;
        case (#BaseTests(base)) return expectedBaseError(base);
      };
    };

    func expectedApproveTokenTestsError(test: ApproveTokenTests): ?UnifiedError {
      switch(test) {
        case (#ApproveValidToken) return null;
        case (#ApproveAlreadyApproved) return null;
        case (#ApproveNonexistentToken) return ?#NonExistingTokenId;
        case (#ApproveUnownedToken) return ?#Unauthorized;
        case (#ApproveSelf) return ?#InvalidSpender;
        case (#ApproveWithExpiry) return null;
        case (#BaseTests(base)) return expectedBaseError(base);
      };
    };

    func expectedRevokeTokenTestsError(test: RevokeTokenTests): ?UnifiedError {
      switch(test) {
        case (#RevokeValidApproval) return null;
        case (#RevokeUnapproved) return ?#ApprovalDoesNotExist;
        case (#RevokeNonexistentToken) return ?#NonExistingTokenId;
        case (#RevokeAsNonOwner) return ?#Unauthorized;
        case (#RevokeExpired) return ?#ApprovalDoesNotExist;
        case (#BaseTests(base)) return expectedBaseError(base);
      };
    };

    func expectedUpdateMetadataTestsError(test: UpdateMetadataTests): ?UnifiedError {
      switch(test) {
        case (#UpdateExistingMetadata) return null;
        case (#UpdateWithoutPermission) return ?#Unauthorized;
        case (#UpdateNonexistentToken) return ?#NonExistingTokenId;
        case (#UpdateClearsMetadata) return null;
        case (#UpdatePartially) return null;
        case (#BaseTests(base)) return expectedBaseError(base);
      };
    };

    func expectedErrorForTestCase(test: TestCases): ?UnifiedError {
      switch (test) {
        case (#Mint(mintTest)) return expectedMintTestsError(mintTest);
        case (#Burn(burnTest)) return expectedBurnTestsError(burnTest);
        case (#Transfer(transferTest)) return expectedTransferTestsError(transferTest);
        case (#ApproveCollection(approveCollectionTest)) return expectedApproveCollectionTestsError(approveCollectionTest);
        case (#ApproveToken(approveTokenTest)) return expectedApproveTokenTestsError(approveTokenTest);
        case (#RevokeCollection(revokeCollectionTest)) return expectedRevokeCollectionTestsError(revokeCollectionTest);
        case (#RevokeToken(revokeTokenTest)) return expectedRevokeTokenTestsError(revokeTokenTest);
        case (#TransferFrom(transferFromTest)) return expectedTransferFromTestsError(transferFromTest);
        case (#UpdateMetadata(updateMetadataTest)) return expectedUpdateMetadataTestsError(updateMetadataTest);
      };
    };

    ////////////////////////////////
    //////Get Caller
    ////////////////////////////
    func callerForTestCase(test: TestCases): Principal {
      let users = getUsers();

      switch (test) {
        case (#Mint(#MintWithoutPermission)) return users.caller.owner;
        case (#Mint(#BaseTests(#UnauthorizedAccess))) return users.to.owner;
        case (#ApproveCollection(#ApproveSelf)) return users.caller.owner;
        case (#ApproveToken(#ApproveSelf)) return users.caller.owner;
        case (#RevokeCollection(#BaseTests(#UnauthorizedAccess))) return users.unauthorisedCaller.owner;
        case (#RevokeToken(#RevokeAsNonOwner)) return users.unauthorisedCaller.owner;
        case (#UpdateMetadata(#BaseTests(#AnonymousCaller))) return users.unauthorisedCaller.owner;
        case (#UpdateMetadata(#BaseTests(#UnauthorizedAccess))) return users.to.owner;
        case (#UpdateMetadata(#UpdateWithoutPermission)) return users.unauthorisedCaller.owner;
        case (#Burn(#BurnUnownedWrongAccount)) return users.unauthorisedCaller.owner;
        case (#Burn(#BaseTests(#UnauthorizedAccess))) return users.to.owner;
        case (#Transfer(#TransferUnownedToken)) return users.unauthorisedCaller.owner;
        case (#TransferFrom(#TransferFromWrongSpender)) return users.unauthorisedCaller.owner;
        
        case (#Mint(#BaseTests(#AnonymousCaller))) return users.unauthorisedCaller.owner;
        case(#Mint(_)) users.admin.owner;
        case(#UpdateMetadata(_)) users.admin.owner;
        case (#ApproveCollection(#BaseTests(#AnonymousCaller))) return users.unauthorisedCaller.owner;
        case (#ApproveToken(#BaseTests(#AnonymousCaller))) return users.to.owner;
        case (#RevokeToken(#BaseTests(#AnonymousCaller))) return users.unauthorisedCaller.owner;
        case (#RevokeCollection(#BaseTests(#AnonymousCaller))) return users.unauthorisedCaller.owner;
        case (#Burn(#BaseTests(#AnonymousCaller))) return users.unauthorisedCaller.owner;
        case (#Transfer(#BaseTests(#AnonymousCaller))) return users.unauthorisedCaller.owner;
        case (#TransferFrom(#BaseTests(#AnonymousCaller))) return users.unauthorisedCaller.owner;

        // All others fall back to standard test caller
        case _ return users.caller.owner;
      };
    };

    ////////////////////////////////
    ///////Token and owner balances 
    ////////////////////////////////

    func seedTestCase(ctx: TxnContext, test: TestCases): () {
      let users = getUsers();
      switch (test) {
        case (#Mint(_)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [], [], 1);

        case (#Burn(#BurnUnownedWrongAccount)) seedTestTokenState(ctx, 1, users.to, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#Burn(#BurnNonExistentToken)) seedTestTokenState(ctx, 99999, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#Burn(_)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);

        case (#Transfer(#TransferUnownedToken)) seedTestTokenState(ctx, 1, users.to, [("name", #Text("Mock NFT"))], [], [], 1); 
        case (#Transfer(#BaseTests(#UnauthorizedAccess))) seedTestTokenState(ctx, 1, users.to, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#Transfer(#TransferFromSubaccount)) seedTestTokenState(ctx, 1, {owner = users.caller.owner; subaccount = ?Text.encodeUtf8("sub-from")}, [("name", #Text("Mock NFT"))], [], [], 1); 
        case (#Transfer(#TransferWithApproval)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [{spender = users.spender; from_subaccount = null; expires_at = null; memo = null; created_at_time = 0}], [], 1);
        case (#Transfer(#TransferToKnownAccount)) {
            seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);
            seedTestTokenState(ctx, 2, users.to, [("name", #Text("Mock NFT"))], [], [], 1);
        };
        case (#Transfer(_)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);

        case (#TransferFrom(#TransferFromWrongSpender)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [{spender = users.spender; from_subaccount = null; expires_at = null; memo = null; created_at_time = 0}], [], 1);
        case (#TransferFrom(#TransferFromNonExistingTokenId)) seedTestTokenState(ctx, 99999, users.from, [("name", #Text("Mock NFT"))], [], [], 1); 
        case (#TransferFrom(#TransferFromNotOwnedByFrom)) seedTestTokenState(ctx, 1, users.to, [("name", #Text("Mock NFT"))], [], [], 1); 
        case (#TransferFrom(#ValidTransferFromWithCollectionApproval)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [], [{spender = users.caller; from_subaccount = null; expires_at = null; memo = null; created_at_time = 0}], 1);
        case (#TransferFrom(#TransferFromExpiredCollectionApproval)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [], [{spender = users.caller; from_subaccount = null; expires_at = ?Nat64.fromIntWrap(Time.now() - 1000); memo = null; created_at_time = 0}], 1);
        case (#TransferFrom(#ValidTransferFromWithTokenApproval)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [{spender = users.caller; from_subaccount = null; expires_at = null; memo = null; created_at_time = 0}], [], 1);
        case (#TransferFrom(#TransferFromExpiredTokenApproval)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [{spender = users.caller; from_subaccount = null; expires_at = ?Nat64.fromIntWrap(Time.now() - 1000); memo = null; created_at_time = 0}], [], 1);
        case (#TransferFrom(#TransferFromWithoutApproval)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#TransferFrom(#TransferFromRevoked)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#TransferFrom(#BaseTests(#InvalidSubaccount))) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [{spender = {owner = users.caller.owner; subaccount = users.unmatchedSubaccount}; from_subaccount = null; expires_at = ?Nat64.fromIntWrap(Time.now() - 1000); memo = null; created_at_time = 0}], [], 1);
        case (#TransferFrom(#BaseTests(#UnauthorizedAccess))) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [{spender = users.caller; from_subaccount = users.unmatchedSubaccount; expires_at = ?Nat64.fromIntWrap(Time.now() - 1000); memo = null; created_at_time = 0}], [], 1);
        case (#TransferFrom(_)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [{spender = users.caller; from_subaccount = null; expires_at = null; memo = null; created_at_time = 0}], [], 1);

        case (#ApproveCollection(#ApproveSelf)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#ApproveCollection(_)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [], [], 1);

        case (#RevokeCollection(#RevokeNonexistent)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#RevokeCollection(#RevokeExpiredApproval)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [{spender = users.spender; from_subaccount = null; expires_at = ?0; memo = null; created_at_time = 0}], 1);
        case (#RevokeCollection(_)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [{spender = users.spender; from_subaccount = null; expires_at = ?Nat64.fromIntWrap(Time.now() + 1000); memo = null; created_at_time = 0}], 1);

        case (#ApproveToken(#ApproveSelf)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#ApproveToken(#ApproveNonexistentToken)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#ApproveToken(#ApproveUnownedToken)) seedTestTokenState(ctx, 1, users.to, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#ApproveToken(#BaseTests(#UnauthorizedAccess))) seedTestTokenState(ctx, 1, {owner = users.caller.owner; subaccount = users.unmatchedSubaccount;}, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#ApproveToken(_)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);

        case (#RevokeToken(#RevokeAsNonOwner)) seedTestTokenState(ctx, 1, users.to, [("name", #Text("Mock NFT"))], [{spender = users.spender; from_subaccount = null; expires_at = ?Nat64.fromIntWrap(Time.now() + 1000); memo = null; created_at_time = 0}], [], 1);
        case (#RevokeToken(#RevokeExpired)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [{spender = users.spender; from_subaccount = null; expires_at = ?0; memo = null; created_at_time = 0}], [], 1);
        case (#RevokeToken(#RevokeUnapproved)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#RevokeToken(#RevokeNonexistentToken)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [{spender = users.spender; from_subaccount = null; expires_at = ?Nat64.fromIntWrap(Time.now() + 1000); memo = null; created_at_time = 0}], [], 1);
        case (#RevokeToken(#BaseTests(#UnauthorizedAccess))) seedTestTokenState(ctx, 1, users.to, [("name", #Text("Mock NFT"))], [{spender = users.spender; from_subaccount = null; expires_at = ?Nat64.fromIntWrap(Time.now() + 1000); memo = null; created_at_time = 0}], [], 1);
        case (#RevokeToken(_)) seedTestTokenState(ctx, 1, users.caller, [("name", #Text("Mock NFT"))], [{spender = users.spender; from_subaccount = null; expires_at = ?Nat64.fromIntWrap(Time.now() + 1000); memo = null; created_at_time = 0}], [], 1);

        case (#UpdateMetadata(#UpdateWithoutPermission)) seedTestTokenState(ctx, 1, users.to, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#UpdateMetadata(#UpdateNonexistentToken)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [], [], 1);
        case (#UpdateMetadata(_)) seedTestTokenState(ctx, 1, users.from, [("name", #Text("Mock NFT"))], [], [], 1);
      };
    };

    ////////////////////////////////
    ////Check balances and token ids
    /////////////////////////////////
    func getExpectedState(test: TestCases, expected: ?UnifiedError): [(Account, ?Nat, Nat)] {
        let users = getUsers();
        switch (test, expected) {
            // ===== MINT =====
            case (#Mint(_), null) return [(users.from, ?1, 1)];
            case (#Mint(_), _) return [];

            // ===== BURN =====
            case (#Burn(#BurnOwned), null) return [(users.from, null, 0)];
            case (#Burn(#BurnUnownedWrongAccount), _) return [(users.to, ?1, 1)];
            case (#Burn(#BurnNonExistentToken), _) return [];
            case (#Burn(_), null) return [(users.from, null, 0)];

            // ===== TRANSFER =====
            case (#Transfer(#TransferOwnedToken), null) return [(users.from, null, 0), (users.to, ?1, 1)];
            case (#Transfer(#TransferToSelf), null) return [(users.from, ?1, 1)];
            case (#Transfer(#TransferToKnownAccount), null) return [(users.to, ?1, 2), (users.to, ?2, 2)];
            case (#Transfer(#TransferUnownedToken), _) return [(users.to, ?1, 1)];
            case (#Transfer(#TransferNonexistentToken), _) return [];
            case (#Transfer(_), null) return [(users.from, null, 0), (users.to, ?1, 1)];

            // ===== TRANSFER FROM =====
            case (#TransferFrom(#TransferFromWrongSpender), _) return [(users.from, ?1, 1)];
            case (#TransferFrom(#TransferFromNonExistingTokenId), _) return [];
            case (#TransferFrom(#TransferFromNotOwnedByFrom), _) return [(users.to, ?1, 1)];
            case (#TransferFrom(_), null) return [(users.from, null, 0), (users.to, ?1, 1)];

            // ===== APPROVE COLLECTION =====
            case (#ApproveCollection(_), _) return [(users.from, ?1, 1)];

            // ===== APPROVE TOKEN =====
            case (#ApproveToken(_), _) return [(users.from, ?1, 1)];

            // ===== REVOKE COLLECTION =====
            case (#RevokeCollection(_), _) return [(users.from, ?1, 1)];

            // ===== REVOKE TOKEN =====
            case (#RevokeToken(_), _) return [(users.from, ?1, 1)];

            // ===== UPDATE METADATA =====
            case (#UpdateMetadata(_), _) return [(users.from, ?1, 1)];

            // ===== DEFAULT =====
            case (_, _) return [];
        }
    };

    public func approvalExpectations(test: TestCases, expected: ?UnifiedError): [(?(Account, Account), ?Nat, ApprovalInfo)] {
      let users = getUsers();

      switch (test, expected) {
        case (#ApproveCollection(#ApproveValidSpender), null) return [(?(users.from, users.spender), null, mockApproval(users.spender))];
        case (#ApproveCollection(_), ?_) return [(?(users.from, users.spender), null, mockApproval(users.spender))];

        case (#RevokeCollection(#RevokeValidSpender), null) return [];
        case (#RevokeCollection(_), ?_) return [(?(users.from, users.spender), null, mockApproval(users.spender))];

        case (#ApproveToken(#ApproveValidToken), null) return [(null, ?1, mockApproval(users.spender))];
        case (#ApproveToken(_), ?_) return [(null, ?1, mockApproval(users.spender))];

        case (#RevokeToken(#RevokeValidApproval), null) return [];
        case (#RevokeToken(_), ?_) return [(null, ?1, mockApproval(users.spender))];

        case (#Transfer(_), null) return [(?(users.from, users.spender), null, mockApproval(users.spender))]; // only collection approvals persist
        case (#Transfer(_), ?_) return [(?(users.from, users.spender), null, mockApproval(users.spender))];

        case (#TransferFrom(#ValidTransferFromWithCollectionApproval), null) return [(?(users.from, users.spender), null, mockApproval(users.spender))];
        case (#TransferFrom(_), null) return [(?(users.from, users.spender), null, mockApproval(users.spender))];
        case (#TransferFrom(_), ?_) return [(?(users.from, users.spender), null, mockApproval(users.spender))];

        case (#Burn(_), null) return [];
        case (#Burn(_), ?_) return [(null, ?1, mockApproval(users.spender))];

        case (#Mint(_), _) return [];

        case (#UpdateMetadata(_), _) return [(null, ?1, mockApproval(users.spender))];

        // Fallback
        case (_, _) return [];
      };
    };

    ///////////////////////////////////
    //////Wiring the tests up 
    //////////////////////////////////
    public func createTestArg(testCase: TestCases, ctx: TxnContext): TestArg {
      let expected = expectedErrorForTestCase(testCase);
      {
        testCase = testCase;
        args = testCaseToArgs(testCase, ctx);
        caller = callerForTestCase(testCase);
        expected;
        expectedBalances = getExpectedState(testCase, expected);
        expectedApprovals = approvalExpectations(testCase, expected);
      };
    };

   public func getTestCasesByArgFlag(flag: ?ArgFlag): [TestCases] {
      let all = getAllTestCases();

      switch (flag) {
        case (?#Mint) return Array.map(all.mint, func (x: MintTests): TestCases = #Mint(x));
        case (?#Burn) return Array.map(all.burn, func (x: BurnTests): TestCases = #Burn(x));
        case (?#Transfer) return Array.map(all.transfer, func (x: TransferTests): TestCases = #Transfer(x));
        case (?#TransferFrom) return Array.map(all.transferFrom, func (x: TransferFromTests): TestCases = #TransferFrom(x));
        case (?#ApproveCollection) return Array.map(all.approveCollection, func (x: ApproveCollectionTests): TestCases = #ApproveCollection(x));
        case (?#RevokeCollection) return Array.map(all.revokeCollection, func (x: RevokeCollectionTests): TestCases = #RevokeCollection(x));
        case (?#ApproveToken) return Array.map(all.approveToken, func (x: ApproveTokenTests): TestCases = #ApproveToken(x));
        case (?#RevokeToken) return Array.map(all.revokeToken, func (x: RevokeTokenTests): TestCases = #RevokeToken(x));
        case (?#UpdateMetadata) return Array.map(all.updateMetadata, func (x: UpdateMetadataTests): TestCases = #UpdateMetadata(x));
        case (null) {
          return Array.flatten([
            Array.map(all.mint, func (x: MintTests): TestCases = #Mint(x)),
            Array.map(all.burn, func (x: BurnTests): TestCases = #Burn(x)),
            Array.map(all.transfer, func (x: TransferTests): TestCases = #Transfer(x)),
            Array.map(all.transferFrom, func (x: TransferFromTests): TestCases = #TransferFrom(x)),
            Array.map(all.approveCollection, func (x: ApproveCollectionTests): TestCases = #ApproveCollection(x)),
            Array.map(all.revokeCollection, func (x: RevokeCollectionTests): TestCases = #RevokeCollection(x)),
            Array.map(all.approveToken, func (x: ApproveTokenTests): TestCases = #ApproveToken(x)),
            Array.map(all.revokeToken, func (x: RevokeTokenTests): TestCases = #RevokeToken(x)),
            Array.map(all.updateMetadata, func (x: UpdateMetadataTests): TestCases = #UpdateMetadata(x))
          ]);
        };
      }
    };

    public func runAllTests(flag: ?ArgFlag): () {
      let tests : [TestCases] = getTestCasesByArgFlag(flag); // returns [TestCases]

      for (test in tests.vals()) {
        let ctx = createMockTxnContext(); // new isolated context
        seedTestCase(ctx, test);       // sets up user/token state
        let testArg = createTestArg(test, ctx); // builds arg & expectations
        for(arg in testArg.args.vals()){
            let result :?{#Ok: Nat; #Err: UnifiedError} = switch (arg) {
              case (#Mint(arg)) ICRC7.mintNFT([arg], ctx, testArg.caller)[0];
              case (#Burn(arg)) ICRC7.burnNFT([arg], ctx, testArg.caller)[0];
              case (#Transfer(arg)) ICRC7.icrc7_transferHelper([arg], ctx, testArg.caller)[0];
              case (#TransferFrom(arg)) ICRC37.handleTransferFrom([arg], ctx, testArg.caller)[0];
              case (#ApproveCollection(arg)) ICRC37.handleApproveCollection([arg], ctx, testArg.caller)[0];
              case (#RevokeCollection(arg)) ICRC37.handleRevokeCollectionApproval([arg], ctx, testArg.caller)[0];
              case (#ApproveToken(arg)) ICRC37.handleApproveTokenRecords([arg], ctx, testArg.caller)[0];
              case (#RevokeToken(arg)) ICRC37.handleRevokeTokenApprovals([arg], ctx, testArg.caller)[0];
              case (#UpdateMetadata(arg)) ICRC7.updateTokenMetadata([arg], ctx, testArg.caller)[0];
            };
            Debug.print(handleOutcome(testArg, ctx, result)); // handles Ok/Err unified variant
        }

      };
    };

    ////////////////////////////////////
    //////////Handle Results
    ///////////////////////////////////
    func verifyBalance(ogText: Text, account: Account, balance: Nat, ctx: TxnContext): Text {
        var text = ogText;
        switch(ctx.accounts.get(account)){
            case(?accountRecord){
                if(accountRecord.balance != balance) text := text # " - invalid balance"; 
            };
            case(null) text := text # " - account record does not exist"
        };
        text;
    };

    func testBalances(arg: TestArg, ctx: TxnContext): Text {
        var text = "";
        for((account, tokenId, balance) in arg.expectedBalances.vals()){
            switch(tokenId){
                case(null) text := verifyBalance(text, account, balance, ctx);
                case(?tokenId){
                    switch(ctx.tokens.get(tokenId), ctx.accounts.get(account)){
                        case(null, ?accountRecord) {
                            text := text # " - token record does not exist";
                            if(accountRecord.balance != balance) text := text # " - invalid balance"; 
                        };
                        case(?tokenRecord, ?accountRecord){
                            if(accountRecord.balance != balance) text := text # " - invalid balance"; 
                            if(account != tokenRecord.owner) text := text # " - accounts don't match";
                            if(Array.indexOf<Nat>(tokenId, accountRecord.owned_tokens, Nat.equal) == null) text := text # " - token id is not in owned_tokens array";
                        };
                        case(?tokenRecord, null){
                            if(account != tokenRecord.owner) text := text # " - accounts don't match";
                            text := text # "- account record does not exist";
                        };
                        case(null, null){
                            text := text # "- account record does not exist";
                            text := text # " - token record does not exist";
                        };
                    };
                };
            };
        };
        text;
    };

    func verifyAllowances(arg: TestArg, ctx: TxnContext): Text {
        var text = "";
        for((accounts, tokenId, approval) in arg.expectedApprovals.vals()){
            switch(accounts){
                case(null){};
                case(?(account, _)) {
                    switch(ctx.accounts.get(account)){
                        case(null) text := text # " - approval account record does not exist";
                        case(?accountRecord) if(Array.indexOf<ApprovalInfo>(approval, accountRecord.approvals, func(a1: ApprovalInfo, a2: ApprovalInfo) {a1 == a2}) == null) text := text # " - account approval does not exist";
                    }
                }
            };

            switch(tokenId){
                case(null){};
                case(?tokenId){
                    switch(ctx.tokens.get(tokenId)){
                        case(null) text := text # "- token record for approval does not exist";
                        case(?tokenRecord) if(Array.indexOf<ApprovalInfo>(approval, tokenRecord.approvals, func(a1: ApprovalInfo, a2: ApprovalInfo) {a1 == a2}) == null) text := text # " - token approval does not exist";
                    };
                };
            };
        };
        text;
    };



    func handleOk(arg: TestArg, ctx: TxnContext): Text {
        "✅ OK: "# debug_show(arg.testCase) # " returned correct result ";//#"Balances: " #testBalances(arg, ctx)#". Allowances: "#verifyAllowances(arg, ctx);
    };

    // Generic Err handler
    func handleErr(err1: UnifiedError, err2: UnifiedError, arg: TestArg, ctx: TxnContext): Text {
        if(err1 == err2)  "✅ OK: "# debug_show(arg.testCase) # " errors match "#debug_show(err1)#debug_show(err2)//#"Balances: " #testBalances(arg, ctx)#". Allowances: "#verifyAllowances(arg, ctx)
        else "❌ Err: " # debug_show(arg.testCase) # " errors mismatch - expected: "#debug_show(err1)#". Actual Result: "#debug_show(err2)//#"Balances: " #testBalances(arg, ctx)#". Allowances: "#verifyAllowances(arg, ctx);
    };

    // Generic dispatcher for any {#Ok; #Err} variant
    func handleOutcome(arg: TestArg, ctx: TxnContext, res : ?{ #Ok : Nat; #Err : UnifiedError }) : Text {
      switch (arg.expected, res) {
        case (null, ?#Ok(_)) handleOk(arg, ctx);
        case (?e, ?#Err(err)) handleErr(e, err, arg, ctx);
        case (_, ?result) "❌ "#debug_show(arg.testCase)#" results mismatch - Expected outcome "# debug_show(arg.expected) #". Actual Result: "#debug_show(result);
        case(_, null) "❌ "#debug_show(arg.testCase)#" null was returned from the function";
      };
    };

}