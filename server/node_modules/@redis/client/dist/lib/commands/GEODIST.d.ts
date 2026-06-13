import { CommandParser } from '../client/parser';
import { RedisArgument, BlobStringReply, NullReply } from '../RESP/types';
import { GeoUnits } from './GEOSEARCH';
declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, member1: RedisArgument, member2: RedisArgument, unit?: GeoUnits) => void;
    readonly transformReply: (this: void, reply: BlobStringReply | NullReply) => number | null;
};
export default _default;
//# sourceMappingURL=GEODIST.d.ts.map