import Types "types";
import Ledger "ledger";
import Meta "metadata";
import ELog "errorlogging";
import Hash "mo:base/Hash";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
import Option "mo:base/Option";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import HashMap "mo:base/HashMap";

module {
    type Account = Types.Account;
    type ApprovalInfo = Types.ApprovalInfo;
    type AccountRecord = Types.AccountRecord;
    type ValidationError = Types.ValidationError;
    type ValidationArg = Types.ValidationArg;
    type TxnContext = Types.TxnContext;
    type ValidationOutcome = Types.ValidationOutcome;
    type BaseArg = Types.BaseArg;
    type Arg = Types.Arg;
    type Authorized = Types.Authorized;
    type ValidationResult = Types.ValidationResult;
    type TokenRecords = Types.TokenRecords;
    type TransactionType = Types.TransactionType;
    type AccountRecords = Types.AccountRecords;
    type Metadata = Types.Metadata;
    type Intent = Types.Intent;
    type TokenRecord = Types.TokenRecord;
    type MintArg = Types.MintArg;
    type ApproveCollectionArg = Types.ApproveCollectionArg;
    type Value = Types.Value;
    type Error = Types.Error;
    type ArgFlag = Types.ArgFlag;
    type ValidationErrorFlag = Types.ValidationErrorFlag;
    

    public func safeSub(a: Nat, b: Nat): Nat {
        if (a < b) 0 else Nat.sub(a, b);
    };

    public func safeSubNat64(a: Nat64, b: Nat64): Nat64 {
        if (a < b) 0 else Nat64.sub(a, b);
    };

    public func accountEqual(a : Account, b : Account) : Bool {
         Principal.equal(a.owner, b.owner) and
         blobEqual(a.subaccount, b.subaccount)
     };

    public func verifyNullableAccounts(a: ?Account, b: ?Account, supposedToBeDifferent: Bool): Bool {
      switch(a, b, supposedToBeDifferent){
        case(?account1, ?account2, false) accountEqual(account1, account2);
        case(?account1, ?account2, true) not accountEqual(account1, account2);
        case(_, _, _) false;
      }
    };

       // Helper function to compare optional Blobs
    public func blobEqual(a : ?Blob, b : ?Blob) : Bool {
        switch (a, b) {
          case (null, null) true;
          case (?a, ?b) Blob.equal(a, b);
          case _ false;
        }
    };

    public func accountHash(account: Account): Hash.Hash {
        let ownerBlob = Principal.hash(account.owner);
        let subaccountBlob = switch (account.subaccount) {
            case null { Blob.hash(Blob.fromArray([])) };
            case (?sub) { Blob.hash(sub)};
        };
        return ownerBlob ^ subaccountBlob;
    };

    public func natToHash(n: Nat): Hash.Hash {
       Text.hash(Nat.toText(n));  
    };

    

    public func findApproval(approvals :[ApprovalInfo], spender: Account): Bool {
      let time = Nat64.fromIntWrap(Time.now());
      for(approval in approvals.vals()){
        if(accountEqual(approval.spender, spender) and  Option.get(approval.expires_at, time) >= time){
          return true;
        };
      };
      return false;
    };

    public func approvalExists(spenderAcc: ?Account, btype: ?{#TransferFrom; #Revoke}, accountRecord: ?AccountRecord, tokenApprovals: ?[ApprovalInfo]): Result.Result<(), ValidationError> {
      let enum = switch(spenderAcc, btype, accountRecord, tokenApprovals){
        case(?spender, ?btype, ?accountRecord, ?approvals) {
          //Debug.print("path 1 " # debug_show(btype));
          if(findApproval(Array.append(approvals, accountRecord.approvals), spender)) return #ok() else btype;
        };
        case(?spender, ?btype, null, ?approvals) {
          //Debug.print("path 2 " # debug_show(btype));
          if(findApproval(approvals, spender)) return #ok() else btype;
        };
        case(?spender, ?btype, ?account, null){
          //Debug.print("path 3 " # debug_show(btype));
          if(findApproval(account.approvals, spender)) return #ok() else btype;
        };
        case(_) {
          //Debug.print("path 4 - find approval not called spender"#debug_show(spenderAcc)#" btype "# debug_show(btype)#" account record "#debug_show(accountRecord)#" token approvals "#debug_show(tokenApprovals));
        return #ok();
        }
      };
      return if(enum == #TransferFrom) #err(#StandardError(#Unauthorized)) else #err(#RevokeCollectionApprovalError(#ApprovalDoesNotExist));
    };

    func automaticity(err: ?ValidationError, ok: ?Intent, ctx: TxnContext): ValidationOutcome {
        switch(err, ok){
            case(null, ?ok) return #ok(ok);
            case(?error, _) return if(Meta.icrc7_atomic_batch_transfers(ctx)) #err(#Automic) else #err(error);
            case(null, null) return #err(#LogicError);
        };
    };

    func verifyAccount(accountRecord: ?AccountRecord, arg: ValidationArg, ctx: TxnContext, lastErr: ?ValidationError):ValidationOutcome {
       let ok = createIntent(arg, null, accountRecord);
       var err = lastErr;
       switch(accountRecord){
            case(null)switch(arg.arg){case(#RevokeCollection(_)) err := ?#RevokeCollectionApprovalError(#ApprovalDoesNotExist); case(_){}; };// 
            case(?account) {
              if(Meta.maxApprovals(arg.maxApprovals, account.approvals.size(), ctx.metadata)) err := ?#BaseError(#GenericError{error_code= 100; message = "Exceeds max allowances per collection"});
              switch(approvalExists(arg.spender, arg.approvalExists, accountRecord, null)){case(#err(e)) err := ?e; case(_){}};
            };
          };
        return automaticity(err, ok, ctx);
    };

    func createIntent(validation: ValidationArg, tokenRecord: ?TokenRecord, accountRecord: ?AccountRecord): ?Intent {
      switch(validation.arg, tokenRecord, accountRecord){
        case(#Burn(arg), ?token, _) ?#Burn(arg, validation.caller, token);
        case(#Transfer(arg), ?token, _) ?#Transfer(arg, validation.caller, token);
        case(#ApproveToken(arg), ?token, _) ?#ApproveToken(arg, validation.caller, token);
        case(#RevokeToken(arg), ?token, _) ?#RevokeToken(arg, validation.caller, token);
        case(#TransferFrom(arg), ?token, _) ?#TransferFrom(arg, validation.caller, token);
        case(#UpdateMetadata(arg), ?token, _) ?#UpdateMetadata(arg, validation.caller, token);
        case(#ApproveCollection(arg), _, account) ?#ApproveCollection(arg, validation.caller, account);
        case(#RevokeCollection(arg), _, ?account) ?#RevokeCollection(arg, validation.caller, account);
        case(#Mint(arg), null, null) ?#Mint(arg, validation.caller);
        case(_)null;
      }
    };

    func verifyToken(tokenRecord: ?TokenRecord, arg: ValidationArg, ctx: TxnContext, lastErr: ?ValidationError):ValidationOutcome {
       var ok = createIntent(arg, tokenRecord, null);
       var err = lastErr;
        switch(tokenRecord){
            case(null) err := ?#StandardError(#NonExistingTokenId);
            case(?token){
              if(Meta.maxApprovals(arg.maxApprovals, token.approvals.size(), ctx.metadata)) err := ?#BaseError(#GenericError{error_code= 100; message = "Exceeds max allowances per token"});
              switch(arg.arg){case(#TransferFrom(_)){}; case(_) if(verifyNullableAccounts(?token.owner, ?arg.caller, true)) err := ?#StandardError(#Unauthorized);};
              switch(approvalExists(arg.spender, arg.approvalExists, ctx.accounts.get(token.owner), ?token.approvals)){case(#ok()){}; case(#err(e)) err := ?e;};
            };
        };
        return automaticity(err, ok, ctx);
    };

    func verifyAdmin(account: Account, arg: ValidationArg, ctx: TxnContext, lastErr: ?ValidationError):ValidationOutcome {
        var err = lastErr;
        var token : ?TokenRecord = null;
        switch(arg.arg){
          case(#UpdateMetadata(arg)){
            switch(ctx.tokens.get(arg.token_id)){
              case(?t) token := ?t; 
              case(null) err := ?#StandardError(#NonExistingTokenId);
            }; 
          };
          case(_) {}
        };
        if(verifyNullableAccounts(?account, ?arg.caller, true)) err := ?#StandardError(#Unauthorized);
        var ok = createIntent(arg, token, null);
        return automaticity(err, ok, ctx);
    };

  public func verify(arg: ValidationArg, ctx: TxnContext): ValidationOutcome {
    var error : ?ValidationError = null;
    if (Meta.createdInFuture(arg.created_at_time, ctx.metadata)) error := ?#BaseError(#CreatedInFuture { ledger_time = Nat64.fromIntWrap(Time.now()) });
    if (Meta.tooOld(arg.created_at_time, ctx.metadata)) error := ?#BaseError(#TooOld);
    //removed this check for now - as you can transfer to yourself, so this now passes but state is not changed on these functions - still need to ensure you can't send to yourself
    //if (verifyNullableAccounts(?arg.caller, arg.recipient, false)) error := ?#TransferError(#InvalidRecipient);
    if(Principal.isAnonymous(arg.caller.owner)) switch(arg.arg){case(#ApproveCollection(_) or #RevokeCollection(_))error := ?#BaseError(#GenericError{error_code = 700; message = "Anonymous Principal"}); case(_) error := ?#StandardError(#Unauthorized)}; 
    if(Meta.memoTooLarge(arg.memo, ctx.metadata)) error := ?#BaseError(#GenericError{error_code = 200; message = "Memo too large"});
    if(arg.minting and Meta.exceedMaxSupply(ctx)) error := ?#MintError(#ExceedsMaxSupply);
    if (verifyNullableAccounts(?arg.caller, arg.spender, false)) switch(arg.arg){case(#TransferFrom(_) or #RevokeToken(_)){}; case(_)  error := ?#ApproveCollectionError(#InvalidSpender);};  // Can't approve self
    
    return switch(arg.authorized){
      case(#Account(accountRecord)) verifyAccount(accountRecord, arg, ctx, error);
      case(#Token(tokenRecord)) verifyToken(tokenRecord, arg, ctx, error);
      case(#Admin(account)) verifyAdmin(account, arg, ctx, error);
    } 
  };

  public func validate(arg: Arg, caller: Principal, ctx: TxnContext, count: Nat):  ValidationResult {
    if(Meta.maxUpdate(count, ctx.metadata)) return #err(#GenericError{error_code = 500; message = "Exceeds max update size"});
    //Debug.print("Arg "#debug_show(arg));
    let (from_subaccount, memo, created_at_time, spender, auth) = getSubaccountMemoAndTimeFromArg(arg, ctx, caller);
    //Debug.print("Auth "#debug_show(auth));
    let validationArg : ValidationArg = {
      arg;
      created_at_time;
      spender;
      memo;
      authorized = auth;
      caller = {owner = caller; subaccount = from_subaccount};
      recipient = switch(arg){case(#Transfer(arg)) ?arg.to; case(#TransferFrom(arg)) ?arg.to; case(_) null};
      minting = switch(arg){case(#Mint(arg)) true; case(_) false};
      maxApprovals = switch(arg){case(#ApproveToken(arg)) true; case(#ApproveCollection(arg)) true; case(_) false};
      approvalExists = switch(arg){case(#RevokeToken(arg) or #RevokeCollection(arg)) ?#Revoke; case(#TransferFrom(arg)) ?#TransferFrom; case(_) null};
    };
    //Debug.print("Validation Arg: "#debug_show(validationArg));
    switch(verify(validationArg, ctx)){
      case(#ok(result)) return #ok(#ok(result));
      case(#err(#Automic)) return #err(#GenericBatchError{error_code = 500; message = "element "#Nat.toText(count)#" failed validation"});
      case(#err(#LogicError)) return #err(#GenericBatchError{error_code = 600; message = "canister logic error"});
      case(#err(e)) return #ok(#err(e));
    };
  };

  func getSubaccountMemoAndTimeFromArg(arg: Arg, ctx: TxnContext, caller: Principal): (?Blob, ?Blob, ?Nat64, ?Account, Authorized) {
    //Indented to improve readability (from_subaccount, memo, created_at_time, spender, auth)
    switch(arg){
      case(#Mint(arg))              (arg.from_subaccount,                 arg.memo,               arg.created_at_time,                null,                                                   #Admin(ctx.admin)); 
      case(#Burn(arg))              (arg.from_subaccount,                 arg.memo,               arg.created_at_time,                null,                                                   #Token(ctx.tokens.get(arg.token_id))); 
      case(#Transfer(arg))          (arg.from_subaccount,                 arg.memo,               arg.created_at_time,                null,                                                   #Token(ctx.tokens.get(arg.token_id))); 
      case(#ApproveCollection(arg)) (arg.approval_info.from_subaccount,   arg.approval_info.memo, ?arg.approval_info.created_at_time, ?arg.approval_info.spender,                             #Account(ctx.accounts.get({owner = caller; subaccount = arg.approval_info.from_subaccount}))); 
      case(#ApproveToken(arg))      (arg.approval_info.from_subaccount,   arg.approval_info.memo, ?arg.approval_info.created_at_time, ?arg.approval_info.spender,                             #Token(ctx.tokens.get(arg.token_id))); 
      case(#RevokeCollection(arg))  (arg.from_subaccount,                 arg.memo,               arg.created_at_time,                arg.spender,                                            #Account(ctx.accounts.get({owner = caller; subaccount = arg.from_subaccount}))); 
      case(#RevokeToken(arg))       (arg.from_subaccount,                 arg.memo,               arg.created_at_time,                arg.spender,                                            #Token(ctx.tokens.get(arg.token_id))); 
      case(#TransferFrom(arg))      (arg.spender_subaccount,              arg.memo,               arg.created_at_time,                ?{owner = caller; subaccount = arg.spender_subaccount}, #Token(ctx.tokens.get(arg.token_id))); 
      case(#UpdateMetadata(arg))    (arg.from_subaccount,                 arg.memo,               arg.created_at_time,                null,                                                   #Admin(ctx.admin));
    };
  };

  public func batchExecute<A, E>(args: [A], ctx: TxnContext, caller: Principal, toArg: (A) -> Arg, handleValidationError: (ValidationError) -> E): [?{#Ok: Nat; #Err: E}] {
    let (results, stateChange) = verify_func<A,E>(args, ctx, caller, toArg, handleValidationError);

    for(intent in stateChange.vals()){
      switch(intent){
        case(#Err(arg, error)) ctx.errors.put(ctx.errors.size(), ELog.createError(ctx.errors.size(), arg, error, caller));
        case(#Ok(intent)) updateState(intent, ctx);
      }
    };

    return results;
  };

  public func verify_func<A, E>(args:[A], ctx: TxnContext, caller: Principal, toArg: (A) -> Arg, handleValidationError: (ValidationError) -> E): ([?{#Ok: Nat; #Err: E}], [{#Ok: Intent; #Err: (Arg, ValidationError)}]){
    let results = Buffer.Buffer<?{#Ok: Nat; #Err: E}>(args.size());
    let outcome = Buffer.Buffer<{#Ok: Intent; #Err: (Arg, ValidationError)}>(args.size());
    for(i in args.keys()){
      switch(validate(toArg(args[i]), caller, ctx, i)){
        case(#err(e)) return ([?#Err(handleValidationError(#BaseError(e)))], [#Err(toArg(args[i]), #BaseError(e))]);
        case(#ok(#err(e))){
          results.add(?#Err(handleValidationError(e)));
          outcome.add(#Err(toArg(args[i]), e));
        };
        case(#ok(#ok(intent))) {
          results.add(?#Ok(ctx.index + i));
          outcome.add(#Ok(intent));
        };
      };
    };
    return (Buffer.toArray(results), Buffer.toArray(outcome));
  };

   func mintNewToken(arg: MintArg): TokenRecord {
      {
        owner = arg.to;
        metadata = arg.meta;
        approvals = [];
      }
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

    public func removeApproval(approvals: [ApprovalInfo], spender: ?Account): [ApprovalInfo]{
        let remainingApprovals = Buffer.Buffer<ApprovalInfo>(approvals.size());
        for(approval in approvals.vals()){
            if(verifyNullableAccounts(spender, ?approval.spender, true)){
                remainingApprovals.add(approval);
            };
        };
        Iter.toArray(remainingApprovals.vals());
    };

    public func updateState(intent: Intent, ctx: TxnContext): () {
      switch(intent){
        case(#Transfer(arg, caller, token)){
          if(accountEqual(arg.to, caller)) return;
          ctx.tokens.put(arg.token_id, {token with owner = arg.to; approvals = []});
          ctx.accounts.put(arg.to, updateAccountRecordsOnTransfer(ctx.accounts.get(arg.to), arg.token_id, #Receive));
          ctx.accounts.put(caller, updateAccountRecordsOnTransfer(ctx.accounts.get(caller), arg.token_id, #Send));
        };
        case(#Mint(arg, _)){
          ctx.totalSupply := ctx.totalSupply + 1;
          ctx.tokens.put(ctx.totalSupply, mintNewToken(arg));
          ctx.accounts.put(arg.to, updateAccountRecordsOnTransfer(ctx.accounts.get(arg.to), ctx.totalSupply, #Receive));
        };
        case(#Burn(arg, _, token)){
          ctx.tokens.delete(arg.token_id);
          ctx.accounts.put(token.owner, updateAccountRecordsOnTransfer(ctx.accounts.get(token.owner), arg.token_id, #Send));
          ctx.totalSupply := ctx.totalSupply - 1;
        };
        case(#TransferFrom(arg, _, token)){
          if(accountEqual(arg.to, arg.from)) return;
          ctx.tokens.put(arg.token_id, {token with owner = arg.to; approvals = []});
          ctx.accounts.put(arg.to, updateAccountRecordsOnTransfer(ctx.accounts.get(arg.to), arg.token_id, #Receive));
          ctx.accounts.put(arg.from, updateAccountRecordsOnTransfer(ctx.accounts.get(arg.from), arg.token_id, #Send));
        };
        case(#ApproveToken(arg, _, token)) ctx.tokens.put(arg.token_id, {token with approvals = appendOrUpdateApprovalInfo(arg.approval_info, token.approvals)});
        case(#ApproveCollection(arg, callerAccount, accountRecord)) ctx.accounts.put(callerAccount, addOrUpdateCollectionApproval(arg, accountRecord));
        case(#RevokeToken(arg, _, token)) ctx.tokens.put(arg.token_id, {token with approvals = removeApproval(token.approvals, arg.spender)});
        case(#RevokeCollection(arg, callerAccount, account)) ctx.accounts.put(callerAccount, {account with approvals = removeApproval(account.approvals, arg.spender)});
        case(#UpdateMetadata(arg, _, token)){
          let tokenMetadata = HashMap.fromIter<Text, Value>(token.metadata.vals(), token.metadata.size(), Text.equal, Text.hash);
          tokenMetadata.put(arg.key, arg.value);
         ctx.tokens.put(arg.token_id, {token with metadata = Iter.toArray(tokenMetadata.entries())});
        };
      };
      Ledger.updateLedger(intent, ctx);
    };

    public func updateAccountRecordsOnTransfer(account: ?AccountRecord, tokenId: Nat, transactionType: TransactionType): AccountRecord {
      switch(account, transactionType){
        case(null, #Receive){
          {
            balance =  1;
            owned_tokens = [tokenId];
            approvals = [];
          };
        };
        case(?record, #Receive){
          {
            balance = record.balance + 1;
            owned_tokens = Array.append(record.owned_tokens, [tokenId]);
            approvals = record.approvals;
          }
        };
        case(?record, #Send){
          {
            balance = if (record.balance <= 0) 0 else Nat.sub(record.balance, 1);
            owned_tokens = Array.filter<(Nat)>(record.owned_tokens, func(k) {k != tokenId});
            approvals = record.approvals;
          };
        };
        case(null, #Send){
          {
            balance =  0;
            owned_tokens = [];
            approvals = [];
          };
        };
      };
    };

    public func takeSubArray<T>(prev: ?Nat, take: ?Nat, arr: [T], metadata: Metadata): [T] {
      let startIndex = Option.get(prev, 0);
      if (startIndex >= arr.size()) return [];

      let requestedTake = Meta.getTake(take, arr.size(), metadata);

      let available = Nat.sub(arr.size(), startIndex);
      let finalTake = Nat.min(Meta.getMaxTake(requestedTake, metadata), available);

      return Array.subArray<T>(arr, startIndex, finalTake);
    };

    




}