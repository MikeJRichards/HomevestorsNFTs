import Types "types";
module {
    type SupportedStandards = Types.SupportedStandards;
    public func supported_standards() : [SupportedStandards] {
        return [
            {name = "ICRC-3"; url = "https://github.com/dfinity/ICRC-1/tree/main/standards/ICRC-3";},  // Declares support for ICRC-7 version 1.0
            {name = "ICRC-7"; url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-7";},  // Declares support for ICRC-7 version 1.0
            {name = "ICRC-10"; url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-10";},   // Declares support for ICRC-7 version 1.0
            {name = "ICRC-37"; url = "https://github.com/dfinity/ICRC/ICRCs/ICRC-37";}   // Declares support for ICRC-7 version 1.0
        ];
    };
}