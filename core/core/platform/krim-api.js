/* =========================================================
   KRIM GLOBAL API SERVICE
   Permanent Data / Function Access Layer
   ========================================================= */

(function () {

    "use strict";

    const KRIM_API = {

        client() {

            if (!window.KRIM_SUPABASE) {
                throw new Error(
                    "KRIM Supabase client is not initialized."
                );
            }

            return window.KRIM_SUPABASE;
        },


        async select(
            table,
            columns = "*",
            options = {}
        ) {

            if (!table) {
                throw new Error(
                    "Table name is required."
                );
            }

            let query = this.client()
                .from(table)
                .select(columns);

            if (options.filters) {

                for (
                    const filter of options.filters
                ) {

                    if (
                        !filter ||
                        !filter.operator ||
                        !filter.column
                    ) {
                        continue;
                    }

                    const {
                        operator,
                        column,
                        value
                    } = filter;

                    if (
                        typeof query[operator] ===
                        "function"
                    ) {
                        query = query[operator](
                            column,
                            value
                        );
                    }

                }
            }

            if (options.order) {

                query = query.order(
                    options.order.column,
                    {
                        ascending:
                            options.order.ascending !==
                            false
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
        },


        async insert(table, rows) {

            if (!table) {
                throw new Error(
                    "Table name is required."
                );
            }

            if (!rows) {
                throw new Error(
                    "Insert data is required."
                );
            }

            const {
                data,
                error
            } = await this.client()
                .from(table)
                .insert(rows)
                .select();

            if (error) {
                throw error;
            }

            return data || [];
        },


        async update(
            table,
            values,
            filters = []
        ) {

            if (!table) {
                throw new Error(
                    "Table name is required."
                );
            }

            if (!values) {
                throw new Error(
                    "Update values are required."
                );
            }

            let query = this.client()
                .from(table)
                .update(values);

            for (
                const filter of filters
            ) {

                if (
                    !filter ||
                    !filter.operator ||
                    !filter.column
                ) {
                    continue;
                }

                const {
                    operator,
                    column,
                    value
                } = filter;

                if (
                    typeof query[operator] ===
                    "function"
                ) {
                    query = query[operator](
                        column,
                        value
                    );
                }
            }

            const {
                data,
                error
            } = await query.select();

            if (error) {
                throw error;
            }

            return data || [];
        },


        async upsert(
            table,
            rows,
            options = {}
        ) {

            if (!table) {
                throw new Error(
                    "Table name is required."
                );
            }

            const {
                data,
                error
            } = await this.client()
                .from(table)
                .upsert(
                    rows,
                    options
                )
                .select();

            if (error) {
                throw error;
            }

            return data || [];
        },


        async remove(
            table,
            filters = []
        ) {

            if (!table) {
                throw new Error(
                    "Table name is required."
                );
            }

            let query = this.client()
                .from(table)
                .delete();

            for (
                const filter of filters
            ) {

                if (
                    !filter ||
                    !filter.operator ||
                    !filter.column
                ) {
                    continue;
                }

                const {
                    operator,
                    column,
                    value
                } = filter;

                if (
                    typeof query[operator] ===
                    "function"
                ) {
                    query = query[operator](
                        column,
                        value
                    );
                }
            }

            const {
                data,
                error
            } = await query.select();

            if (error) {
                throw error;
            }

            return data || [];
        },


        async invoke(
            functionName,
            body = {},
            options = {}
        ) {

            if (!functionName) {
                throw new Error(
                    "Edge Function name is required."
                );
            }

            const {
                data,
                error
            } = await this.client()
                .functions
                .invoke(
                    functionName,
                    {
                        body,
                        headers:
                            options.headers || {}
                    }
                );

            if (error) {
                throw error;
            }

            return data;
        },


        async count(
            table,
            options = {}
        ) {

            if (!table) {
                throw new Error(
                    "Table name is required."
                );
            }

            let query = this.client()
                .from(table)
                .select(
                    "*",
                    {
                        count: "exact",
                        head: true
                    }
                );

            if (options.filters) {

                for (
                    const filter of options.filters
                ) {

                    if (
                        !filter ||
                        !filter.operator ||
                        !filter.column
                    ) {
                        continue;
                    }

                    const {
                        operator,
                        column,
                        value
                    } = filter;

                    if (
                        typeof query[operator] ===
                        "function"
                    ) {
                        query = query[operator](
                            column,
                            value
                        );
                    }
                }
            }

            const {
                count,
                error
            } = await query;

            if (error) {
                throw error;
            }

            return count || 0;
        }

    };


    window.KRIM_API = KRIM_API;

})();
