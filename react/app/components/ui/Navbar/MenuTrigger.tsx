import { Button } from "~/components/ui/button"
import { DropdownMenuTrigger } from "~/components/ui/dropdown-menu"
import { ChevronDown } from 'lucide-react';

export function MenuTrigger(props) {
  return (
    <DropdownMenuTrigger asChild className="ml-3">
        <Button variant="outline" className="pt-4 pb-4 rounded-sm bg-transparent border-0 hover:bg-mgray-300 hover:border-0 text-sm shadow-none">
          {props.text}
          	<ChevronDown className="relative top-[1px] ms-1 size-3"/>
        </Button>
    </DropdownMenuTrigger>
  )
}
