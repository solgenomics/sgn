import { ArrowUpDown } from "lucide-react"
import { Button } from "~/components/ui/button"

export function Sortable(props){
    return(
        <Button
            variant="ghost"
            onClick={() => props.column.toggleSorting(props.column.getIsSorted() === "asc")}
            className="bg-mgray-100 cursor-pointer"
        >
            {props.text}
            <ArrowUpDown className="ml-2 h-4 w-4" />
        </Button>
    )
}
