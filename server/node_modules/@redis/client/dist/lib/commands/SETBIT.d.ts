import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
import { BitValue } from './generic-transformers';
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, offset: number, value: BitValue) => void;
    readonly transformReply: () => NumberReply<BitValue>;
};
export default _default;
//# sourceMappingURL=SETBIT.d.ts.map