import Types "types";
import Meta "metadata";
import Option "mo:base/Option";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Nat64 "mo:base/Nat64";
import Time "mo:base/Time";
module {
    type ArgFlag = Types.ArgFlag;
    type Error = Types.Error;
    type ValidationErrorFlag = Types.ValidationErrorFlag;
    type TxnContext = Types.TxnContext;
    type Arg = Types.Arg;
    type ValidationError = Types.ValidationError;

    public func createError(id: Nat, arg: Arg, error: ValidationError, caller: Principal): Error{
        {
          id;
          arg;
          error;
          caller;
          time = Nat64.fromIntWrap(Time.now());
        };
    };

    func sameErrorArg(arg: ?ArgFlag, error: Error): Bool {
    switch(arg, error.arg){
      case(?#Mint, #Mint(_)) true;
      case(?#Burn, #Burn(_)) true;
      case(?#Transfer, #Transfer(_)) true;
      case(?#ApproveCollection, #ApproveCollection(_)) true;
      case(?#ApproveToken, #ApproveToken(_)) true;
      case(?#RevokeCollection, #RevokeCollection(_)) true;
      case(?#RevokeToken, #RevokeToken(_)) true;
      case(?#TransferFrom, #TransferFrom(_)) true;
      case(?#UpdateMetadata, #UpdateMetadata(_)) true;
      case(null, _) true;
      case(_, _) false
    }
  };

  func sameValidationError(validationError: ?ValidationErrorFlag, error: Error): Bool {
    switch(validationError, error.error){
      case(?#TransferError, #TransferError(_)) true;
      case(?#MintError, #MintError(_)) true;
      case(?#ApproveTokenError, #ApproveTokenError(_)) true;
      case(?#RevokeTokenApprovalError, #RevokeTokenApprovalError(_)) true;
      case(?#StandardError, #StandardError(_)) true;
      case(?#BaseError, #BaseError(_)) true;
      case(?#ApproveCollectionError, #ApproveCollectionError(_)) true;
      case(?#RevokeCollectionApprovalError, #RevokeCollectionApprovalError(_)) true;
      case(?#Automic, #Automic) true;
      case(?#LogicError, #LogicError) true;
      case(null, _) true;
      case(_, _) false;
    }
  };
  
  public func getErrors(start: ?Nat, take: ?Nat, argType: ?ArgFlag, errorType: ?ValidationErrorFlag, ctx: TxnContext): [Error]{
    let startIndex = Option.get(start, 0);
    if (startIndex >= ctx.errors.size()) return [];
    var updatedTake = Meta.getTake(take, ctx.errors.size(), ctx.metadata);
    let errors = Buffer.Buffer<Error>(0);
    let allErrors = Iter.toArray(ctx.errors.vals());
    let relevantErrors = Array.subArray<Error>(allErrors, startIndex, updatedTake);
    for(error in relevantErrors.vals()){
      if(sameErrorArg(argType, error) and sameValidationError(errorType, error)) {
        errors.add(error);
        updatedTake -= 1;
      };
      if(updatedTake == 0) return Iter.toArray(errors.vals());
    };
    return Iter.toArray(errors.vals());
  };

}