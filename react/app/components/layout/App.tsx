import {Navbar} from "@/components/ui/Navbar"
import { Outlet } from "react-router";

export default function Layout() {

    const style = { "min_width": "var(--breakpoint-xs)" } as React.CSSProperties;

    return (
        <div className="text-center">
            <div className="overflow-auto w-full h-screen" style={style}>
                <Navbar/>
                <Outlet />
            </div>
        </div>
    )
}
