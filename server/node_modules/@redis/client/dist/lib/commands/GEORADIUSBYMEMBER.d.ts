import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, BlobStringReply } from '../RESP/types';
import { GeoUnits, GeoSearchOptions } from './GEOSEARCH';
export declare function parseGeoRadiusByMemberArguments(parser: CommandParser, key: RedisArgument, from: RedisArgument, radius: number, unit: GeoUnits, options?: GeoSearchOptions): void;
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, from: RedisArgument, radius: number, unit: GeoUnits, options?: GeoSearchOptions) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply>;
};
export default _default;
//# sourceMappingURL=GEORADIUSBYMEMBER.d.ts.map