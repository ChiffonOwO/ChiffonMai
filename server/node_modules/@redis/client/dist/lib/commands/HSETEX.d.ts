import { CommandParser } from '../client/parser';
import { NumberReply, RedisArgument } from '../RESP/types';
export interface HSetExOptions {
    expiration?: {
        type: 'EX' | 'PX' | 'EXAT' | 'PXAT';
        value: number;
    } | {
        type: 'KEEPTTL';
    } | 'KEEPTTL';
    mode?: 'FNX' | 'FXX';
}
export type HashTypes = RedisArgument | number;
type HSETEXObject = Record<string | number, HashTypes>;
type HSETEXMap = Map<HashTypes, HashTypes>;
type HSETEXTuples = Array<[HashTypes, HashTypes]> | Array<HashTypes>;
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fields: HSETEXObject | HSETEXMap | HSETEXTuples, options?: HSetExOptions) => void;
    readonly transformReply: () => NumberReply<0 | 1>;
};
export default _default;
//# sourceMappingURL=HSETEX.d.ts.map