import { CommandParser } from '../client/parser';
import { RedisArgument, BlobStringReply } from '../RESP/types';
import { ScanCommonOptions } from './SCAN';
export interface HScanEntry {
    field: BlobStringReply;
    value: BlobStringReply;
}
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, cursor: RedisArgument, options?: ScanCommonOptions) => void;
    readonly transformReply: (this: void, [cursor, rawEntries]: [BlobStringReply, Array<BlobStringReply>]) => {
        cursor: BlobStringReply<string>;
        entries: {
            field: BlobStringReply<string>;
            value: BlobStringReply<string>;
        }[];
    };
};
export default _default;
//# sourceMappingURL=HSCAN.d.ts.map