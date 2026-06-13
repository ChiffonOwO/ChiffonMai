import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, BlobStringReply } from '../RESP/types';
import { ScanCommonOptions } from './SCAN';
export interface HScanEntry {
    field: BlobStringReply;
    value: BlobStringReply;
}
declare const _default: {
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, cursor: RedisArgument, options?: ScanCommonOptions) => void;
    readonly transformReply: (this: void, [cursor, rawMembers]: [BlobStringReply, ArrayReply<BlobStringReply>]) => {
        cursor: BlobStringReply<string>;
        members: {
            value: BlobStringReply<string>;
            score: import("../RESP/types").DoubleReply<number>;
        }[];
    };
};
export default _default;
//# sourceMappingURL=ZSCAN.d.ts.map