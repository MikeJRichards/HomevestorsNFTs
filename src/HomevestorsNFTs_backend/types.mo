import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import CertTree "mo:ic-certification/CertTree";
import Buffer "mo:base/Buffer";

module {
    public type TxnContext = {
      var index: Nat;
      var totalSupply : Nat;
      var tokens: TokenRecords;
      var ledger: Blocks;
      var accounts: AccountRecords;
      var metadata: Metadata;
      var errors : HashMap.HashMap<Nat, Error>;
      var phash: Blob;
      var cert : CertTree.Store;
      admin: Principal;
    };

    public type Error = {
        id: Nat;
        arg: Arg;
        error: ValidationError;
        time: Nat64;
        caller: Principal;
    };

    public type Subaccount = Blob;
    
    public type Account = {
        owner : Principal;
        subaccount :?Subaccount;
    };

    public type TokenMetadataArg = {
      token_id: Nat;
      key: Text;
      value: Value;
      from_subaccount: ?Blob;
      created_at_time: ?Nat64;
      memo: ?Blob;
    };

    public type TokenMetadataResult = {
      #Ok: Nat;
      #Err: StandardError;
    };

    
    public type BlockValue = {
        id: Nat;
        block: Value;
    };

    public  type GetArchivesResult = [{
        canister_id : Principal; // The id of the archive
        start : Nat; // The first block in the archive
        end : Nat; // The last block in the archive
    }];

  public type GetArchivesArgs = {
    // The last archive seen by the client.
    // The Ledger will return archives coming
    // after this one if set, otherwise it
    // will return the first archives.
    from : ?Principal;
  };

  public type GetBlocksArgs = [{ 
    start : Nat; 
    length : Nat; 
  }];


  public type GetBlocksResult = {
    // Total number of blocks in the
    // block log
    log_length : Nat;
    blocks : [{ id : Nat; block: Value }];
    archived_blocks : [{
        args : GetBlocksArgs;
        callback : query GetBlocksArgs -> async GetBlocksResult;
    }];
  };

    

    public type Block = {
        phash: Blob;
        btype : Text;
        ts: Nat;
        tx: Tx;
    };

    public type Tx = {
        tid : ?Nat; //token id
        from: ?Account;
        to: ?Account;
        spender: ?Account;
        exp: ?Nat;
        meta: ?Value;
        memo: ?Blob;
        ts: ?Nat;
    };

    public type MintResult = {
      #Ok: Nat;
      #Err: MintError;
    };
    
    public type Value = {
        #Blob : Blob; 
        #Text : Text; 
        #Nat : Nat;
        #Int : Int;
        #Array : [Value]; 
        #Map : [(Text, Value)];
    };

    public type ValidationArg = {
        arg: Arg;
        created_at_time: ?Nat64;
        caller: Account;
        recipient: ?Account;
        spender: ?Account;
        authorized: Authorized;
        memo: ?Blob;
        maxApprovals: Bool;
        approvalExists: ?{#TransferFrom; #Revoke};
        minting: Bool;
    };

    public type Authorized = {
      #Account: ?AccountRecord;
      #Token: ?TokenRecord;
      #Admin: Account;
    };


    public type Arg = {
      #Mint: MintArg;
      #Burn: BurnArg;
      #Transfer: TransferArg;
      #ApproveCollection : ApproveCollectionArg;
      #ApproveToken: ApproveTokenArg;
      #RevokeCollection : RevokeCollectionApprovalArg;
      #RevokeToken : RevokeTokenApprovalArg;
      #TransferFrom : TransferFromArg;
      #UpdateMetadata: TokenMetadataArg;
    };

    public type ArgFlag = {
        #Mint;
        #Burn;
        #Transfer;
        #ApproveCollection;
        #ApproveToken;
        #RevokeCollection;
        #RevokeToken;
        #TransferFrom;
        #UpdateMetadata;
    };

    public type Intent = {
        #Mint: (MintArg, Account);
        #ApproveCollection: (ApproveCollectionArg, Account, AccountRecord);
        #RevokeCollection: (RevokeCollectionApprovalArg, Account, AccountRecord);
        #Burn : (BurnArg, Account, TokenRecord);
        #Transfer :(TransferArg, Account, TokenRecord);
        #ApproveToken: (ApproveTokenArg, Account, TokenRecord);
        #RevokeToken: (RevokeTokenApprovalArg, Account, TokenRecord);
        #TransferFrom: (TransferFromArg, Account, TokenRecord);
        #UpdateMetadata: (TokenMetadataArg, Account, TokenRecord);
    };


    
    public type BurnArg = {
        token_id : Nat;
        from_subaccount : ?Blob;
        memo: ?Blob;
        created_at_time: ?Nat64;
    };
    
    
    public type MintArg = {
      meta: [(Text, Value)];
      from_subaccount: ?Blob;
      to: Account;
      memo: ?Blob;
      created_at_time: ?Nat64;
    };

    public type ApprovalInfo = {
        spender : Account;             // Approval is given to an ICRC Account
        from_subaccount : ?Blob;    // The subaccount the token can be transferred out from with the approval
        expires_at : ?Nat64;
        memo : ?Blob;
        created_at_time : Nat64; 
    };
    
    public type ApproveCollectionArg = {
        approval_info : ApprovalInfo;
    };

    public type ApproveTokenArg = {
        token_id : Nat;
        approval_info : ApprovalInfo;
    };

    public type TransferArg = BurnArg and {
        to: Account;
    };

    public type RevokeCollectionApprovalArg = {
        spender : ?Account;      // null revokes approvals for all spenders that match the remaining parameters
        from_subaccount : ?Blob; // null refers to the default subaccount
        memo : ?Blob;
        created_at_time : ?Nat64;
    };

    public type RevokeTokenApprovalArg = RevokeCollectionApprovalArg and {
        token_id : Nat;
    };

    public type DataCertificate = {
        certificate : Blob;
        hash_tree : Blob;
    };


 

    public type IsApprovedArg = {
        spender : Account;
        from_subaccount : ?Blob;
        token_id : Nat;
    };

    public type TransferFromArg = {
        spender_subaccount: ?Blob; // The subaccount of the caller (used to identify the spender) - essentially equivalent to from_subaccount
        from : Account;
        to : Account;
        token_id : Nat;
        memo : ?Blob;
        created_at_time : ?Nat64;
    };


    public type TransferResult = {
        #Ok : Nat; // Transaction index for successful transfer
        #Err : TransferError;
    };

    public type BaseError = {
        #TooOld;
        #CreatedInFuture : {ledger_time: Nat64};
        #GenericError : {error_code : Nat; message : Text};
        #GenericBatchError : {error_code : Nat; message : Text};
    };
    
    public type RevokeCollectionApprovalError = BaseError or {
        #ApprovalDoesNotExist;
    };

    public type ApproveCollectionError = BaseError or  {
        #InvalidSpender;
    };

    public type StandardError = BaseError or {
        #Unauthorized;
        #NonExistingTokenId;
    };

    public type RevokeTokenApprovalError = StandardError or  {
        #ApprovalDoesNotExist;
    };

    public type ApproveTokenError = StandardError or {
        #InvalidSpender;
    };

    public type TransferError = StandardError or {
        #InvalidRecipient;
        #Duplicate : {duplicate_of : Nat};
    };

    public type TransferFromError = TransferError;

    public type MintError = TransferError or {
        #ExceedsMaxSupply;
    };

    public type BaseArg = {
      from_subaccount: ?Blob;
      created_at_time: ?Nat64;
      memo: ?Blob;
    };

    public type ValidationError =  {
        #TransferError : TransferError;
        #MintError : MintError;
        #ApproveTokenError: ApproveTokenError;
        #RevokeTokenApprovalError : RevokeTokenApprovalError;
        #StandardError : StandardError;
        #BaseError : BaseError;
        #ApproveCollectionError: ApproveCollectionError;
        #RevokeCollectionApprovalError : RevokeCollectionApprovalError;
        #Automic;
        #LogicError;
    };

    public type ValidationErrorFlag = {
        #TransferError;
        #MintError;
        #ApproveTokenError;
        #RevokeTokenApprovalError;
        #StandardError;
        #BaseError;
        #ApproveCollectionError;
        #RevokeCollectionApprovalError;
        #Automic;
        #LogicError;
    };

    public type ValidationOutcome = Result.Result<Intent, ValidationError>;
    public type ValidationResult = Result.Result<ValidationOutcome, BaseError>;

 

    public type TokenRecord = {
      owner: Account;
      metadata: [(Text, Value)];
      approvals : [ApprovalInfo];
    };

    public type Result = {
        #Ok: Block;
        #Err: (Arg, ValidationError);
    };


    public type AccountRecord = {
      balance: Nat;
      owned_tokens: [Nat];
      approvals : [ApprovalInfo];
    };

    public type SupportedStandards = {
        name: Text;
        url: Text;
    };

    public type TransactionType = {
       #Send;
       #Receive;
    };
 
 
    
    
   //////////////
    ///ICRC37
    /////////////
    

    public type ApproveTokenResult = {
        #Ok : Nat; // Transaction index for successful approval
        #Err : ApproveTokenError;
    };

   


    public type ApproveCollectionResult = {
        #Ok : Nat; // Transaction index for successful approval
        #Err : ApproveCollectionError;
    };

   

 

    public type RevokeTokenApprovalResponse = {
        #Ok : Nat; // Transaction index for successful approval revocation
        #Err : RevokeTokenApprovalError;
    };

 



    public type RevokeCollectionApprovalResult = {
        #Ok : Nat; // Transaction index for successful approval revocation
        #Err : RevokeCollectionApprovalError;
    };

  

    public type TokenApproval = {
        token_id : Nat;
        approval_info : ApprovalInfo;
    };

    public type CollectionApproval = ApprovalInfo;

    public type TransferFromResult = {
        #Ok : Nat; // Transaction index for successful transfer
        #Err : TransferFromError;
    };

   

    public type PropertyDetails = {
        location: LocationDetails;  // Location-specific details, including property name
        physical: PhysicalDetails;  // Physical characteristics of the property
        additional: AdditionalDetails;  // Additional property-related details
        description: Text;  // General description of the property
    };

    public type LocationDetails = {
        name: Text;  // Name of the property
        addressLine1: Text;  // Street address
        addressLine2: Text;  // Street address
        addressLine3: ?Text;  // Street address
        addressLine4: ?Text;  // Street address
        location: Text;  // City, state, or other location information
        postcode: Text;  // Postal code
    };

    public type PhysicalDetails = {
        lastRenovation: Nat;
        yearBuilt: Nat;
        squareFootage: Nat;
        beds: Nat;
        baths: Nat;
    };

    public type AdditionalDetails = {
        crimeScore: Nat;
        schoolScore: Nat;
        affordability: Nat;
        floodZone: Bool;
    };

    public type CreateFinancialsArg = {
        reserve: Nat;
        purchasePrice: Nat;
        platformFee: Nat;
        currentValue: Nat;
        sqrFoot: Nat;
        monthlyRent: Nat;
    };

    public type TokenRecords = HashMap.HashMap<Nat, TokenRecord>;
    public type AccountRecords = HashMap.HashMap<Account, AccountRecord>;
    public type Blocks = Buffer.Buffer<{id: Nat; block: Value}>;
    public type Metadata = HashMap.HashMap<Text, Value>;



}