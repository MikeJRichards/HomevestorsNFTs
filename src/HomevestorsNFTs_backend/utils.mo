import Types "types";
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

    public func maxQuery(size: Nat, metadata:Metadata): Bool {
        switch(metadata.get("icrc7:max_query_batch_size")){
            case(?#Nat(n)) size > n;
            case(_) false;
        };
    };

    public func maxUpdate(size: Nat, metadata: Metadata): Bool {
        switch (metadata.get("icrc7:max_update_batch_size")) {
          case (?#Nat(n)) size > n;
          case (_) false;
        }
    };

    public func memoTooLarge(memo: ?Blob, metadata: Metadata): Bool {
      switch (memo, metadata.get("icrc7:max_memo_size")) {
        case (?m, ?#Nat(limit)) m.size() > limit;
        case (_) false;
      }
    };

    public func getTake(take: ?Nat, size: Nat, metadata: Metadata): Nat {
      switch (take, metadata.get("icrc7:default_take_value")) {
        case (?t, _) t;
        case (null, ?#Nat(d)) d;
        case(null, _) size; 
      }
    };

    public func getMaxTake(size: Nat, metadata: Metadata): Nat {
      switch (metadata.get("icrc7:max_take_value")) {
        case (?#Nat(t)) if(size > t) t else size;
        case(_) size; 
      }
    };

    public func tooOld(created_at_time: ?Nat64, metadata: Metadata): Bool {
      switch (created_at_time, metadata.get("icrc7:tx_window")) {
        case (?t, ?#Nat(w)) if(Time.now() - w > Nat64.toNat(t)) true else false;  
        case(_, _) false; 
      }
    };

    public func createdInFuture(created_at_time: ?Nat64, metadata: Metadata): Bool {
      switch (created_at_time, metadata.get("icrc7:permitted_drift")) {
        case (?t, ?#Nat(d)) if(Nat64.toNat(t) > Time.now() + d) true else false;  
        case(_, _) false; 
      }
    };

    public func maxApprovals(test: Bool, size: Nat, metadata: Metadata): Bool {
      switch (metadata.get("icrc37_max_approvals_per_token_or_collection"), test) {
        case (?#Nat(m), true) size > m;
        case(_, _) false; 
      }
    };

    public func maxApprovalRevokes(count: Nat, metadata: Metadata): Bool {
      switch (metadata.get("icrc37:max_revoke_approvals")) {
        case (?#Nat(m)) count > m; 
        case(_) false; 
      }
    };

    public func exceedMaxSupply(ctx: TxnContext): Bool {
      switch (ctx.metadata.get("icrc7:total_supply")) {
        case (?#Nat(m)) ctx.totalSupply + 1 > m; 
        case(_) false; 
      }
    };

    public func icrc7_atomic_batch_transfers(ctx: TxnContext): Bool {
      switch (ctx.metadata.get("icrc7:atomic_batch_transfers")) {
        case (?#Text("true")) true; 
        case(_) false; 
      }
    };

    public func findApproval(approvals :[ApprovalInfo], spender: Account): Bool {
      let time = Nat64.fromIntWrap(Time.now());
      for(approval in approvals.vals()){
        if(accountEqual(approval.spender, spender) and  Option.get(approval.expires_at, time) > time){
          return true;
        }
      };
      return false;
    };

    public func approvalExists(approvalExists: ?{spender: Account; btype: Text}, accountRecord: ?AccountRecord, tokenApprovals: ?[ApprovalInfo]): Result.Result<(), ValidationError> {
      let btype = switch(approvalExists, accountRecord, tokenApprovals){
        case(?arg, _, ?approvals) {
          if(findApproval(approvals, arg.spender)) return #ok() else arg.btype;
        };
        case(?arg, ?account, null){
          if(findApproval(account.approvals, arg.spender)) return #ok() else arg.btype;
        };
        case(_) return #ok();
      };
      return if(Text.equal(btype, "transfer")) #err(#StandardError(#Unauthorized)) else #err(#RevokeCollectionApprovalError(#ApprovalDoesNotExist));
    };

    func automaticity(err: ?ValidationError, ok: Intent, ctx: TxnContext, arg:  ValidationArg): ValidationOutcome {
        switch(err){
            case(null) return #ok((arg.arg, ok));
            case(?error) return if(icrc7_atomic_batch_transfers(ctx)) #err(#Automic) else #err(error);
        };
    };

    func verifyAccount(accountRecord: ?AccountRecord, arg: ValidationArg, ctx: TxnContext, lastErr: ?ValidationError):ValidationOutcome {
       var ok : Intent = #Caller(arg.caller);
       var err = lastErr;
        switch(accountRecord){
            case(null) err := ?#RevokeCollectionApprovalError(#ApprovalDoesNotExist);
            case(?account) {
              if(maxApprovals(arg.maxApprovals, account.approvals.size(), ctx.metadata)) err := ?#BaseError(#GenericError{error_code= 100; message = "Exceeds max allowances per collection"});
              switch(approvalExists(arg.approvalExists, ?account, null)){case(#ok()) ok := #Account(arg.caller, account); case(#err(e)) err := ?e};
            };
          };
        return automaticity(err, ok, ctx, arg);
    };

    func verifyToken(tokenRecord: ?TokenRecord, arg: ValidationArg, ctx: TxnContext, lastErr: ?ValidationError):ValidationOutcome {
       var ok : Intent = #Caller(arg.caller);
       var err = lastErr;
        switch(tokenRecord){
            case(null) return #err(#StandardError(#NonExistingTokenId));
            case(?token){
              if(verifyNullableAccounts(?token.owner, ?arg.caller, false)) err := ?#StandardError(#Unauthorized);
              if(maxApprovals(arg.maxApprovals, token.approvals.size(), ctx.metadata)) err := ?#BaseError(#GenericError{error_code= 100; message = "Exceeds max allowances per token"});
              switch(approvalExists(arg.approvalExists, ctx.accounts.get(token.owner), ?token.approvals)){case(#ok()) ok := #Token(arg.caller, token); case(#err(e)) err := ?e};
            };
        };
        return automaticity(err, ok, ctx, arg);
    };

    func verifyAdmin(account: Account, arg: ValidationArg, ctx: TxnContext, lastErr: ?ValidationError):ValidationOutcome {
        var ok : Intent = #Caller(arg.caller);
        var err = lastErr;
        if(verifyNullableAccounts(?account, ?arg.caller, false)) err := ?#StandardError(#Unauthorized);
        return automaticity(err, ok, ctx, arg);
    };


    public func verify(arg: ValidationArg, ctx: TxnContext): ValidationOutcome {
      var ok : Intent = #Caller(arg.caller);
      var error : ?ValidationError = null;
      if (createdInFuture(arg.created_at_time, ctx.metadata)) error := ?#BaseError(#CreatedInFuture { ledger_time = Nat64.fromIntWrap(Time.now()) });
      if (tooOld(arg.created_at_time, ctx.metadata)) error := ?#BaseError(#TooOld);
      if (verifyNullableAccounts(?arg.caller, arg.recipient, false)) error := ?#TransferError(#InvalidRecipient);
      if(memoTooLarge(arg.memo, ctx.metadata)) error := ?#BaseError(#GenericError{error_code = 200; message = "Memo too large"});
      if (verifyNullableAccounts(?arg.caller, arg.spender, false)) error := ?#ApproveCollectionError(#InvalidSpender);  // Can't approve self
      if(arg.minting and exceedMaxSupply(ctx)) error := ?#MintError(#ExceedsMaxSupply);
      
      return switch(arg.authorized){
        case(?#Account(accountRecord)) verifyAccount(accountRecord, arg, ctx, error);
        case(?#Token(tokenRecord)) verifyToken(tokenRecord, arg, ctx, error);
        case(?#Admin(account)) verifyAdmin(account, arg, ctx, error);
        case(_) automaticity(error, ok, ctx, arg);
      } 
    };

    public func validate<T <: BaseArg>(arg: Arg, x: T, authorized: ?Authorized, spender: ?Account, caller: Principal, ctx: TxnContext, count: Nat):  ValidationResult {
      if(maxUpdate(count, ctx.metadata)) return #err(#GenericError{error_code = 500; message = "Exceeds max update size"});
      let validationArg : ValidationArg = {
        arg;
        created_at_time = x.created_at_time;
        spender = spender;
        memo = x.memo;
        caller = {owner = caller; subaccount = x.from_subaccount};
        recipient = switch(arg){case(#Transfer(arg)) ?arg.to; case(#TransferFrom(arg)) ?arg.to; case(_) null};
        authorized;
        minting = switch(arg){case(#Mint(arg)) true; case(_) false};
        maxApprovals = switch(arg){case(#ApproveToken(arg)) true; case(#ApproveCollection(arg)) true; case(_) false};
        approvalExists = switch(arg, spender){case(#RevokeToken(arg), ?spender) ?{spender = spender; btype = "revoke"}; case(#TransferFrom(arg), ?spender) ?{spender = spender; btype = "transfer"}; case(#RevokeCollection(arg), ?spender) ?{spender = spender; btype = "revoke"}; case(_) null};
      };

      switch(verify(validationArg, ctx)){
        case(#ok(result)) return #ok(#ok(result));
        case(#err(#Automic)) return #err(#GenericBatchError{error_code = 500; message = "element "#Nat.toText(count)#" failed validation"});
        case(#err(e)) return #ok(#err(e));
      };
    };

  
    
   

    public func updateTokenRecordOnTransfer(tokens: TokenRecords, id: Nat, newOwner: Account, transactionType: TransactionType): TokenRecords {
      switch(tokens.get(id)){
        case(null){return tokens};
        case(?record){
          let updatedRecord : TokenRecord = {
            owner = newOwner;
            metadata = record.metadata;
            history = Array.append(record.history, [(newOwner.owner, Time.now(), transactionType)]);
            approvals = [];
          };
          tokens.put(id, updatedRecord);
          return tokens;
        }
      };
    };

    public func updateAccountRecord(record: AccountRecord, tokenId: Nat, transactionType: TransactionType): AccountRecord {
      switch(transactionType){
        case(#Receive or #Mint){
          {
            balance = record.balance + 1;
            owned_tokens = Array.append(record.owned_tokens, [tokenId]);
            approvals = record.approvals;
          }
        };
        case(#Send or #Burn){
          {
            balance = if (record.balance <= 0) 0 else Nat.sub(record.balance, 1);
            owned_tokens = Array.filter<(Nat)>(record.owned_tokens, func(k) {k != tokenId});
            approvals = record.approvals;
          };
        };
        case(_){record};
      };
    };

    public func updateAccountRecordsOnTransfer(accountBalances: AccountRecords, account: Account, tokenId: Nat, transactionType: TransactionType): AccountRecords {
      switch(accountBalances.get(account)){
        case(null){
          let newRecord : AccountRecord = {
            balance = if(transactionType == #Receive or transactionType == #Mint) 1 else 0;
            owned_tokens = [tokenId];
            approvals = [];
          };
          accountBalances.put(account, newRecord);
          return accountBalances;
        };
        case(?record){
          accountBalances.put(account, updateAccountRecord(record, tokenId, transactionType));
          return accountBalances;
        };
      }
    };

    public func takeSubArray<T>(prev: ?Nat, take: ?Nat, arr: [T], metadata: Metadata): [T] {
      let startIndex = Option.get(prev, 0);
      if (startIndex >= arr.size()) return [];

      let requestedTake = getTake(take, arr.size(), metadata);

      let available = Nat.sub(arr.size(), startIndex);
      let finalTake = Nat.min(getMaxTake(requestedTake, metadata), available);

      return Array.subArray<T>(arr, startIndex, finalTake);
    };





}