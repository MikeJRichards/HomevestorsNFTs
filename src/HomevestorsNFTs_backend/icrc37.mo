import Types "types";
import Utils "utils";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Principal "mo:base/Principal";

module {
    type TransferFromArg = Types.TransferFromArg;
    type AccountRecords = Types.AccountRecords;
    type Account = Types.Account;
    type TransferFromError = Types.TransferFromError;
    type TransferFromResult = Types.TransferFromResult;
    type IsApprovedArg = Types.IsApprovedArg;
    type RevokeCollectionApprovalArg = Types.RevokeCollectionApprovalArg;
    type AccountRecord = Types.AccountRecord;
    type RevokeCollectionApprovalError = Types.RevokeCollectionApprovalError;
    type ApprovalInfo = Types.ApprovalInfo;
    type RevokeTokenApprovalArg = Types.RevokeTokenApprovalArg;
    type RevokeTokenApprovalError = Types.RevokeTokenApprovalError;
    type ApproveCollectionArg = Types.ApproveCollectionArg;
    type ApproveTokenArg = Types.ApproveTokenArg;
    type ApproveTokenError = Types.ApproveTokenError;
    type ApproveTokenResult = Types.ApproveTokenResult;
    type ApproveCollectionResult = Types.ApproveCollectionResult;
    type RevokeTokenApprovalResponse = Types.RevokeTokenApprovalResponse;
    type RevokeCollectionApprovalResult = Types.RevokeCollectionApprovalResult;
    type TokenApproval = Types.TokenApproval;
    type CollectionApproval = Types.CollectionApproval;
    type TokenRecords = Types.TokenRecords;
    type TxnContext = Types.TxnContext;
    type SupportedStandards = Types.SupportedStandards;
    type ValidationOutcome = Types.ValidationOutcome;
    type ValidationError = Types.ValidationError;

    public func get_token_approvals(token_id: Nat, prev: ?TokenApproval, take: ?Nat, tokens: TokenRecords) : [TokenApproval] {
        switch (tokens.get(token_id)) {
          case (null) { return []; }; // No approvals exist for this NFT
          case (?tokenRecord) {
            let startIndex = switch(prev){case(?p) Option.get( Array.indexOf<ApprovalInfo>(p.approval_info, tokenRecord.approvals, func (a, b) { a == b }), 0); case (null) 0;};
            let length = Nat.sub(Nat.min(Option.get(take, tokenRecord.approvals.size()), tokenRecord.approvals.size()), startIndex);
            let sortedArray = Array.sort<ApprovalInfo>(tokenRecord.approvals, func (a, b) {Text.compare(Principal.toText(a.spender.owner), Principal.toText(b.spender.owner))});
            let filteredApprovals = Array.subArray<ApprovalInfo>(sortedArray, startIndex, length); // sub == [3, 4, 5]
            return Array.map<ApprovalInfo, TokenApproval>(filteredApprovals, func a = { token_id = token_id; approval_info = a});
          }; 
        }
    };

 

    public func get_collection_approvals(owner: Account, prev: ?CollectionApproval, take: ?Nat, accountBalances: AccountRecords) : [CollectionApproval] {
        switch (accountBalances.get(owner)) {
          case (null) { return []; }; // No approvals exist for this NFT
          case (?accountRecord) {
            let startIndex = switch(prev){case(?p) Option.get( Array.indexOf<ApprovalInfo>(p, accountRecord.approvals, func (a, b) { a == b }), 0); case (null) 0;};
            let length = Nat.sub(Nat.min(Option.get(take, accountRecord.approvals.size()), accountRecord.approvals.size()), startIndex);
            let sortedArray = Array.sort<ApprovalInfo>(accountRecord.approvals, func (a, b) {Text.compare(Principal.toText(a.spender.owner), Principal.toText(b.spender.owner))});
            Array.subArray<ApprovalInfo>(sortedArray, startIndex, length); // sub == [3, 4, 5]
          }; 
        }
    };

    public func handleIsApproved(args: [IsApprovedArg], caller: Principal, ctx: TxnContext): [Bool]{
      let results = Buffer.Buffer<Bool>(args.size());
      for(arg in args.vals()){
        let tokenApprovals = switch(ctx.tokens.get(arg.token_id)){case(?t)t.approvals; case(null)[]};
        let accountApprovals = switch(ctx.accounts.get({owner= caller; subaccount = arg.from_subaccount})){case(?accountRecord) accountRecord.approvals; case(null)[]};
        let approvals = Array.append(tokenApprovals, accountApprovals);
        results.add(Utils.findApproval(approvals, arg.spender));
      };
      Iter.toArray(results.vals());
    };

    public func handleApproveTokenValidationError(error: ValidationError): ?ApproveTokenResult {
      switch(error){
        case(#ApproveCollectionError(e: ApproveTokenError) or #BaseError(e: ApproveTokenError) or #StandardError(e: ApproveTokenError)) return ?#Err(e);
        case(_) return ?#Err(#GenericError{error_code = 998; message = "invalid response";})
      }
    };

    public func handleApproveCollectionValidationError(error: ValidationError): ?ApproveCollectionResult {
      switch(error){
        case(#ApproveCollectionError(e) or #BaseError(e)) return ?#Err(e);
        case(_) return ?#Err(#GenericError{error_code = 998; message = "invalid response";})
      }
    };

    public func handleRevokeTokenApprovalValidationError(error: ValidationError): ?RevokeTokenApprovalResponse {
      switch(error){
        case(#BaseError(e: RevokeTokenApprovalError) or #StandardError(e: RevokeTokenApprovalError) or #RevokeCollectionApprovalError(e: RevokeTokenApprovalError)) return ?#Err(e);
        case(_) return ?#Err(#GenericError{error_code = 998; message = "invalid response";})
      }
    };

    public func handleRevokeCollectionApprovalValidationError(error: ValidationError): ?RevokeCollectionApprovalResult {
      switch(error){
        case(#BaseError(e: RevokeCollectionApprovalError) or #RevokeCollectionApprovalError(e)) return ?#Err(e);
        case(_) return ?#Err(#GenericError{error_code = 998; message = "invalid response";})
      }
    };

    public func handleTransferFromValidationError(error: ValidationError): ?TransferFromResult {
      switch(error){
        case(#TransferError(e: TransferFromError) or #BaseError(e: TransferFromError) or #StandardError(e: TransferFromError)) return ?#Err(e);
        case(_) return ?#Err(#GenericError{error_code = 998; message = "invalid response";})
      }
    };

  

    public func handleApproveTokenRecords(args: [ApproveTokenArg], ctx: TxnContext, caller: Principal): ([?ApproveTokenResult], TxnContext) {
      Utils.batchExecute<ApproveTokenArg, ApproveTokenResult>(args, ctx, caller, func(arg: ApproveTokenArg) { #ApproveToken(arg) },  handleApproveTokenValidationError, func(index) { ?#Ok(index) });
    };

    public func handleApproveCollection(args: [ApproveCollectionArg], ctx: TxnContext, caller: Principal): ([?ApproveCollectionResult], TxnContext) {
      Utils.batchExecute<ApproveCollectionArg, ApproveCollectionResult>(args, ctx, caller, func(arg: ApproveCollectionArg) { #ApproveCollection(arg) },  handleApproveCollectionValidationError, func(index) { ?#Ok(index) });
    };

    public func handleRevokeTokenApprovals(args: [RevokeTokenApprovalArg], ctx: TxnContext, caller: Principal): ([?RevokeTokenApprovalResponse], TxnContext) {
      Utils.batchExecute<RevokeTokenApprovalArg, RevokeTokenApprovalResponse>(args, ctx, caller, func(arg: RevokeTokenApprovalArg) { #RevokeToken(arg) },  handleRevokeTokenApprovalValidationError, func(index) { ?#Ok(index) });
    };

    public func handleRevokeCollectionApproval(args: [RevokeCollectionApprovalArg], ctx: TxnContext, caller: Principal): ([?RevokeCollectionApprovalResult], TxnContext) {
      Utils.batchExecute<RevokeCollectionApprovalArg, RevokeCollectionApprovalResult>(args, ctx, caller, func(arg: RevokeCollectionApprovalArg) { #RevokeCollection(arg) },  handleRevokeCollectionApprovalValidationError, func(index) { ?#Ok(index) });
    };

    public func handleTransferFrom(args: [TransferFromArg], ctx: TxnContext, caller: Principal): ([?TransferFromResult], TxnContext) {
      Utils.batchExecute<TransferFromArg, TransferFromResult>(args, ctx, caller, func(arg: TransferFromArg) { #TransferFrom(arg) },  handleTransferFromValidationError, func(index) { ?#Ok(index) });
    };




}