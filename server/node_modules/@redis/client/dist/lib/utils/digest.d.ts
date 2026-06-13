import { RedisArgument } from '../RESP/types';
/**
 * Computes a deterministic 64-bit XXH3 digest of the input.
 *
 * This produces the same digest that Redis computes internally via the `DIGEST` command,
 * allowing you to use it with conditional SET and DELEX operations (`IFDEQ`, `IFDNE`).
 *
 * @param value - The value to compute the digest for (string or Buffer)
 * @returns A 16-character lowercase hexadecimal digest
 * @throws If the `@node-rs/xxhash` package is not found
 */
export declare function digest(value: RedisArgument): Promise<string>;
//# sourceMappingURL=digest.d.ts.map