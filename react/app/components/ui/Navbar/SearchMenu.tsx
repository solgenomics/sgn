import { DropdownMenu, DropdownMenuGroup } from "~/components/ui/dropdown-menu";

import { MenuContent, MenuItem, MenuSeparator, MenuTrigger } from "./"

export default function SearchMenu() {
  return (
        <DropdownMenu>
            <MenuTrigger text="Search"/>
            <MenuContent>
                <DropdownMenuGroup>
                    <MenuItem text="Wizard" link="/search/wizard"/>
                    <MenuItem text="Bulk Search" link="/search/bulk"/>
                    <MenuItem text="Accessions and Plots"/>
                    <MenuItem text="Organisms" link="/search/organisms"/>
                    <MenuItem text="Progenies, Parents, Crosses"/>
                    <MenuItem text="Field Trials"/>
                </DropdownMenuGroup>

                <MenuSeparator />

                <DropdownMenuGroup>
                    <MenuItem text="Genotyping Plates"/>
                    <MenuItem text="Genotyping Projects"/>
                    <MenuItem text="Genotyping Protocols"/>
                    <MenuItem text="Accessions Using Genotypes"/>
                    <MenuItem text="Vector Constructs"/>
                </DropdownMenuGroup>

                <MenuSeparator />

                <DropdownMenuGroup>
                    <MenuItem text="Traits"/>
                    <MenuItem text="Treatments"/>
                    <MenuItem text="Markers"/>
                    <MenuItem text="Images"/>
                    <MenuItem text="People"/>
                    <MenuItem text="FAQ"/>
                </DropdownMenuGroup>

            </MenuContent>
        </DropdownMenu>
  )
}
