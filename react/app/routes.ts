import { type RouteConfig, index, layout, route, prefix } from "@react-router/dev/routes"

export default [
    layout("components/layout/App.tsx", [
        index("routes/home.tsx"),
        route("/breeders/manage_programs", "routes/breeders/manage_programs/index.tsx"),
        route("/basic", "routes/basic.tsx"),
    ]),
    route( "/table", "routes/table/table.tsx"),
] satisfies RouteConfig
