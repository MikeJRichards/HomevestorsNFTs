import Types "types";
import Utils "utils";
import Ledger "ledger";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Time "mo:base/Time";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";


module ICRC7 {
    type Account = Types.Account;
    type TransferArg = Types.TransferArg;
    type TransferResult = Types.TransferResult;
    type TokenRecords = Types.TokenRecords;
    type AccountRecords = Types.AccountRecords;
    type BurnArg = Types.BurnArg;
    type TokenRecord = Types.TokenRecord;
    type TransferError = Types.TransferError;
    type MintArg = Types.MintArg;
    type MintResult = Types.MintResult;
    type TxnContext = Types.TxnContext;
    type MintError = Types.MintError;
    type ValidationOutcome = Types.ValidationOutcome;
    
    public func icrc7_transferHelper(args: [TransferArg], ctx: TxnContext, caller: Principal): ([?TransferResult], TxnContext) {
      let validations = Buffer.Buffer<ValidationOutcome>(args.size());
      for(i in Iter.range(0, args.size())){
        switch(Utils.validate(#Transfer(args[i]), args[i], ?#Token(ctx.tokens.get(args[i].token_id)), null, caller, ctx, i)){
          case(#err(e)) return ([?#Err(e)], ctx);
          case(#ok(result)) validations.add(result);
        }
      };
      var results = Buffer.Buffer<?TransferResult>(args.size());
      for (validation in validations.vals()) {
          switch(validation){
            case(#err(#TransferError(e)) or #err(#BaseError(e: TransferError)) or #err(#StandardError(e: TransferError))) results.add(?#Err(e));
            case(#ok((#Transfer(arg), #Token(caller, _)))){
              ctx.tokens := Utils.updateTokenRecordOnTransfer(ctx.tokens, arg.token_id, arg.to, #Transfer);
              ctx.accounts := Utils.updateAccountRecordsOnTransfer(ctx.accounts, arg.to, arg.token_id, #Receive);
              ctx.accounts := Utils.updateAccountRecordsOnTransfer(ctx.accounts, caller, arg.token_id, #Send);
              ctx.index += 1;
              ctx.ledger.put(ctx.index, Ledger.createBlock(#Transfer(arg, caller)));
              results.add(?#Ok(ctx.index));
            };
            case(_) results.add(?#Err(#GenericError{error_code = 998; message = "canister error"}));
          };
        };
      return (Iter.toArray(results.vals()), ctx);
    };

     func mintNewToken(arg: MintArg): TokenRecord {
      {
        owner = arg.to;
        metadata = arg.meta;
        history = [(arg.to.owner, Time.now(), #Mint)];
        approvals = [];
      }
    };

    func updateCtxOnSuccessfulMint(ctx: TxnContext, from:Account, arg: MintArg): TxnContext {
      ctx.tokens.put(ctx.totalSupply, mintNewToken(arg));
      ctx.accounts:= Utils.updateAccountRecordsOnTransfer(ctx.accounts, from, ctx.totalSupply, #Mint);
      ctx.totalSupply += 1;
      ctx.index += 1;
      ctx.ledger.put(ctx.index, Ledger.createBlock(#Mint(arg, from, ctx.totalSupply)));
      return ctx;
    }; 

    public func mintNFT(args: [MintArg], ctx: TxnContext, caller: Principal): ([?MintResult], TxnContext) {
      let validations = Buffer.Buffer<ValidationOutcome>(args.size());
      for(i in Iter.range(0, args.size())){
        switch(Utils.validate(#Mint(args[i]), args[i], ?#Admin({owner = ctx.admin; subaccount = args[i].from_subaccount}), null, caller, ctx, i)){
          case(#err(e)) return ([?#Err(e)], ctx);
          case(#ok(result)) validations.add(result);
        }
      };
      var results = Buffer.Buffer<?MintResult>(args.size());
      var updatedCtx = ctx;
      for (validation in validations.vals()) {
            switch(validation){
          case(#err(#TransferError(e: MintError)) or #err(#BaseError(e: MintError)) or #err(#StandardError(e: MintError)) or #err(#MintError(e))) results.add(?#Err(e));
          case(#ok((#Mint(arg), #Caller(from)))){
            updatedCtx := updateCtxOnSuccessfulMint(updatedCtx, from, arg);
            results.add(?#Ok(ctx.index));
          };
          case(_) results.add(?#Err(#GenericError{error_code = 998; message = "invalid response";}));
        };
        };
      ctx.metadata.put("icrc7:total_supply", #Nat(ctx.totalSupply));
      return (Iter.toArray(results.vals()), ctx);
    };

    public func burnNFT(args: [BurnArg], ctx: TxnContext, caller: Principal): ([?TransferResult], TxnContext) {
      let validations = Buffer.Buffer<ValidationOutcome>(args.size());
      for(i in Iter.range(0, args.size())){
        switch(Utils.validate(#Burn(args[i]), args[i], ?#Token(ctx.tokens.get(args[i].token_id)), null, caller, ctx, i)){
          case(#err(e)) return ([?#Err(e)], ctx);
          case(#ok(result)) validations.add(result);
        }
      };
      var results = Buffer.Buffer<?TransferResult>(args.size());
      for (validation in validations.vals()) {
         switch (validation) {
          case (#err(#BaseError(e : TransferError)) or #err(#StandardError(e: TransferError)) or #err(#TransferError(e))) results.add(?#Err(e));
          case (#ok((#Burn(arg), #Token(callerAccount, token)))){
              ctx.tokens.delete(arg.token_id);
              ctx.accounts := Utils.updateAccountRecordsOnTransfer(ctx.accounts, token.owner, arg.token_id, #Burn);
              ctx.totalSupply := ctx.totalSupply - 1;
              ctx.index += 1;
              ctx.ledger.put(ctx.index, Ledger.createBlock(#Burn(arg, callerAccount)));
              results.add(?#Ok(ctx.index));
          };
          case(_) {results.add(?#Err(#GenericError{error_code = 998; message = "invalid response";}))};
        };
        };
      ctx.metadata.put("icrc7:total_supply", #Nat(ctx.totalSupply));
      return (Iter.toArray(results.vals()), ctx);
    };

    public func icrc7_owner_of(token_ids: [Nat], tokens: TokenRecords) : [ ?Account ] {
        return Array.map<Nat, ?Account>(token_ids, func (id) { 
          switch(tokens.get(id)){
            case(null){ null };
            case(?record){ ?record.owner }
          } 
        });
    };

    public func icrc7_balance_of(accounts: [Account], accountBalances: AccountRecords): [Nat] {
        return Array.map<Account, Nat>(accounts, func (account) {
            switch(accountBalances.get(account)){
              case(null){0};
              case(?record){record.balance}
            }
        });
    };

    public func icrc7_tokens(prev: ?Nat, take: ?Nat, ctx: TxnContext): [Nat] {
      let tokenIds = Array.sort(Iter.toArray(ctx.tokens.keys()), Nat.compare);
      Utils.takeSubArray<Nat>(prev, take, tokenIds, ctx.metadata);
    };

    public func icrc7_tokens_of(account: Account, prev: ?Nat, take: ?Nat, ctx: TxnContext): [Nat] {
      let ownedTokens = switch (ctx.accounts.get(account)) {
          case (null) return [];
          case (?record) Array.sort(record.owned_tokens, Nat.compare);
      };
      Utils.takeSubArray<Nat>(prev, take, ownedTokens, ctx.metadata);
    };   


}   