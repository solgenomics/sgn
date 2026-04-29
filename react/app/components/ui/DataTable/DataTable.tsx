"use client"

import * as React from "react"

import {
  Pagination,
  PaginationContent,
  PaginationItem,
  PaginationLink,
  PaginationNext,
  PaginationPrevious,
} from "@/components/ui/pagination";

import {
  type ColumnDef,
  type SortingState,
  flexRender,
  getCoreRowModel,
  getPaginationRowModel,
  useReactTable,

  getSortedRowModel,
} from "@tanstack/react-table"

import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";

import { Skeleton } from "@/components/ui/skeleton";
import {
  Table as TestTable,
  TableBody,
  TableCaption,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"

interface DataTableProps<TData, TValue> {
  columns: ColumnDef<TData, TValue>[]
  data: TData[],
  caption: string,
  // pageSize: number,
  // currentPage: number,
  skeleton: boolean,
  // filePrefix: string,
  // footerClass: String,
  // refreshTable: Function,
  // buttons: Function,
}

export function DataTable<TData, TValue>({
  columns,
  data,
  caption,
  skeleton=false,
}: DataTableProps<TData, TValue>) {
  const [sorting, setSorting] = React.useState<SortingState>([])

  const table = useReactTable({
    data,
    columns,
    getCoreRowModel: getCoreRowModel(),
    getPaginationRowModel: getPaginationRowModel(),
    getSortedRowModel: getSortedRowModel(),
    onSortingChange: setSorting,
    state: {
      sorting,
    },
  })

  return (
    // <div className="h-full min-w-[425px]">
      <div className="rounded-md border shadow-sm p-2 h-full inline-block w-full">
        <TestTable>
          <TableHeader className="sticky top-0 z-1 bg-background">
            {table.getHeaderGroups().map((headerGroup) => (
              <TableRow key={headerGroup.id}>
                {headerGroup.headers.map((header) => {
                  return (
                    <TableHead key={header.id}>
                      {header.isPlaceholder
                        ? null
                        : flexRender(
                            header.column.columnDef.header,
                            header.getContext()
                          )}
                    </TableHead>
                  )
                })}
              </TableRow>
            ))}
          </TableHeader>
          <TableBody>
            { skeleton
              // Display Skeleton Rows
              ? <TableRow> {columns.map((col) => <TableCell><Skeleton className="h-[20px] w-full rounded-sm bg-gray-400 opacity-5"/></TableCell>)} </TableRow>
              // Display Real Data
              : table.getRowModel().rows?.length
                // Display Rows
                ? table.getRowModel().rows.map((row) => (
                    <TableRow
                      key={row.id}
                      data-state={row.getIsSelected() && "selected"}
                    >
                      {row.getVisibleCells().map((cell) => (
                        <TableCell key={cell.id}>
                          {flexRender(cell.column.columnDef.cell, cell.getContext())}
                        </TableCell>
                      ))}
                    </TableRow>
                  ))
                // Display No Results
                : <TableRow>
                    <TableCell colSpan={columns.length} className="h-24 text-center">
                      No results.
                    </TableCell>
                  </TableRow>
            }
          </TableBody>

          {/*  Table Caption */}
          { caption
            ? <TableCaption className="text-xs pt-4 pb-0 sticky bottom-0 bg-white z-1">{caption}</TableCaption>
            : null
          }
        </TestTable>

        {/* Table Footer */}
        <div className="flex items-center justify-between px-2 pt-2 pb-2">

          {/* Summarize Selected */}
          <div className="text-muted-foreground flex-1 text-xs text-left">
            {table.getFilteredSelectedRowModel().rows.length} of{" "}
            {table.getFilteredSelectedRowModel().rows.length} of{" "}
            {table.getFilteredRowModel().rows.length} row(s) selected.
          </div>

          <div className="flex items-center space-x-6 lg:space-x-4">

            {/* Rows per Page */}
            <div className="flex items-center space-x-2">
              <span className="text-muted-foreground text-xs">Rows per page</span>
                <Select
                  value={`${table.getState().pagination.pageSize}`}
                  onValueChange={(value) => { table.setPageSize(Number(value)) }}
                >
                <SelectTrigger className="w-[180px]">
                  <SelectValue placeholder={table.getState().pagination.pageSize} />
                </SelectTrigger>
                <SelectContent side="top">
                  {[10, 50, 100, 1000].map((pageSize) => (
                    <SelectItem key={pageSize} value={`${pageSize}`}>
                      {pageSize}
                    </SelectItem>
                  ))}
                </SelectContent>
                </Select>
            </div>

            {/* Page X of X */}
            <div className="flex w-[100px] items-center justify-center text-xs">
              Page {table.getState().pagination.pageIndex + 1} of{" "}
              {table.getPageCount()}
            </div>
          </div>

          {/* Pagination Controls */}
          <div className="flex items-center justify-end space-x-2 py-4 pt-1 pb-1">
            <Pagination className="mx-0 w-auto">
                <PaginationContent>

                <PaginationItem>
                  <PaginationPrevious onClick={() => table.previousPage()} className="text-xs"/>
                </PaginationItem>

                <PaginationItem>
                  <PaginationLink href="#"  isActive>1</PaginationLink>
                </PaginationItem>
                <PaginationItem>
                  <PaginationLink href="#">2</PaginationLink>
                </PaginationItem>
                <PaginationItem>
                  <PaginationLink href="#">3</PaginationLink>
                </PaginationItem>
                <PaginationItem>
                  <PaginationLink href="#">4</PaginationLink>
                </PaginationItem>
                <PaginationItem>
                  <PaginationLink href="#">5</PaginationLink>
                </PaginationItem>

                <PaginationItem>
                  <PaginationNext onClick={() => table.previousPage()} className="text-xs"/>
                </PaginationItem>

              </PaginationContent>
            </Pagination>
          </div>
      </div>
    </div>
  // </div>
  )
}
