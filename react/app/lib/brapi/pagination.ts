import * as z from "zod";

export const Pagination = z.object({
    currentPage:  z.number().default(0),
    pageSize:     z.number().default(10),
    totalCount:   z.number().default(0),
    totalPages:   z.number().default(0)
});
