import { Button } from "~/components/ui/button"
import { ArrowUpDown } from "lucide-react"
import {Sortable} from "./sortable"
import { type ColumnDef } from "@tanstack/react-table"
import { type SchemaType } from "@/lib/brapi/v2/programs"

export const columns: ColumnDef<SchemaType>[] = [
  {
    id: "ID",
    accessorKey: "programDbId",
    accessorFn: (row) => { return row.programDbId == null ? '' : row.programDbId},
    header: ({column}) => <Sortable text="ID" column={column}/>,
    cell: ({row}) => { return <div className="text-left">{row.original.programDbId}</div> },
    enableSorting: true,
    enableColumnFilter: true
  },
  {
    id: "Name",
    accessorKey: "programName",
    accessorFn: (row) => { return row.programName == null ? '' : row.programName},
    header: ({column}) => <Sortable text="Name" column={column}/>,
    cell: ({row}) => { return <div className="text-left">{row.original.programName}</div> },
    enableColumnFilter: true,
  },
  {
    id: "Description",
    accessorKey: "objective",
    accessorFn: (row) => { return row.objective == null ? '' : row.objective},
    header: ({column}) => <Sortable text="Objective" column={column}/>,
    cell: ({row}) => { return <div className="text-left">{row.original.objective}</div> },
    enableColumnFilter: true,
    enableSorting: true,
  },
]
