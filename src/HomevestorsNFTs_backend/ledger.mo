import Types "types";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Int "mo:base/Int";
import Option "mo:base/Option";

module {
    type Account = Types.Account;
    type ApprovalInfo = Types.ApprovalInfo;
    type BurnArg = Types.BurnArg;
    type TransferArg = Types.TransferArg;
    type RevokeTokenApprovalArg = Types.RevokeTokenApprovalArg;
    type RevokeCollectionApprovalArg = Types.RevokeCollectionApprovalArg;
    type TransferFromArg = Types.TransferFromArg;
    type TokenMetadataArg = Types.TokenMetadataArg;
    type MintArg = Types.MintArg;
    type Block = Types.Block;
    type Tx = Types.Tx;
    type Arg = Types.Arg;
    type Intent = Types.Intent;
    type TxnContext = Types.TxnContext;

    

    public func updateLedger(intent: Intent, ctx: TxnContext): TxnContext {
        let block = {
             btype = createBtype(intent);
             ts = Int.abs(Time.now());
             tx = createTX(intent, ctx.totalSupply);
        };
        ctx.index += 1;
        ctx.ledger.put(ctx.index, block);
        return ctx;
    };

    func createTX(intent: Intent, tid: Nat): Tx {
        switch(intent){
            case(#Mint(arg, from)) createMintTx(arg, from, tid);
            case(#Burn(arg, from, _)) createBurnTx(arg, from);
            case(#Transfer(arg, from, _)) createTransferTx(arg, from);
            case(#UpdateMetadata(arg, from, _)) createMetaTx(arg, from);
            case(#ApproveToken(arg, from, _)) createApproveTx(arg.approval_info, ?arg.token_id, from);
            case(#ApproveCollection(arg, from, _)) createApproveTx(arg.approval_info, null, from);
            case(#RevokeToken(arg, from, _)) createRevokeTokenTx(arg, from);
            case(#RevokeCollection(arg, from, _)) createRevokeCollectionTx(arg, from);
            case(#TransferFrom(arg, callerAccount, _)) createTransferFromTx(arg, callerAccount);
        }
    };

    func createBtype(intent: Intent): Text {
        switch(intent){
            case(#Mint(_))"7mint";
            case(#Burn(_))"7burn";
            case(#Transfer(_))"7xfer";
            case(#UpdateMetadata(_))"7update_token";
            case(#ApproveToken(_))"37approve";
            case(#ApproveCollection(_))"37approve_coll";
            case(#RevokeToken(_))"37revoke";
            case(#RevokeCollection(_))"37revoke_coll";
            case(#TransferFrom(_))"37xfer";
        }
    };

    func emptyTx(): Tx {
        {
            tid = null;
            from = null;
            to = null;
            spender = null;
            exp = null;
            meta = null;
            memo = null;
            ts = null;
        }
    };

    func createApproveTx(arg: ApprovalInfo, tid: ?Nat, from: Account): Tx {
        {
            emptyTx() with 
            tid = tid;
            from = ?from;
            spender = ?arg.spender;
            exp = Option.map<Nat64, Nat>(arg.expires_at, Nat64.toNat);
            memo = arg.memo;
            ts = ?Nat64.toNat(arg.created_at_time)
        };
    };

    func createRevokeTokenTx(arg: RevokeTokenApprovalArg, from: Account): Tx {
        {
            emptyTx() with
            tid = ?arg.token_id;
            from = ?from;
            spender = arg.spender;
            memo = arg.memo;
            ts = Option.map<Nat64, Nat>(arg.created_at_time, Nat64.toNat);
        };
    };

    func createRevokeCollectionTx(arg: RevokeCollectionApprovalArg, from: Account): Tx {
        {
            emptyTx() with
            from = ?from;
            spender = arg.spender;
            memo = arg.memo;
            ts = Option.map<Nat64, Nat>(arg.created_at_time, Nat64.toNat);
        };
    };


    func createBurnTx(arg: BurnArg, from: Account): Tx {
        {
            emptyTx() with
            tid = ?arg.token_id;
            from = ?from;
            memo = arg.memo;
            ts = Option.map<Nat64, Nat>(arg.created_at_time, Nat64.toNat);
        };
    };

    func createTransferTx(arg: TransferArg, from: Account): Tx {
        {
            emptyTx() with
            tid = ?arg.token_id;
            from = ?from;
            to = ?arg.to;
            memo = arg.memo;
            ts = Option.map<Nat64, Nat>(arg.created_at_time, Nat64.toNat);
        };
    };

    func createTransferFromTx(arg: TransferFromArg, spender: Account): Tx {
        {
            emptyTx() with
            tid = ?arg.token_id;
            from = ?arg.from;
            to = ?arg.to;
            spender = ?spender;
            memo = arg.memo;
            ts = Option.map<Nat64, Nat>(arg.created_at_time, Nat64.toNat); 
        };
    };

    func createMetaTx(arg: TokenMetadataArg, from: Account): Tx {
        {
            emptyTx() with
            tid = ?arg.token_id;
            from = ?from;
            meta = ?#Map([(arg.key, arg.value)]);
            memo = arg.memo;
            ts = Option.map<Nat64, Nat>(arg.created_at_time, Nat64.toNat);
        };
    };

    func createMintTx(arg: MintArg, from: Account, tid: Nat): Tx {
        {
            emptyTx() with
            tid = ?tid;
            from = ?from;
            to = ?arg.to;
            meta = ?#Map(arg.meta);
            memo = arg.memo;
            ts = Option.map<Nat64, Nat>(arg.created_at_time, Nat64.toNat);
        };
    };


}