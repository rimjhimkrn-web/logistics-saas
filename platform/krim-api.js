/* =========================================================
   KRIM API / DATA ACCESS SERVICE
   Permanent shared Supabase data layer
   ========================================================= */

(function () {
    "use strict";

    function getClient() {
        if (!window.KRIM_SUPABASE) {
            throw new Error(
                "KRIM: Supabase client is not initialized."
            );
        }

        return window.KRIM_SUPABASE;
    }


    /*
     * -------------------------------------------------------
     * FILTER SUPPORT
     * -------------------------------------------------------
     *
     * Only approved Supabase query operators are accepted.
     * This keeps domain pages from passing arbitrary methods.
     */

    const FILTER_OPERATORS = Object.freeze([
        "eq",
        "neq",
        "gt",
        "gte",
        "lt",
        "lte",
        "like",
        "ilike",
        "is",
        "in",
        "contains",
        "containedBy",
        "overlaps",
        "match",
        "not"
    ]);


    function applyFilters(query, filters) {

        if (!Array.isArray(filters)) {
            return query;
        }

        let currentQuery = query;

        for (const filter of filters) {

            if (
                !filter ||
                !filter.operator ||
                !filter.column
            ) {
                continue;
            }

            const operator = String(
                filter.operator
            );

            const column = String(
                filter.column
            );

            if (!FILTER_OPERATORS.includes(operator)) {
                throw new Error(
                    `KRIM: Unsupported filter operator "${operator}".`
                );
            }

            if (
                typeof currentQuery[operator] !==
                "function"
            ) {
                throw new Error(
                    `KRIM: Supabase operator "${operator}" is unavailable.`
                );
            }

            currentQuery =
                currentQuery[operator](
                    column,
                    filter.value
                );
        }

        return currentQuery;
    }


    /*
     * -------------------------------------------------------
     * SELECT
     * -------------------------------------------------------
     */

    async function select(
        table,
        columns = "*",
        options = {}
    ) {

        if (!table) {
            throw new Error(
                "Table name is required."
            );
        }

        let query =
            getClient()
                .from(table)
                .select(columns);


        query = applyFilters(
            query,
            options.filters
        );


        if (options.order) {

            if (!options.order.column) {
                throw new Error(
                    "Order column is required."
                );
            }

            query = query.order(
                options.order.column,
                {
                    ascending:
                        options.order.ascending !== false,

                    nullsFirst:
                        options.order.nullsFirst === true
                }
            );
        }


        if (
            Number.isInteger(options.limit) &&
            options.limit > 0
        ) {
            query = query.limit(
                options.limit
            );
        }


        if (
            Number.isInteger(options.from) &&
            Number.isInteger(options.to)
        ) {
            if (options.from < 0 || options.to < options.from) {
                throw new Error(
                    "Invalid range supplied."
                );
            }

            query = query.range(
                options.from,
                options.to
            );
        }


        const {
            data,
            error
        } = await query;


        if (error) {
            throw error;
        }


        return data || [];
    }


    /*
     * -------------------------------------------------------
     * INSERT
     * -------------------------------------------------------
     */

    async function insert(
        table,
        rows,
        options = {}
    ) {

        if (!table) {
            throw new Error(
                "Table name is required."
            );
        }

        if (
            rows === null ||
            rows === undefined
        ) {
            throw new Error(
                "Insert data is required."
            );
        }


        let query =
            getClient()
                .from(table)
                .insert(rows);


        if (options.select === true) {
            query = query.select(
                options.columns || "*"
            );
        }


        const {
            data,
            error
        } = await query;


        if (error) {
            throw error;
        }


        return data || [];
    }


    /*
     * -------------------------------------------------------
     * UPDATE
     * -------------------------------------------------------
     */

    async function update(
        table,
        values,
        filters = [],
        options = {}
    ) {

        if (!table) {
            throw new Error(
                "Table name is required."
            );
        }

        if (
            !values ||
            typeof values !== "object"
        ) {
            throw new Error(
                "Update values are required."
            );
        }

        if (
            !Array.isArray(filters) ||
            filters.length === 0
        ) {
            throw new Error(
                "KRIM: Update requires at least one filter."
            );
        }


        let query =
            getClient()
                .from(table)
                .update(values);


        query = applyFilters(
            query,
            filters
        );


        query = query.select(
            options.columns || "*"
        );


        const {
            data,
            error
        } = await query;


        if (error) {
            throw error;
        }


        return data || [];
    }


    /*
     * -------------------------------------------------------
     * UPSERT
     * -------------------------------------------------------
     */

    async function upsert(
        table,
        rows,
        options = {}
    ) {

        if (!table) {
            throw new Error(
                "Table name is required."
            );
        }

        if (
            rows === null ||
            rows === undefined
        ) {
            throw new Error(
                "Upsert data is required."
            );
        }


        const upsertOptions = {
            ...options
        };


        if (!upsertOptions.onConflict) {
            delete upsertOptions.onConflict;
        }


        let query =
            getClient()
                .from(table)
                .upsert(
                    rows,
                    upsertOptions
                );


        query = query.select(
            options.columns || "*"
        );


        const {
            data,
            error
        } = await query;


        if (error) {
            throw error;
        }


        return data || [];
    }


    /*
     * -------------------------------------------------------
     * DELETE
     * -------------------------------------------------------
     *
     * Destructive operations require explicit filters.
     */

    async function remove(
        table,
        filters = [],
        options = {}
    ) {

        if (!table) {
            throw new Error(
                "Table name is required."
            );
        }

        if (
            !Array.isArray(filters) ||
            filters.length === 0
        ) {
            throw new Error(
                "KRIM: Delete requires at least one filter."
            );
        }


        let query =
            getClient()
                .from(table)
                .delete();


        query = applyFilters(
            query,
            filters
        );


        query = query.select(
            options.columns || "*"
        );


        const {
            data,
            error
        } = await query;


        if (error) {
            throw error;
        }


        return data || [];
    }


    /*
     * -------------------------------------------------------
     * EDGE FUNCTION
     * -------------------------------------------------------
     */

    async function invoke(
        functionName,
        body = {},
        options = {}
    ) {

        if (!functionName) {
            throw new Error(
                "Edge Function name is required."
            );
        }


        const invokeOptions = {
            body
        };


        if (options.headers) {
            invokeOptions.headers =
                options.headers;
        }


        if (options.signal) {
            invokeOptions.signal =
                options.signal;
        }


        const {
            data,
            error
        } = await getClient()
            .functions
            .invoke(
                functionName,
                invokeOptions
            );


        if (error) {
            throw error;
        }


        return data;
    }


    /*
     * -------------------------------------------------------
     * COUNT
     * -------------------------------------------------------
     */

    async function count(
        table,
        options = {}
    ) {

        if (!table) {
            throw new Error(
                "Table name is required."
            );
        }


        let query =
            getClient()
                .from(table)
                .select("*", {
                    count: "exact",
                    head: true
                });


        query = applyFilters(
            query,
            options.filters
        );


        const {
            count: total,
            error
        } = await query;


        if (error) {
            throw error;
        }


        return total || 0;
    }


    /*
     * -------------------------------------------------------
     * PUBLIC KRIM API
     * -------------------------------------------------------
     */

    window.KRIM_API = Object.freeze({

        client: getClient,

        select,

        insert,

        update,

        upsert,

        remove,

        delete: remove,

        invoke,

        count

    });

})();
