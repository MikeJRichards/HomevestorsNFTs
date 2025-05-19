import Types "types";
import Utils "utils";
import Principal "mo:base/Principal";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Array "mo:base/Array";

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
    type ValidationError = Types.ValidationError;
    type Arg = Types.Arg;
    type Intent = Types.Intent;
    type BaseError = Types.BaseError;
    type TokenMetadataResult = Types.TokenMetadataResult;
    type TokenMetadataArg = Types.TokenMetadataArg;
    type StandardError = Types.StandardError;

    public func handleMintValidationError(error: ValidationError): ?MintResult {
      switch(error){
        case(#TransferError(e: MintError) or #BaseError(e: MintError) or #StandardError(e: MintError) or #MintError(e)) return ?#Err(e);
        case(_) return ?#Err(#GenericError{error_code = 998; message = "invalid response";})
      }
    };

    public func handleTransferValidationError(error: ValidationError): ?TransferResult {
      switch(error){
        case(#TransferError(e) or #BaseError(e: TransferError) or #StandardError(e: TransferError)) return ?#Err(e);
        case(_) return ?#Err(#GenericError{error_code = 998; message = "invalid response";})
      }
    };
    
    public func icrc7_transferHelper(args: [TransferArg], ctx: TxnContext, caller: Principal): ([?TransferResult], TxnContext) {
      Utils.batchExecute<TransferArg, TransferResult>(args, ctx, caller, func(arg: TransferArg) { #Transfer(arg) },  handleTransferValidationError, func(index) { ?#Ok(index) });
    };

   

    public func mintNFT(args: [MintArg], ctx: TxnContext, caller: Principal): ([?MintResult], TxnContext) {
      let (results, updatedCtx) = Utils.batchExecute<MintArg, MintResult>(args, ctx, caller, func(arg: MintArg) { #Mint(arg) },  handleMintValidationError, func(index) { ?#Ok(index) });
      updatedCtx.metadata.put("icrc7:total_supply", #Nat(updatedCtx.totalSupply));
      return (results, updatedCtx);
    };

    public func burnNFT(args: [BurnArg], ctx: TxnContext, caller: Principal): ([?TransferResult], TxnContext) {
      let (results, updatedCtx) = Utils.batchExecute<BurnArg, TransferResult>(args, ctx, caller, func(arg: BurnArg) { #Burn(arg) },  handleTransferValidationError, func(index) { ?#Ok(index) });
      updatedCtx.metadata.put("icrc7:total_supply", #Nat(updatedCtx.totalSupply));
      return (results, updatedCtx);
    };

    public func handleMetadataUpdateValidationError(error: ValidationError): ?TokenMetadataResult {
      switch(error){
        case(#BaseError(e: StandardError) or #StandardError(e)) return ?#Err(e);
        case(_) return ?#Err(#GenericError{error_code = 998; message = "invalid response";})
      }
    };

    public func updateTokenMetadata(args: [TokenMetadataArg], ctx: TxnContext, caller: Principal): ([?TokenMetadataResult], TxnContext) {
      Utils.batchExecute<TokenMetadataArg, TokenMetadataResult>(args, ctx, caller, func(arg: TokenMetadataArg) { #UpdateMetadata(arg) },  handleMetadataUpdateValidationError, func(index) { ?#Ok(index) });
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