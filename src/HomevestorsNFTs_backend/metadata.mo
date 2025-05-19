import Types "types";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Nat64 "mo:base/Nat64";


module {
    type Metadata = Types.Metadata;
    type Value = Types.Value;
    type TxnContext = Types.TxnContext;
    type PropertyDetails = Types.PropertyDetails;
    type LocationDetails = Types.LocationDetails;
    type PhysicalDetails = Types.PhysicalDetails;
    type AdditionalDetails = Types.AdditionalDetails;
    type CreateFinancialsArg = Types.CreateFinancialsArg;
    type TokenMetadataArg = Types.TokenMetadataArg;
    type TokenMetadataResult = Types.TokenMetadataResult;
    type StandardError = Types.StandardError;
    type TokenRecords = Types.TokenRecords;
    type ValidationOutcome = Types.ValidationOutcome;
    type ValidationError = Types.ValidationError;

     public func initiateMetadata(metadata: Metadata, totalSupply: Nat, propertyId: Nat): Metadata {
        metadata.put("icrc7:symbol", #Text("HVD-P"#Nat.toText(propertyId)));
        metadata.put("icrc7:name", #Text("15 The Ridgeway"));
        metadata.put("icrc7:description", #Text("Welcome To Membership of the Property DAO"));
        metadata.put("icrc7:logo", #Text("https://nwyye-naaaa-aaaap-qpwka-cai.icp0.io/nft1.jpg"));
        metadata.put("icrc7:total_supply", #Nat(totalSupply));
        metadata.put("icrc7:supply_cap", #Nat(1000));
        //extra fields
        metadata.put("address_line_1", #Text("15 The Ridgeway"));
        metadata.put("address_line_2", #Text("Doxey"));
        metadata.put("address_line_3", #Text("Stafford"));
        metadata.put("address_line_4", #Text(""));
        metadata.put("location", #Text("Staffordshire"));
        metadata.put("postcode", #Text("ST16 1XP"));
        metadata.put("last_renovation", #Nat(2023));
        metadata.put("year_built", #Nat(1995));
        metadata.put("square_footage(sqft)", #Nat(200));
        metadata.put("beds", #Nat(3));
        metadata.put("baths", #Nat(2));
        metadata.put("crime_score(out_of_100)", #Nat(100));
        metadata.put("school_score(out_of_100)", #Nat(100));
        metadata.put("affordability(out_of_100)", #Nat(100));
        metadata.put("flood_zone", #Text("false"));//true or false
        metadata.put("description", #Text("Awesome house"));
        metadata.put("reserve", #Nat(10000));
        metadata.put("purchase_price", #Nat(150000));
        metadata.put("platform_fee", #Nat(0));
        metadata.put("current_value", #Nat(225000));
        metadata.put("monthly_rent", #Nat(1195));
        //Technical Metadata
        metadata.put("icrc7:max_query_batch_size", #Nat(100));
        metadata.put("icrc7:max_update_batch_size", #Nat(1001));
        metadata.put("icrc7:default_take_value", #Nat(50));
        metadata.put("icrc7:max_take_value", #Nat(500));
        metadata.put("icrc7:max_memo_size", #Nat(500));
        metadata.put("icrc7:atomic_batch_transfers", #Text("true"));//true or false
        metadata.put("icrc7:tx_window", #Nat(60000));
        metadata.put("icrc7:permitted_drift", #Nat(60000));
        metadata.put("icrc37_max_approvals_per_token_or_collection", #Nat(100));
        metadata.put("icrc37:max_revoke_approvals", #Nat(100));
        
        return metadata;
    };

    func createPropertyDetails(metadata: Metadata): PropertyDetails {
        return {
            location = createLocationDetails(metadata);
            physical = createPhysicalDetails(metadata);
            additional = createAdditionalDetails(metadata);
            description = unwrapText("description", "placeholder", metadata);
        }
    };

    func createLocationDetails(metadata: Metadata): LocationDetails {
        return {
            name = unwrapText("name", "HVD", metadata);
            addressLine1 = unwrapText("address_line_1", "placeholder", metadata);
            addressLine2 = unwrapText("address_line_2", "placeholder", metadata);
            addressLine3 = unwrapTextOrNull("address_line_3", metadata);  // Street address
            addressLine4 = unwrapTextOrNull("address_line_4", metadata);  // Street address
            location = unwrapText("location", "placeholder", metadata);
            postcode = unwrapText("postcode", "placeholder", metadata);
        }
    };

    func createPhysicalDetails(metadata: Metadata): PhysicalDetails {
        return {
            lastRenovation = unwrapNat("last_renovation", 0, metadata);
            yearBuilt = unwrapNat("year_built", 0, metadata);
            squareFootage= unwrapNat("square_footage(sqft)", 0, metadata);
            beds = unwrapNat("beds", 0, metadata);
            baths = unwrapNat("baths", 0, metadata);
        }
    };

    func createAdditionalDetails(metadata: Metadata): AdditionalDetails {
        return {
            crimeScore = unwrapNat("crime_score(out_of_100)", 0, metadata);
            schoolScore = unwrapNat("school_score(out_of_100)", 0, metadata);
            affordability = unwrapNat("affordability(out_of_100)", 0, metadata);
            floodZone = if(Text.equal(unwrapText("flood_zone", "", metadata), "true")) true else false;
        }
    };

    func createFinancials(metadata: Metadata): CreateFinancialsArg {
        return {
            reserve = unwrapNat("reserve", 0, metadata);
            purchasePrice = unwrapNat("purchase_price", 0, metadata);
            platformFee = unwrapNat("platform_fee", 0, metadata);
            currentValue= unwrapNat("current_value", 0, metadata);
            sqrFoot = unwrapNat("square_footage(sqft)", 0, metadata);
            monthlyRent = unwrapNat("monthly_rent", 0, metadata);
        }
    };

    public func createPropertyData(metadata: Metadata): (CreateFinancialsArg, PropertyDetails){
        (createFinancials(metadata), createPropertyDetails(metadata))
    };


    public func unwrapTextOrNull(key: Text, metadata: Metadata): ?Text {
      switch(metadata.get(key)){
        case(?#Text(t)){?t};
        case(_){null}
      }
    };

    public func unwrapNatOrNull(key: Text, metadata: Metadata): ?Nat {
      switch(metadata.get(key)){
        case(?#Nat(t)){?t};
        case(_){null}
      }
    };

    public func unwrapText(key: Text, alternative: Text, metadata: Metadata): Text {
      switch(metadata.get(key)){
        case(?#Text(t)){t};
        case(_){alternative}
      }
    };

    public func unwrapNat(key: Text, alternative: Nat, metadata: Metadata): Nat {
      switch(metadata.get(key)){
        case(?#Nat(t)){t};
        case(_){alternative}
      }
    };

    public func unwrapMap(key: ?Value, alternative: [(Text, Value)]): [(Text, Value)] {
      switch(key){
        case(?#Map(m))return m;
        case(_) return alternative;
      }
    };
  
    public func updateElementByKey(arr: [(Text, Value)], key: Text, newValue: Value) : [(Text, Value)] {
        return Array.map<(Text, Value), (Text, Value)>(arr, func((k, v)) {
            if (k == key) {
                return (k, newValue);
            } else {
                return (k, v);
            }
        });
    };

    


  public func removeTokenMetadata(ctx: TxnContext, tokenId: Nat, key: Text, caller: Principal): TxnContext {
    assert(Principal.equal(caller, ctx.admin));
    switch(ctx.tokens.get(tokenId)){
      case(null){};
      case(?record){
        let updatedRecord = {record with metadata = Array.filter<(Text, Value)>(record.metadata, func(k, v) {k != key});};
        ctx.tokens.put(tokenId, updatedRecord);
      };
    };
    return ctx;
  };  


   public func icrc7_token_metadata(token_ids: [Nat], tokens: TokenRecords): [?[(Text, Value)]] {
        var results : [?[ (Text, Value) ]] = [];

        for (id in token_ids.vals()) {
          switch (tokens.get(id)) {
            case (?meta){
              results := Array.append(results, [?meta.metadata])
            };
            case (_) results := Array.append(results, [null]);
          };
        };

        return results;
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


}