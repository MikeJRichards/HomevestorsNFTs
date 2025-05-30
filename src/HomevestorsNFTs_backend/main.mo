import Types "./types";
import Utils "utils";
import ICRC7 "icrc7";
import ICRC10 "icrc10";
import ICRC37 "icrc37";
import ICRC3 "icrc3";
import Metadata "metadata";
import ELog "errorlogging";
import Ledger "ledger";
import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Iter "mo:base/Iter";
import CertTree "mo:ic-certification/CertTree";
import Buffer "mo:base/Buffer";
import Blob "mo:base/Blob";


actor {
  type Account = Types.Account;
  type Value = Types.Value;
  type TransferArg = Types.TransferArg;
  type BurnArg = Types.BurnArg;
  type TransferResult = Types.TransferResult;
  type AccountRecord = Types.AccountRecord;
  type TokenRecord = Types.TokenRecord;
  type PropertyDetails = Types.PropertyDetails;
  type CreateFinancialsArg = Types.CreateFinancialsArg;
  type ApproveTokenArg = Types.ApproveTokenArg;
  type ApproveTokenResult = Types.ApproveTokenResult;
  type ApproveCollectionArg = Types.ApproveCollectionArg;
  type RevokeTokenApprovalArg = Types.RevokeTokenApprovalArg;
  type RevokeTokenApprovalResponse = Types.RevokeTokenApprovalResponse;
  type RevokeCollectionApprovalArg = Types.RevokeCollectionApprovalArg;
  type RevokeCollectionApprovalResult = Types.RevokeCollectionApprovalResult;
  type IsApprovedArg = Types.IsApprovedArg;
  type TokenApproval = Types.TokenApproval;
  type CollectionApproval = Types.CollectionApproval;
  type TransferFromArg = Types.TransferFromArg;
  type TransferFromResult = Types.TransferFromResult;
  type ApproveCollectionResult = Types.ApproveCollectionResult;
  type TokenMetadataArgs = Types.TokenMetadataArg;
  type TokenMetadataResult = Types.TokenMetadataResult;
  type Block = Types.Block;
  type MintArg = Types.MintArg;
  type MintResult = Types.MintResult;
  type TxnContext = Types.TxnContext;
  type SupportedStandards = Types.SupportedStandards;
  type Error = Types.Error;
  type Arg = Types.Arg;
  type ValidationError = Types.ValidationError;
  type ArgFlag = Types.ArgFlag;
  type ValidationErrorFlag = Types.ValidationErrorFlag;
  type DataCertificate = Types.DataCertificate;
  type BlockValue = Types.BlockValue;
  type GetArchivesArgs = Types.GetArchivesArgs;
  type GetArchivesResult = Types.GetArchivesResult;
  type GetBlocksArgs = Types.GetBlocksArgs;
  type GetBlocksResult = Types.GetBlocksResult;

  var ctx : TxnContext = {
    var index = 0;
    var tokens = HashMap.HashMap<Nat, TokenRecord>(0, Nat.equal, Utils.natToHash);
    var ledger = Buffer.Buffer<BlockValue>(0);
    var accounts = HashMap.HashMap<Account, AccountRecord>(0, Utils.accountEqual, Utils.accountHash);
    var totalSupply = 0;
    var metadata = HashMap.HashMap<Text, Value>(0, Text.equal, Text.hash);
    var errors = HashMap.HashMap<Nat, Error>(0, Nat.equal, Utils.natToHash);
    var phash = Blob.fromArray([]);
    var cert = CertTree.newStore(); 
    //CertTree.Ops(CertTree.newStore());
    admin = Principal.fromText("vq2za-kqaaa-aaaas-amlvq-cai");
  };

  stable var stableCert = CertTree.newStore();
  stable var stablePhash = Blob.fromArray([]);
  stable var propertyId = 0;
  stable var stableTokenRecords : [(Nat, TokenRecord)] = [];
  stable var stableAccountRecords :[(Account, AccountRecord)] = [];
  stable var stableMetadata : [(Text, Value)] = [];
  stable var stableLedger : [BlockValue] = [];
  stable var stableErrors : [(Nat, Error)] = [];
  stable var stableTotalSupply = 0;
  stable var stableIndex = 0;

  public shared ({caller}) func initiateMetadata(id: Nat): async (){
    assert(Principal.equal(caller, ctx.admin));
    propertyId := id;
    ctx.metadata := Metadata.initiateMetadata(ctx.metadata, ctx.totalSupply, propertyId);
  };

  public shared query ({caller}) func initiateProperty(): async (CreateFinancialsArg, PropertyDetails){
    assert(Principal.equal(caller, ctx.admin));
    Metadata.createPropertyData(ctx.metadata);
  };

  public shared ({caller}) func updateCollectionMetadata(updates: [(Text, Value)]): async (){
    assert(Principal.equal(caller, ctx.admin));
    for((key, value) in updates.vals()){
      ctx.metadata.put(key, value);
    };
  };

  public shared query ({caller}) func get_all_tokens(): async [(Nat, TokenRecord)] {
    assert(Principal.equal(caller, ctx.admin));
    Iter.toArray(ctx.tokens.entries())
  };

  public query func getTokenRecord(tokenId: Nat): async ?TokenRecord {
    ctx.tokens.get(tokenId);
  };

  public query func getAccountRecord(account: Account): async ?AccountRecord {
    ctx.accounts.get(account);
  };

  public shared ({caller}) func exportState(): async ([(Nat, TokenRecord)], [(Account, AccountRecord)], [(Text, Value)]) {
    assert(Principal.equal(caller, ctx.admin));
    (Iter.toArray(ctx.tokens.entries()), Iter.toArray(ctx.accounts.entries()), Iter.toArray(ctx.metadata.entries()))
  };

  public shared ({caller}) func updateTokenMetadata(args: [TokenMetadataArgs]): async [?TokenMetadataResult] {
    let (results, updatedCtx) = ICRC7.updateTokenMetadata(args, ctx, caller); 
    ctx := updatedCtx;
    return results;
  };  

  public shared ({caller}) func removeTokenMetadata(tokenId: Nat, key: Text): async (){
    ctx := Metadata.removeTokenMetadata(ctx, tokenId, key, caller);
  };  
  
  // Mint new NFT
  
  public shared ({caller}) func mintNFT(args: [MintArg]) : async [?MintResult] {
    let (results, updatedCtx) = ICRC7.mintNFT(args, ctx, caller);
    ctx := updatedCtx;
    return results;
  };

  public shared ({caller}) func burnNFT(arg: [BurnArg]): async [?TransferResult] {
    let (results, updatedCtx) = ICRC7.burnNFT(arg, ctx, caller);
    ctx := updatedCtx;
    return results;
  };

  public shared query ({caller}) func getAllAccountRecords(): async [(Account, AccountRecord)]{
    assert(Principal.equal(caller, ctx.admin));
    Iter.toArray(ctx.accounts.entries());
  };

  public query func icrc7_collection_metadata() : async [(Text, Value)] {
    return Iter.toArray(ctx.metadata.entries());
  };

  public query func icrc7_symbol() : async Text {
    Metadata.unwrapText("icrc7:symbol", "HVDP", ctx.metadata)
  };

  public query func debug_get_token(id: Nat): async ?TokenRecord {
    ctx.tokens.get(id)
  };

  public query func debug_get_account(account: Account): async ?AccountRecord {
    ctx.accounts.get(account)
  };

  public query func icrc7_name() : async Text {
    Metadata.unwrapText("icrc7:name", "HomeVestors DAO NFT", ctx.metadata);
  };

  public query func icrc7_description() : async ?Text {
    Metadata.unwrapTextOrNull("icrc7:description", ctx.metadata);
  };

  public query func icrc7_logo() : async ?Text {
    Metadata.unwrapTextOrNull("icrc7:logo", ctx.metadata);
  };

  public query func icrc7_total_supply() : async Nat {
    return Metadata.unwrapNat("icrc7:total_supply", ctx.totalSupply, ctx.metadata);
  };

  public query func icrc7_supply_cap() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc7:supply_cap", ctx.metadata);
  };

  public query func icrc7_max_query_batch_size() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc7:max_query_batch_size", ctx.metadata);
  };

  public query func icrc7_max_update_batch_size() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc7:max_update_batch_size", ctx.metadata);
  };

  public query func icrc7_default_take_value() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc7:default_take_value", ctx.metadata);
  };

  public query func icrc7_max_take_value() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc7:max_take_value", ctx.metadata);
  };

  public query func icrc7_max_memo_size() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc7:max_memo_size", ctx.metadata);
  };

  public query func icrc7_atomic_batch_transfers() : async ?Bool {
    return ?Metadata.icrc7_atomic_batch_transfers(ctx);
  };

  public query func icrc7_tx_window() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc7:tx_window", ctx.metadata);
  };

  public query func icrc7_permitted_drift() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc7:permitted_drift", ctx.metadata);
  };

  public query func icrc7_token_metadata(token_ids: [Nat]) : async [?[ (Text, Value) ]] {
    Metadata.icrc7_token_metadata(token_ids, ctx.tokens);
  };

  public query func icrc7_owner_of(token_ids: [Nat]) : async [ ?Account ] {
    ICRC7.icrc7_owner_of(token_ids, ctx.tokens);
  };

  public query func icrc7_balance_of(accounts: [Account]) : async [Nat] {
    ICRC7.icrc7_balance_of(accounts, ctx.accounts);
  };

  public query func icrc7_tokens(prev: ?Nat, take: ?Nat) : async [Nat] {
    ICRC7.icrc7_tokens(prev, take, ctx);
  };

  public query func icrc7_tokens_of(account: Account, prev: ?Nat, take: ?Nat): async [Nat] {
    ICRC7.icrc7_tokens_of(account, prev, take, ctx);  
  };

  public shared ({caller}) func icrc7_transfer(transfers: [TransferArg]) : async [ ?TransferResult ] {
    let (result, updatedCtx) = ICRC7.icrc7_transferHelper(transfers, ctx, caller);
    ctx := updatedCtx;
    return result;
  };



  ////////////////
  //////ICRC37
  ///////////////
  public query func icrc37_max_approvals_per_token_or_collection() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc37_max_approvals_per_token_or_collection", ctx.metadata);  // Set an arbitrary limit of 100 approvals per token/collection
  };

  public query func icrc37_max_revoke_approvals() : async ?Nat {
    return Metadata.unwrapNatOrNull("icrc37:max_revoke_approvals", ctx.metadata);  // Set an arbitrary limit of 100 approvals per token/collection
  };

  public shared ({caller}) func icrc37_approve_tokens(args: [ApproveTokenArg]) : async [ ?ApproveTokenResult ] {
    let (results, updatedCtx) = ICRC37.handleApproveTokenRecords(args, ctx, caller);
    ctx := updatedCtx;
    return results;
  };

  public shared ({caller}) func icrc37_approve_collection(args: [ApproveCollectionArg]) : async [ ?ApproveCollectionResult ] {
    let (results, updatedCtx) = ICRC37.handleApproveCollection(args, ctx, caller);
    ctx := updatedCtx;
    return results;
  };

  public shared ({caller}) func icrc37_revoke_token_approvals(args: [RevokeTokenApprovalArg]) : async [ ?RevokeTokenApprovalResponse ] {
    let (results, updatedCtx) = ICRC37.handleRevokeTokenApprovals(args, ctx, caller);
    ctx := updatedCtx;
    return results;
  };

  public shared ({caller}) func icrc37_revoke_collection_approvals(args: [RevokeCollectionApprovalArg]) : async [ ?RevokeCollectionApprovalResult ] {
    let (results, updatedCtx) = ICRC37.handleRevokeCollectionApproval(args, ctx, caller);
    ctx := updatedCtx;
    results;
  };

  public shared query ({caller}) func icrc37_is_approved(args: [IsApprovedArg]) : async [Bool] {
    ICRC37.handleIsApproved(args, caller, ctx);
  };

  public query func icrc37_get_token_approvals(token_id: Nat, prev: ?TokenApproval, take: ?Nat) : async [TokenApproval] {
    ICRC37.get_token_approvals(token_id, prev, take, ctx.tokens);
  };

  public query func icrc37_get_collection_approvals(owner: Account, prev: ?CollectionApproval, take: ?Nat) : async [CollectionApproval] {
    ICRC37.get_collection_approvals(owner, prev, take, ctx.accounts);
  };

  public shared ({caller}) func icrc37_transfer_from(args: [TransferFromArg]) : async [ ?TransferFromResult ] {
    let (results, updatedCtx) = ICRC37.handleTransferFrom(args, ctx, caller);
    ctx := updatedCtx;
    return results;
  };

  public query func icrc10_supported_standards() : async [SupportedStandards] {
    ICRC10.supported_standards();
  };

  public query func getErrors(start: ?Nat, take: ?Nat, argType: ?ArgFlag, errorType: ?ValidationErrorFlag): async [Error]{
    ELog.getErrors(start, take, argType, errorType, ctx);
  };

  //////////////////////////////////////
  //////ICRC3
  //////////////////////////////////////
  public query func icrc3_supported_block_types(): async [{ block_type: Text; url: Text }] {
    ICRC3.icrc3_supported_block_types();
  };

  public query func icrc3_get_archives(arg: GetArchivesArgs): async [GetArchivesResult] {
    return [];
  };

  public query func icrc3_get_tip_certificate(): async ?DataCertificate {
    ICRC3.icrc3_get_tip_certificate(ctx.cert);
  };

  public query func icrc3_get_blocks(arg: GetBlocksArgs): async GetBlocksResult{
    Ledger.icrc3_get_blocks(arg, ctx, Utils.takeSubArray);
  };

  

  
  system func preupgrade(){
    stableTokenRecords := Iter.toArray(ctx.tokens.entries());
    stableAccountRecords := Iter.toArray(ctx.accounts.entries());
    stableMetadata := Iter.toArray(ctx.metadata.entries());
    stableLedger := Iter.toArray(ctx.ledger.vals());
    stableErrors := Iter.toArray(ctx.errors.entries());
    stableTotalSupply := ctx.totalSupply;
    stableIndex := ctx.index;
    stableCert := ctx.cert;
    stablePhash := ctx.phash;
  };

  system func postupgrade (){
    ctx.tokens :=  HashMap.fromIter(stableTokenRecords.vals(), 0, Nat.equal, Utils.natToHash);
    ctx.accounts := HashMap.fromIter(stableAccountRecords.vals(), 0, Utils.accountEqual, Utils.accountHash);
    ctx.metadata := HashMap.fromIter(stableMetadata.vals(), 0, Text.equal, Text.hash);
    ctx.ledger := Buffer.fromArray<BlockValue>(stableLedger);
    ctx.errors := HashMap.fromIter(stableErrors.vals(), 0, Nat.equal, Utils.natToHash);
    ctx.totalSupply := stableTotalSupply;
    ctx.index := stableIndex;
    ctx.cert := stableCert;
    ctx.phash := stablePhash;
    stableTokenRecords := [];
    stableAccountRecords := [];
    stableMetadata := [];
    stableLedger := [];
    stableErrors := [];
    stableIndex := 0;
    stableTotalSupply := 0;
  };

};
