import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, NumberReply } from '../RESP/types';
import { BitFieldGetOperation } from './BITFIELD';
export type BitFieldRoOperations = Array<Omit<BitFieldGetOperation, 'operation'>>;
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, operations: BitFieldRoOperations) => void;
    readonly transformReply: () => ArrayReply<NumberReply>;
};
export default _default;
//# sourceMappingURL=BITFIELD_RO.d.ts.map