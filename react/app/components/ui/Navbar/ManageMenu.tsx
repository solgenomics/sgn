import {
  DropdownMenu,
  DropdownMenuGroup,
} from "~/components/ui/dropdown-menu";

import {MenuContent, MenuItem, MenuSeparator, MenuTrigger} from "./"

export default function ManageMenu() {
  return (
        <DropdownMenu>
            <MenuTrigger text="Manage"/>
            <MenuContent>
                <DropdownMenuGroup>
                    <MenuItem text="User Roles"/>
                    <MenuItem text="Breeding Programs" link="/breeders/manage_programs"/>
                    <MenuItem text="Locations"/>
                    <MenuItem text="Accessions"/>
                </DropdownMenuGroup>

                <MenuSeparator/>

                <DropdownMenuGroup>
                    <MenuItem text="Seed Lots"/>
                    <MenuItem text="Crosses"/>
                    <MenuItem text="Field"/>
                    <MenuItem text="Genotyping Projects"/>
                    <MenuItem text="Tissue Samples"/>
                    <MenuItem text="Table" link={`/table`}/>
                </DropdownMenuGroup>


            </MenuContent>
        </DropdownMenu>
  )
}
