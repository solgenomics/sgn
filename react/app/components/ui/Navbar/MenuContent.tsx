import { DropdownMenuContent } from "~/components/ui/dropdown-menu"

export function MenuContent({children}) {
  return (
    <DropdownMenuContent className="p-4 rounded-sm w-full bg-mgray-100 border-mgray-500 border">
        {children}
    </DropdownMenuContent>
  )
}
