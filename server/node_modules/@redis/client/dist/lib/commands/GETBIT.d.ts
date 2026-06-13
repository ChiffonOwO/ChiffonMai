import { CommandParser } from '../client/parser';
import { NumberReply, RedisArgument } from '../RESP/types';
import { BitValue } from './generic-transformers';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, offset: number) => void;
    readonly transformReply: () => NumberReply<BitValue>;
};
export default _default;
//# sourceMappingURL=GETBIT.d.ts.map