import { CommandParser } from '../client/parser';
import { ArrayReply, RedisArgument } from '../RESP/types';
import { RedisVariadicArgument } from './generic-transformers';
export declare const HASH_EXPIRATION: {
    /** The field does not exist */
    readonly FIELD_NOT_EXISTS: -2;
    /** Specified NX | XX | GT | LT condition not met */
    readonly CONDITION_NOT_MET: 0;
    /** Expiration time was set or updated */
    readonly UPDATED: 1;
    /** Field deleted because the specified expiration time is in the past */
    readonly DELETED: 2;
};
export type HashExpiration = typeof HASH_EXPIRATION[keyof typeof HASH_EXPIRATION];
declare const _default: {
    readonly parseCommand: (this: void, parser: CommandParser, key: RedisArgument, fields: RedisVariadicArgument, seconds: number, mode?: 'NX' | 'XX' | 'GT' | 'LT') => void;
    readonly transformReply: () => ArrayReply<HashExpiration>;
};
export default _default;
//# sourceMappingURL=HEXPIRE.d.ts.map