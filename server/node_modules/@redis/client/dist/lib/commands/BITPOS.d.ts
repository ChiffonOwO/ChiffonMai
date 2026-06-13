import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
import { BitValue } from './generic-transformers';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, bit: BitValue, start?: number, end?: number, mode?: 'BYTE' | 'BIT') => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=BITPOS.d.ts.map