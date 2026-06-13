import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
import { GeoCoordinates, GeoSearchOptions, GeoUnits } from './GEOSEARCH';
export interface GeoRadiusStoreOptions extends GeoSearchOptions {
    STOREDIST?: boolean;
}
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, from: GeoCoordinates, radius: number, unit: GeoUnits, destination: RedisArgument, options?: GeoRadiusStoreOptions) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=GEORADIUS_STORE.d.ts.map