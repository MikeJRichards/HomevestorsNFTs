import Types "types";
import Blob "mo:base/Blob";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Sha256 "mo:sha2/Sha256";
import NatX "mo:xtended-numbers/NatX";
import IntX "mo:xtended-numbers/IntX";
import CertTree "mo:ic-certification/CertTree";
import CertifiedData "mo:base/CertifiedData";
import MerkleTree "mo:ic-certification/MerkleTree";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

module {
    type Account = Types.Account;
    type Value = Types.Value;
    type Tx = Types.Tx;
    type Block = Types.Block;
    type TxnContext = Types.TxnContext;
    type DataCertificate = Types.DataCertificate;

    func accountToValue(acc: Account): Value {
        return #Array([
            #Blob(Principal.toBlob(acc.owner)),
            switch (acc.subaccount) {
                case (?sub) #Blob(sub);
                case null #Blob(Blob.fromArray([])); // empty subaccount = default
            }
        ]);
    };

    func txToValue(tx: Tx): Value {
      var fields: [(Text, Value)] = [];

      switch (tx.tid){ case (?tid) fields := Array.append(fields, [("tid", #Nat(tid))]); case(null) {}};
      switch (tx.from){ case (?from) fields := Array.append(fields, [("from", accountToValue(from))]); case(null) {}};
      switch (tx.to){ case (?to) fields := Array.append(fields, [("to", accountToValue(to))]); case(null) {}};
      switch (tx.spender){ case (?spender) fields := Array.append(fields, [("spender", accountToValue(spender))]); case(null) {}};
      switch (tx.exp){ case (?exp) fields := Array.append(fields, [("exp", #Nat(exp))]); case(null) {}};
      switch (tx.meta){ case (?meta) fields := Array.append(fields, [("meta", meta)]); case(null) {}};
      switch (tx.memo){ case (?memo) fields := Array.append(fields, [("memo", #Blob(memo))]); case(null) {}};
      switch (tx.ts){ case (?ts) fields := Array.append(fields, [("ts", #Nat(ts))]); case(null) {}};

      return #Map(fields);
    };


    public func blockToValue(block: Block): Value {
      return #Map([
        ("phash", #Blob(block.phash)),
        ("btype", #Text(block.btype)),
        ("ts", #Nat(block.ts)),
        ("tx", txToValue(block.tx))
      ]);
    };

    public func hashValue(value: Value): Blob {
        switch (value) {
          case (#Nat(n)) {
            let buf = Buffer.Buffer<Nat8>(10);
            NatX.encodeNat(buf, n, #unsignedLEB128);
            Sha256.fromArray(#sha256, Iter.toArray(buf.vals()));
          };

          case (#Int(i)) {
            let buf = Buffer.Buffer<Nat8>(10);
            IntX.encodeInt(buf, i, #signedLEB128);
            Sha256.fromArray(#sha256, Iter.toArray(buf.vals()));
          };

          case (#Text(t)) {
            Sha256.fromBlob(#sha256, Text.encodeUtf8(t));
          };

          case (#Blob(b)) {
            Sha256.fromBlob(#sha256, b);
          };

          case (#Array(arr)) {
            var combined: [Nat8] = [];
            for (element in arr.vals()) {
              let hashed = hashValue(element);
              combined := Array.append(combined, Blob.toArray(hashed));
            };
            Sha256.fromBlob(#sha256, Blob.fromArray(combined));
          };

          case (#Map(entries)) {
            var kvHashes: [(Blob, Blob)] = [];

            for ((key, val) in entries.vals()) {
              let keyHash = Sha256.fromBlob(#sha256, Text.encodeUtf8(key));
              let valHash = hashValue(val);
              kvHashes := Array.append(kvHashes, [(keyHash, valHash)]);
            };

            // Sort by key hash
            kvHashes := Array.sort<(Blob, Blob)>(kvHashes, func(a, b) = Blob.compare(a.0, b.0));

            var combined: [Nat8] = [];
            for ((kHash, vHash) in kvHashes.vals()) {
              combined := Array.append(combined, Array.append(Blob.toArray(kHash), Blob.toArray(vHash)));
            };

            Sha256.fromBlob(#sha256, Blob.fromArray(combined));
          };
        };
    };

      func leb128(n: Nat): Blob {
        let buf = Buffer.Buffer<Nat8>(10);
        NatX.encodeNat(buf, n, #unsignedLEB128);
        Blob.fromArray(Iter.toArray(buf.vals()));
    };

    public func certifyTip(blockIndex: Nat, blockHash: Blob, ctx: TxnContext) {
        let cert = CertTree.Ops(ctx.cert);
        cert.put([Text.encodeUtf8("last_block_index")], leb128(blockIndex));
        cert.put([Text.encodeUtf8("last_block_hash")], blockHash);
    
        let root = cert.treeHash();
    
        CertifiedData.set(root);
    };
  
    public func icrc3_get_tip_certificate(store: CertTree.Store): ?DataCertificate {
      switch (CertifiedData.getCertificate()) {
        case null null;
        case (?cert) {
            let ops = CertTree.Ops(store);
            let witness = ops.reveals([
                [Text.encodeUtf8("last_block_index")],
                [Text.encodeUtf8("last_block_hash")]
            ].vals()); // `vals()` makes it iterable
          let encodedTree = MerkleTree.encodeWitness(witness);
    
          ?{
            certificate = cert;
            hash_tree = encodedTree;
          }
        }
      }
    };

    public func icrc3_supported_block_types(): [{ block_type: Text; url: Text }] {
        return [
          { block_type = "7mint"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md" },
          { block_type = "7burn"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md" },
          { block_type = "7xfer"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md" },
          { block_type = "7update_token"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-7/ICRC-7.md" },
          { block_type = "37approve"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-37/ICRC-37.md" },
          { block_type = "37approve_coll"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-37/ICRC-37.md" },
          { block_type = "37revoke"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-37/ICRC-37.md" },
          { block_type = "37revoke_coll"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-37/ICRC-37.md" },
          { block_type = "37xfer"; url = "https://github.com/dfinity/ICRC/blob/main/ICRCs/ICRC-37/ICRC-37.md" },
        ];
    };


    

    

    



}