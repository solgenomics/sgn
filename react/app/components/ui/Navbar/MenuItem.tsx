import { Link } from "react-router";
import { DropdownMenuItem } from "~/components/ui/dropdown-menu";

export function MenuItem(props) {
  return (
    <DropdownMenuItem
        className="p-0 pl-2 pr-2 hover:bg-mgray-300 hover:hover-shadow-text rounded-sm whitespace-nowrap text-sm"
    >
        <Link to={`${props.link}`} className="w-full" reloadDocument>{props.text}</Link>
    </DropdownMenuItem>
  )
}
