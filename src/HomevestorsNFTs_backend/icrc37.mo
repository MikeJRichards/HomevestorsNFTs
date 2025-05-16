import Types "types";
import Utils "utils";
import Nat "mo:base/Nat";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Ledger "ledger";

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

    public func removeApproval(approvals: [ApprovalInfo], spender: ?Account): [ApprovalInfo]{
        let remainingApprovals = Buffer.Buffer<ApprovalInfo>(approvals.size());
        for(approval in approvals.vals()){
            if(Utils.verifyNullableAccounts(spender, ?approval.spender, true)){
                remainingApprovals.add(approval);
            };
        };
        Iter.toArray(remainingApprovals.vals());
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

   func appendOrUpdateApprovalInfo(newApproval: ApprovalInfo, arr: [ApprovalInfo]): [ApprovalInfo] {
        let indexOpt = Array.indexOf<ApprovalInfo>(
            newApproval,
            arr,
            func (a, b) { a.spender == b.spender }
        );
    
        switch (indexOpt) {
            case (null) return Array.append(arr, [newApproval]);
            case (_)    return Array.map<ApprovalInfo, ApprovalInfo>(arr, func (a) {
                if (a.spender == newApproval.spender) newApproval else a
            });
        };
    };

    func addOrUpdateCollectionApproval(arg: ApproveCollectionArg, accountRecord: ?AccountRecord): AccountRecord {
      switch(accountRecord){
          case(?account){
              {account with approvals = appendOrUpdateApprovalInfo(arg.approval_info, account.approvals)};
          };
          case(null){
            {
              balance = 0;
              owned_tokens = [];
              approvals = [arg.approval_info];
            };
          }
      }
    };

    public func handleApproveTokenRecords(args: [ApproveTokenArg], ctx: TxnContext, caller: Principal): ([?ApproveTokenResult], TxnContext) {
      let validations = Buffer.Buffer<ValidationOutcome>(args.size());
      for(i in Iter.range(0, args.size())){
        switch(Utils.validate(#ApproveToken(args[i]), {args[i].approval_info with created_at_time = ?args[i].approval_info.created_at_time}, ?#Token(ctx.tokens.get(args[i].token_id)), ?args[i].approval_info.spender, caller, ctx, i)){
          case(#err(e)) return ([?#Err(e)], ctx);
          case(#ok(result)) validations.add(result);
        }
      };
      var results = Buffer.Buffer<?ApproveTokenResult>(args.size());
      for (validation in validations.vals()) {
         switch(validation){
            case(#err(#ApproveCollectionError(e: ApproveTokenError)) or #err(#BaseError(e: ApproveTokenError)) or #err(#StandardError(e: ApproveTokenError))) results.add(?#Err(e));
            case(#ok((#ApproveToken(arg), #Token(_, token)))){
              ctx.tokens.put(arg.token_id, {token with approvals = appendOrUpdateApprovalInfo(arg.approval_info, token.approvals)});
              ctx.index += 1;
              results.add(?#Ok(ctx.index));
              ctx.ledger.put(ctx.index, Ledger.createBlock(#ApproveToken(arg.approval_info, arg.token_id, {owner = caller; subaccount = arg.approval_info.from_subaccount})));
            };
            case(_) results.add(?#Err(#GenericError{error_code = 998; message = "canister error"}));
          };
        };
      return (Iter.toArray(results.vals()), ctx);
    };

    public func handleApproveCollection(args: [ApproveCollectionArg], ctx: TxnContext, caller: Principal): ([?ApproveCollectionResult], TxnContext) {
      let validations = Buffer.Buffer<ValidationOutcome>(args.size());
      for(i in Iter.range(0, args.size())){
        switch(Utils.validate(#ApproveCollection(args[i]), {args[i].approval_info with created_at_time = ?args[i].approval_info.created_at_time}, ?#Account(ctx.accounts.get({owner = caller; subaccount = args[i].approval_info.from_subaccount})), ?args[i].approval_info.spender, caller, ctx, i)){
          case(#err(e)) return ([?#Err(e)], ctx);
          case(#ok(result)) validations.add(result);
        }
      };
      var results = Buffer.Buffer<?ApproveCollectionResult>(args.size());
      for (validation in validations.vals()) {
         switch(validation){
            case(#err(#ApproveCollectionError(e)) or #err(#BaseError(e))) results.add(?#Err(e));
            case(#ok((#ApproveCollection(arg), #Account(callerAccount, accountRecord)))){
                ctx.index += 1;
                ctx.accounts.put(callerAccount, addOrUpdateCollectionApproval(arg, ?accountRecord));
                results.add(?#Ok(ctx.index));
                ctx.ledger.put(ctx.index, Ledger.createBlock(#ApproveCollection(arg.approval_info, callerAccount)));
            };
            case(_) results.add(?#Err(#GenericError{error_code = 998; message = "canister error"}));
          };
        };
      return (Iter.toArray(results.vals()), ctx);
    };

    public func handleRevokeTokenApprovals(args: [RevokeTokenApprovalArg], ctx: TxnContext, caller: Principal): ([?RevokeTokenApprovalResponse], TxnContext) {
      let validations = Buffer.Buffer<ValidationOutcome>(args.size());
      for(i in Iter.range(0, args.size())){
        switch(Utils.validate(#RevokeToken(args[i]), args[i], ?#Token(ctx.tokens.get(args[i].token_id)), args[i].spender, caller, ctx, i)){
          case(#err(e)) return ([?#Err(e)], ctx);
          case(#ok(result)) validations.add(result);
        }
      };
      var results = Buffer.Buffer<?RevokeTokenApprovalResponse>(args.size());
      for (validation in validations.vals()) {
         switch(validation){
            case(#err(#BaseError(e: RevokeTokenApprovalError)) or #err(#StandardError(e: RevokeTokenApprovalError)) or #err(#RevokeCollectionApprovalError(e: RevokeTokenApprovalError))) results.add(?#Err(e));
            case(#ok((#RevokeToken(arg), #Token(callerAccount, token)))){
                ctx.tokens.put(arg.token_id, {token with approvals = removeApproval(token.approvals, arg.spender)});
                ctx.index += 1;
                results.add(?#Ok(ctx.index));
                ctx.ledger.put(ctx.index, Ledger.createBlock(#RevokeTokenApproval(arg, callerAccount)));
            };
            case(_) results.add(?#Err(#GenericError{error_code = 998; message = "canister error"}));
          };
        };
      return (Iter.toArray(results.vals()), ctx);
    };

    public func handleRevokeCollectionApproval(args: [RevokeCollectionApprovalArg], ctx: TxnContext, caller: Principal): ([?RevokeCollectionApprovalResult], TxnContext) {
      let validations = Buffer.Buffer<ValidationOutcome>(args.size());
      for(i in Iter.range(0, args.size())){
        switch(Utils.validate(#RevokeCollection(args[i]), args[i], ?#Account(ctx.accounts.get({owner = caller; subaccount = args[i].from_subaccount})), args[i].spender, caller, ctx, i)){
          case(#err(e)) return ([?#Err(e)], ctx);
          case(#ok(result)) validations.add(result);
        }
      };
      var results = Buffer.Buffer<?RevokeCollectionApprovalResult>(args.size());
      for (validation in validations.vals()) {
         switch(validation){
            case(#err(#BaseError(e: RevokeCollectionApprovalError)) or #err(#RevokeCollectionApprovalError(e))) results.add(?#Err(e));
            case(#ok((#RevokeCollection(arg), #Account(callerAccount, account)))){
              ctx.accounts.put(callerAccount, {account with approvals = removeApproval(account.approvals, arg.spender)});
              ctx.index += 1;
              results.add(?#Ok(ctx.index));
              ctx.ledger.put(ctx.index, Ledger.createBlock(#RevokeCollection(arg, callerAccount)));
            };
            case(_) results.add(?#Err(#GenericError{error_code = 998; message = "canister error"}));
          };
        };
      return (Iter.toArray(results.vals()), ctx);
    };

    public func handleTransferFrom(args: [TransferFromArg], ctx: TxnContext, caller: Principal): ([?TransferFromResult], TxnContext) {
      let validations = Buffer.Buffer<ValidationOutcome>(args.size());
      for(i in Iter.range(0, args.size())){
        switch(Utils.validate(#TransferFrom(args[i]), {args[i] with from_subaccount = args[i].spender_subaccount}, ?#Token(ctx.tokens.get(args[i].token_id)), ?{owner = caller; subaccount = args[i].spender_subaccount}, caller, ctx, i)){
          case(#err(e)) return ([?#Err(e)], ctx);
          case(#ok(result)) validations.add(result);
        }
      };
      var results = Buffer.Buffer<?TransferFromResult>(args.size());
      for (validation in validations.vals()) {
         switch(validation){
            case(#err(#TransferError(e: TransferFromError)) or #err(#BaseError(e: TransferFromError)) or #err(#StandardError(e: TransferFromError))) results.add(?#Err(e));
            case(#ok((#TransferFrom(arg), #Token(callerAccount, _)))){
              ctx.tokens := Utils.updateTokenRecordOnTransfer(ctx.tokens, arg.token_id, arg.to, #TransferFrom);
              ctx.accounts := Utils.updateAccountRecordsOnTransfer(ctx.accounts, arg.to, arg.token_id, #Receive);
              ctx.accounts := Utils.updateAccountRecordsOnTransfer(ctx.accounts, arg.from, arg.token_id, #Send);
              ctx.index += 1;
              results.add(?#Ok(ctx.index));
              ctx.ledger.put(ctx.index, Ledger.createBlock(#TransferFrom(arg, callerAccount)))
            };
            case(_) results.add(?#Err(#GenericError{error_code = 998; message = "canister error"}));
          };
        };
      return (Iter.toArray(results.vals()), ctx);
    };

    public func supported_standards() : [SupportedStandards] {
        return [
            {name = "ICRC-7"; url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-7";},  // Declares support for ICRC-7 version 1.0
            {name = "ICRC-10"; url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-10";},   // Declares support for ICRC-7 version 1.0
            {name = "ICRC-37"; url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-37";}   // Declares support for ICRC-7 version 1.0
        ];
    };


}