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
    type BlockOp = Types.BlockOp;
    type Block = Types.Block;
    type Tx = Types.Tx;

    

    public func createBlock(op: BlockOp): Block {
        {
            btype = createBtype(op);
            ts = Int.abs(Time.now());
            tx = createTX(op);
        }
    };

    func createTX(op: BlockOp): Tx {
        switch(op){
            case(#Mint(arg, from, tid)) createMintTx(arg, from, tid);
            case(#Burn(arg, from)) createBurnTx(arg, from);
            case(#Transfer(arg, from)) createTransferTx(arg, from);
            case(#Meta(arg, from)) createMetaTx(arg, from);
            case(#ApproveToken(arg, tokenId, from)) createApproveTx(arg, ?tokenId, from);
            case(#ApproveCollection(arg, from)) createApproveTx(arg, null, from);
            case(#RevokeTokenApproval(arg, from)) createRevokeTokenTx(arg, from);
            case(#RevokeCollection(arg, from)) createRevokeCollectionTx(arg, from);
            case(#TransferFrom(arg, spender)) createTransferFromTx(arg, spender);
        }
    };

    func createBtype(op: BlockOp): Text {
        switch(op){
            case(#Mint(_))"7mint";
            case(#Burn(_))"7burn";
            case(#Transfer(_))"7xfer";
            case(#Meta(_))"7update_token";
            case(#ApproveToken(_))"37approve";
            case(#ApproveCollection(_))"37approve_coll";
            case(#RevokeTokenApproval(_))"37revoke";
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