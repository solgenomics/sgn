import SearchMenu from "./SearchMenu";
import ManageMenu from "./ManageMenu";

export function Navbar() {
    return (
        <div className="min-h-15 w-full bg-mgray-100 button-box-shadow mb-8 content-center text-left">
            <SearchMenu/>
            <ManageMenu/>
        </div>
    );
}
