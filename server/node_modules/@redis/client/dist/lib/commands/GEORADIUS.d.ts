import { CommandParser } from '../client/parser';
import { RedisArgument, ArrayReply, BlobStringReply } from '../RESP/types';
import { GeoCoordinates, GeoUnits, GeoSearchOptions } from './GEOSEARCH';
export declare function parseGeoRadiusArguments(parser: CommandParser, key: RedisArgument, from: GeoCoordinates, radius: number, unit: GeoUnits, options?: GeoSearchOptions): void;
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, from: GeoCoordinates, radius: number, unit: GeoUnits, options?: GeoSearchOptions | undefined) => void;
    readonly transformReply: () => ArrayReply<BlobStringReply>;
};
export default _default;
//# sourceMappingURL=GEORADIUS.d.ts.map