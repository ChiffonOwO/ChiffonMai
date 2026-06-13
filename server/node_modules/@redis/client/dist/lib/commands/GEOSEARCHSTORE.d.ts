import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
import { GeoSearchFrom, GeoSearchBy, GeoSearchOptions } from './GEOSEARCH';
export interface GeoSearchStoreOptions extends GeoSearchOptions {
    STOREDIST?: boolean;
}
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, destination: RedisArgument, source: RedisArgument, from: GeoSearchFrom, by: GeoSearchBy, options?: GeoSearchStoreOptions) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=GEOSEARCHSTORE.d.ts.map