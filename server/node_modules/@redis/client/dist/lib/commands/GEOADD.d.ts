import { CommandParser } from '../client/parser';
import { RedisArgument, NumberReply } from '../RESP/types';
import { GeoCoordinates } from './GEOSEARCH';
export interface GeoMember extends GeoCoordinates {
    member: RedisArgument;
}
export interface GeoAddOptions {
    condition?: 'NX' | 'XX';
    /**
     * @deprecated Use `{ condition: 'NX' }` instead.
     */
    NX?: boolean;
    /**
     * @deprecated Use `{ condition: 'XX' }` instead.
     */
    XX?: boolean;
    CH?: boolean;
}
declare const _default: {
    readonly IS_READ_ONLY: false;
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, toAdd: GeoMember | Array<GeoMember>, options?: GeoAddOptions) => void;
    readonly transformReply: () => NumberReply;
};
export default _default;
//# sourceMappingURL=GEOADD.d.ts.map