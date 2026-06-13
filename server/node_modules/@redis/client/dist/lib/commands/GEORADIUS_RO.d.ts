declare const _default: {
    readonly CACHEABLE: true;
    readonly IS_READ_ONLY: true;
    readonly parseCommand: (this: void, parser: import("../..").CommandParser, key: import("../RESP/types").RedisArgument, from: import("./GEOSEARCH").GeoCoordinates, radius: number, unit: import("./GEOSEARCH").GeoUnits, options?: import("./GEOSEARCH").GeoSearchOptions | undefined) => void;
    readonly transformReply: () => import("../RESP/types").ArrayReply<import("../RESP/types").BlobStringReply<string>>;
};
export default _default;
//# sourceMappingURL=GEORADIUS_RO.d.ts.map